"""Native GLHMM adapter. Inputs/outputs live only in a new analysis directory."""
import importlib.metadata
import json
import pickle
import sys
from pathlib import Path

import numpy as np
from scipy.io import loadmat, savemat
from glhmm import glhmm


def main(spec_file):
    spec = json.loads(Path(spec_file).read_text(encoding="utf-8-sig"))
    output = Path(spec["outputFile"])
    model_file = Path(spec["modelFile"])
    if output.exists() or model_file.exists():
        raise FileExistsError("Refuse to overwrite a fitted model or posterior")
    d = loadmat(spec["inputFile"])
    y = np.asarray(d["Y"], dtype=float)
    indices = np.asarray(d["indices"], dtype=np.int64)
    o = spec["options"]
    if (y.ndim != 2 or not np.isfinite(y).all() or indices.ndim != 2
            or indices.shape[1] != 2 or indices[0, 0] != 0
            or indices[-1, 1] != len(y)
            or np.any(indices[:, 1] <= indices[:, 0])
            or not np.array_equal(indices[1:, 0], indices[:-1, 1])):
        raise ValueError("Finite Y and exhaustive zero-based, exclusive-end segments required")
    np.random.seed(int(o["seed"]))
    model = glhmm.glhmm(K=int(o["nStates"]), covtype=o["hmmCovariance"],
                        model_mean=o["hmmMean"], model_beta="no")
    gamma, xi, fe = model.train(
        X=None, Y=y, indices=indices,
        options={"cyc": int(o["hmmMaxCycles"]),
                 "initrep": int(o["hmmInitializations"]),
                 "initcyc": min(10, int(o["hmmMaxCycles"])),
                 "serial": True, "verbose": True, "gpu_acceleration": 0})
    # GLHMM 1.1.2 serial Viterbi omits an internal serial argument; use its
    # public parallel decoder without modifying the installed dependency.
    vpath = model.decode(X=None, Y=y, indices=indices, viterbi=True, serial=False)
    k = int(o["nStates"])
    if gamma.shape != (len(y), k) or not np.allclose(gamma.sum(axis=1), 1):
        raise ValueError("Posterior state probabilities do not sum to one")
    if vpath.shape != gamma.shape or not np.allclose(vpath.sum(axis=1), 1):
        raise ValueError("Native Viterbi path is not one-hot")
    covariances = np.stack([model.get_covariance_matrix(s) for s in range(k)], axis=2)
    means = model.get_means() if o["hmmMean"] != "no" else np.zeros((y.shape[1], k))
    arrays = [gamma, xi, fe, vpath, covariances, means, model.P, model.Pi]
    if not all(np.isfinite(a).all() for a in arrays):
        raise ValueError("Nonfinite native posterior/model parameter")
    if xi.shape != (len(y) - len(indices), k, k) or not np.allclose(model.P.sum(axis=1), 1):
        raise ValueError("Transition posterior dimensions/normalization mismatch")
    for s in range(k):
        c = covariances[:, :, s]
        if not np.allclose(c, c.T) or np.linalg.eigvalsh(c).min() <= 0:
            raise ValueError("State covariance is not positive definite")
    versions = {name: importlib.metadata.version(name)
                for name in ["glhmm", "numpy", "scipy", "numba", "scikit-learn"]}
    with model_file.open("xb") as f:
        pickle.dump(model, f, protocol=pickle.HIGHEST_PROTOCOL)
    savemat(output, {"Gamma": gamma, "Xi": xi,
                     "labels": vpath.argmax(axis=1).astype(np.int64) + 1,
                     "means": means, "covariances": covariances,
                     "transition": model.P, "initial": model.Pi,
                     "activeStates": model.active_states,
                     "freeEnergyHistory": np.asarray(fe),
                     "versionsJson": json.dumps(versions)}, do_compression=True)


if __name__ == "__main__":
    main(sys.argv[1])
