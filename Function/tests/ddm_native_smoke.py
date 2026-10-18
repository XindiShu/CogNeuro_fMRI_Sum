"""Native simulation -> native fit -> density checks, no real-data assertion."""
import json
import sys
from pathlib import Path
import numpy as np
from scipy.io import savemat, loadmat
import pyddm
from pyddm.models import DriftConstant, BoundConstant, OverlayNonDecision

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from ddm_bridge import main

folder = Path(sys.argv[1])
truth = pyddm.Model(drift=DriftConstant(drift=.7), bound=BoundConstant(B=1),
                    overlay=OverlayNonDecision(nondectime=.2), dt=.01, dx=.02,
                    T_dur=4, choice_names=("upper", "lower"))
sample = truth.solve_analytical().sample(k=150, seed=8)
rt = np.r_[sample.choice_upper, sample.choice_lower]
choice = np.r_[np.ones(len(sample.choice_upper)), np.zeros(len(sample.choice_lower))]
savemat(folder / "input.mat", {"rtSeconds": rt, "upperChoice": choice})
o = dict(driftBounds=[-3, 3], boundBounds=[.3, 2], nondecisionBounds=[0, .5],
         dtSeconds=.01, dx=.02, maxRtSeconds=10, mixture=.02,
         maxIterations=15, populationSize=6, seed=61)
request = dict(inputFile=str(folder / "input.mat"), outputFile=str(folder / "posterior.mat"),
               modelFile=str(folder / "model.pkl"), options=o)
path = folder / "request.json"
path.write_text(json.dumps(request), encoding="utf-8")
main(path)
d = loadmat(request["outputFile"])
assert np.isfinite(d["parameterValues"]).all()
assert np.isfinite(d["negativeLogLikelihood"]).all()
assert (d["perTrialNegativeLogDensity"].size == rt.size)
assert 0.8 <= d["choiceProbabilities"].sum() <= 1.0001
baseline = pyddm.Model(drift=DriftConstant(drift=0), bound=BoundConstant(B=1.8),
                       overlay=OverlayNonDecision(nondectime=0), dt=.01, dx=.02,
                       T_dur=float(d["durationSeconds"].item()), choice_names=("upper", "lower"))
solution = baseline.solve_analytical()
nll = -sum(np.log(max(1e-30, solution.evaluate(float(t), choice="upper" if c else "lower")))
           for t, c in zip(rt, choice))
assert d["negativeLogLikelihood"].item() < nll
print("Native PyDDM synthetic simulation/fit/density checks passed")
