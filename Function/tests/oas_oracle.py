"""Independent installed scikit-learn OAS numerical oracle; no input writes."""
import sys
from scipy.io import loadmat, savemat
from sklearn.covariance import oas

x = loadmat(sys.argv[1])["x"]
covariance, shrinkage = oas(x, assume_centered=False)
savemat(sys.argv[2], {"covariance": covariance, "shrinkage": shrinkage})
