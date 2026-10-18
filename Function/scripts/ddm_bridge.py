"""Constant unbiased binary DDM via official PyDDM, noise fixed to one."""
import importlib.metadata
import json
import pickle
import sys
from pathlib import Path
import numpy as np
from scipy.io import loadmat, savemat
import pyddm
from pyddm.models import (DriftConstant, NoiseConstant, BoundConstant,
                          ICPointSourceCenter, OverlayChain,
                          OverlayNonDecision, OverlayUniformMixture)


def main(request_file):
    request = json.loads(Path(request_file).read_text(encoding="utf-8-sig"))
    o = request["options"]
    output = Path(request["outputFile"])
    model_file = Path(request["modelFile"])
    if output.exists() or model_file.exists():
        raise FileExistsError("Refuse to overwrite DDM fit")
    data = loadmat(request["inputFile"])
    rt = np.asarray(data["rtSeconds"], dtype=float).ravel()
    choice = np.asarray(data["upperChoice"], dtype=float).ravel()
    if (rt.size != choice.size or not np.isfinite(rt).all() or
            np.any(rt <= 0) or np.any(rt > o["maxRtSeconds"]) or
            not np.isin(choice, [0, 1]).all()):
        raise ValueError("Finite seconds RT and binary upper-choice indicator required")
    bounds = [list(o["driftBounds"]), list(o["boundBounds"]),
              [o["nondecisionBounds"][0], min(o["nondecisionBounds"][1], float(rt.min())*.95)]]
    if (not all(np.isfinite(b).all() and b[0] < b[1] for b in bounds)
            or bounds[1][0] <= 0 or bounds[2][0] < 0 or
            o["dtSeconds"] <= 0 or o["dx"] <= 0 or not 0 < o["mixture"] < 1):
        raise ValueError("Invalid drift/bound/nondecision/grid/mixture settings")
    duration = float(np.ceil(rt.max()/o["dtSeconds"])*o["dtSeconds"]+.5)
    names = ("upper", "lower")
    model = pyddm.Model(
        drift=DriftConstant(drift=pyddm.Fittable(*bounds[0])),
        noise=NoiseConstant(noise=1),
        bound=BoundConstant(B=pyddm.Fittable(*bounds[1])),
        IC=ICPointSourceCenter(),
        overlay=OverlayChain(overlays=[
            OverlayNonDecision(nondectime=pyddm.Fittable(*bounds[2])),
            OverlayUniformMixture(umixturecoef=o["mixture"])]),
        dt=o["dtSeconds"], dx=o["dx"], T_dur=duration, choice_names=names)
    sample = pyddm.Sample(rt[choice == 1], rt[choice == 0], choice_names=names)
    pyddm.fit_adjust_model(
        sample=sample, model=model, fitting_method="differential_evolution",
        fitparams={"maxiter": int(o["maxIterations"]),
                   "popsize": int(o["populationSize"]),
                   "seed": int(o["seed"]), "tol": .01, "polish": True},
        lossfunction=pyddm.LossLikelihood, method="analytical", verbose=False)
    solution = model.solve_analytical()
    density = np.array([solution.evaluate(float(t), choice=names[0] if c else names[1])
                        for t, c in zip(rt, choice)])
    parameters = np.array([float(p) for p in model.get_model_parameters()])
    pdf_upper, pdf_lower = solution.pdf("upper"), solution.pdf("lower")
    if (not np.isfinite(parameters).all() or not np.isfinite(density).all()
            or np.any(density <= 0) or np.any(pdf_upper < 0) or np.any(pdf_lower < 0)):
        raise ValueError("Invalid fitted DDM density/parameter")
    nll = float(-np.log(density).sum())
    versions = {p: importlib.metadata.version(p) for p in ["pyddm", "numpy", "scipy"]}
    with model_file.open("xb") as f:
        pickle.dump(model, f, protocol=pickle.HIGHEST_PROTOCOL)
    savemat(output, {"parameterNames": np.asarray(model.get_model_parameter_names(), dtype=object),
                     "parameterValues": parameters, "effectiveBounds": np.asarray(bounds),
                     "negativeLogLikelihood": nll, "perTrialNegativeLogDensity": -np.log(density),
                     "aic": 2*nll+2*len(parameters), "bic": 2*nll+np.log(rt.size)*len(parameters),
                     "timeSeconds": model.t_domain(), "pdfUpper": pdf_upper,
                     "pdfLower": pdf_lower,
                     "choiceProbabilities": [solution.prob("upper"), solution.prob("lower")],
                     "durationSeconds": duration, "versionsJson": json.dumps(versions),
                     "nativeFitResult": str(model.fitresult)}, do_compression=True)


if __name__ == "__main__":
    main(sys.argv[1])
