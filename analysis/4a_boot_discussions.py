import pandas as pd
from pathlib import Path
import pickle as pkl
from os.path import join
import numpy as np
import statsmodels.api as sm
import sys
from tqdm import tqdm

np.random.seed(63)

pd.options.display.float_format = '{:.5f}'.format
pd.options.mode.chained_assignment = None


N_ITER = 10000

src = sys.argv[1] #"../data/"
with open(join(src, "./dtypes_config.pickle"), "rb") as file:
    DTYPES = pkl.load(file)

def read_data(data_dir, pattern):
    for file_path in Path(data_dir).glob(pattern):
        try:
            print(f"Processing file: {file_path}")
            df = pd.read_csv(file_path, dtype=DTYPES)
            df["Rating"] = pd.to_numeric(df["Rating"], errors="coerce")
            df["Bias"] = pd.to_numeric(df["Orientation"], errors="coerce")
            df.drop(columns=["Orientation"], inplace=True)
            df.drop(columns=["Unnamed: 0"], inplace=True)
            df.columns = df.columns.str.replace("author.", "",
                                                regex=True)
            df.columns = df.columns.str.capitalize()
            return df
        except Exception as e:
            print(f"Error processing file {file_path}: {e}")
    
replies = read_data(src, "matched_replies_mahalanobis.csv")
first = read_data(src, "matched_replies_first_mahalanobis.csv")

#define relevant columns
IV = "Rating"
DVS_REPLIES = ["Anger_avg", "Disgust_avg", "Fear_avg", "Sadness_avg", 
       "Joy_avg", "Pride_avg", "Hope_avg"]
DVS_FIRST = ["Anger_first", "Disgust_first", "Fear_first", "Sadness_first",
                "Joy_first", "Pride_first", "Hope_first"]
COVARIATES = ["Bias", 
              "Anger_log", "Disgust_log", "Fear_log", "Sadness_log",
              "Joy_log", "Pride_log", "Hope_log",
              "Followers_count_log", "Following_count_log", "Tweet_count_log",
              "Word_count_log", 
              "Tweet_count_avg_log", "Time_diff_log"]

COVARIATES_FIRST = ["Bias",
                    "Anger_log", "Disgust_log", "Fear_log", "Sadness_log",
                    "Joy_log", "Pride_log", "Hope_log",
                    "Followers_count_log", "Following_count_log","Tweet_count_log", "Word_count_log", 
                    "Tweet_count_first_log"]



#filter data
reply_columns = [IV] + DVS_REPLIES + COVARIATES
df_replies = replies[reply_columns] 

first_columns = [IV] + DVS_FIRST + COVARIATES_FIRST
df_first = first[first_columns]


def fit_models(df, dvs, iv, covariates, coeff_path):
    coefficients_df = pd.DataFrame(
        columns=["DV", "Coefficient", "SE",
                 "CI_Lower", "CI_Upper",
                 "P-Value", "R-Squared", 
                 "Cond_Mean"])
    models = []
    
    for dv in dvs:
        X = df[[iv] + covariates]
        X = sm.add_constant(X)
        y = df[dv]

        model = sm.OLS(y, X).fit()
        models.append(model)

        #extract the model params
        coef_score = model.params[iv]
        se = model.bse[iv]
        ci_lower, ci_upper = model.conf_int().loc[iv]
        p_value = model.pvalues[iv]
        r_squared = model.rsquared

        #calculate conditional mean
        intercept = model.params["const"]
        mean_cov_values = df[covariates].mean()
        mean_cov_effects = (mean_cov_values * model.params[covariates]).sum()
        cond_mean = intercept + mean_cov_effects

        #save the results
        coefficients_df = pd.concat(
            [coefficients_df, pd.DataFrame({
                "DV": [dv],
                "Coefficient": [coef_score],
                "SE": [se],
                "CI_Lower": [ci_lower],
                "CI_Upper": [ci_upper],
                "P-Value": [p_value],
                "R-Squared": [r_squared],
                "Cond_Mean": [cond_mean]
            })], ignore_index=True)
        
    coefficients_df.to_csv(coeff_path, index=False)


def residual_bootstrap(df, dvs, iv, covariates, n_iter, output_file):

    bootstrap_results = []
    
    for dv in tqdm(dvs, desc="Residual Bootstrapping DVs"):
        # fit original model 
        X = df[[iv] + covariates].copy()
        X = sm.add_constant(X)
        y = df[dv].copy()
        
        # remove missing values
        combined = pd.concat([X, y], axis=1).dropna()
        X_clean = combined.iloc[:, :-1]
        y_clean = combined.iloc[:, -1]
        
        og_model = sm.OLS(y_clean, X_clean).fit()
        
        # extract fitted values and residuals
        y_fitted = og_model.fittedvalues
        residuals = og_model.resid
        
        # bootstrap residuals
        for i in range(n_iter):
            # sample residuals with replacement
            bootstrap_residuals = np.random.choice(residuals, size=len(residuals), replace=True)
            
            # generate new Y values: Y_new = Y_fitted + bootstrap_residuals
            y_bootstrap = y_fitted + bootstrap_residuals
            
            # re-estimate model with new Y but same X
            bootstrap_model = sm.OLS(y_bootstrap, X_clean).fit()
            
            # extract coefficient for IV
            coefficient = bootstrap_model.params[iv]
            ci_lower = bootstrap_model.conf_int().loc[iv, 0]
            ci_upper = bootstrap_model.conf_int().loc[iv, 1]
            
            result = {
                "DV": dv,
                "Coefficient_boot": coefficient,
                "CI_Lower_boot": ci_lower,
                "CI_Upper_boot": ci_upper
            }
            bootstrap_results.append(result)
            
            # save periodically
            if (i + 1) % 100 == 0 or (dv == dvs[-1] and i == n_iter - 1):
                pd.DataFrame(bootstrap_results).to_csv(output_file, 
                                                       index=False, 
                                                       mode='a', 
                                                       header=not Path(output_file).exists())
                bootstrap_results = []

print("Computing full models for replies")
fit_models(df_replies, DVS_REPLIES, IV, COVARIATES, 
            "./replies/replies_coeffs.csv")

print("Computing full models for first replies")
fit_models(df_first, DVS_FIRST, IV, COVARIATES_FIRST, 
            "./replies_first/first_replies_coeffs.csv")
print("Residual Bootstrapping for replies")
residual_bootstrap(df_replies, 
                      DVS_REPLIES, IV, COVARIATES, 
                      N_ITER, 
                      "./replies/replies_res_boot.csv")

print("Residual Bootstrapping for first")
residual_bootstrap(df_first, 
                      DVS_FIRST, IV, COVARIATES_FIRST, 
                      N_ITER,
                      "./replies_first/replies_first_res_boot.csv")


print("Saved results.")
