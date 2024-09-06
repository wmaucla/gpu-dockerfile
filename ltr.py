"""
Using xgboost on GPU devices
============================

Shows how to train a model on the `forest cover type
<https://archive.ics.uci.edu/ml/datasets/covertype>`_ dataset using GPU
acceleration. The forest cover type dataset has 581,012 rows and 54 features, making it
time consuming to process. We compare the run-time and accuracy of the GPU and CPU
histogram algorithms.
"""

import time
from sklearn.model_selection import train_test_split
from sklearn.datasets import fetch_covtype

import xgboost as xgb

# Fetch dataset using sklearn
X, y = fetch_covtype(return_X_y=True)
y -= y.min()  # Normalize target values to start from 0

# Create 0.75/0.25 train/test split using sklearn
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.25, train_size=0.75, random_state=42
)

# Specify sufficient boosting iterations to reach a minimum
num_round = 3000

print("Beginning training on GPU")

# Leave most parameters as default
clf = xgb.XGBClassifier(tree_method='gpu_hist', n_estimators=num_round)
# Train model
start = time.time()
clf.fit(X_train, y_train, eval_set=[(X_test, y_test)])
gpu_res = clf.evals_result()
print("GPU Training Time: %s seconds" % (str(time.time() - start)))

# Repeat for CPU algorithm
clf = xgb.XGBClassifier(tree_method='hist', n_estimators=num_round)
start = time.time()
clf.fit(X_train, y_train, eval_set=[(X_test, y_test)])
cpu_res = clf.evals_result()
print("CPU Training Time: %s seconds" % (str(time.time() - start)))
