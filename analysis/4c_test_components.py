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

src = sys.argv[1] #"../data"
dst = sys.argv[2] #"./newsguard"
with open(join(src, "dtypes_config.pickle"), "rb") as file:
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
    
replies = read_data(src, "matched_replies.csv")
first = read_data(src, "matched_replies_first.csv")

criteria = pd.read_csv(join(dst,"newsguard_criteria.csv"),
                       dtype=DTYPES)

criteria = criteria[
    criteria.file_date.str.contains("-15") &
    (criteria.Language == "de") &
    criteria.Score.notnull()
]

def merge_criteria(df, criteria):
    criteria["month"] = criteria.file_date.str[:7]
    df["month"] = df.Created_at.str[:7]
    max_date = df.month.max()
    criteria = criteria[criteria.month <= max_date]
    dis_crit = pd.merge(df,
                    criteria, 
                  left_on=["Domain", "month", "Score"], 
                  right_on=["Domain", "month", "Score"], 
                  how="left")
    return dis_crit

replies = merge_criteria(replies, criteria)
first = merge_criteria(first, criteria)


#define relevant columns
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

CRITERIA = [
       "Does not repeatedly publish false content", 
       "Gathers and presents information responsibly", 
       "Regularly corrects or clarifies errors", 
       "Handles the difference between news and opinion responsibly", 
       "Avoids deceptive headlines", 
       "Website discloses ownership and financing", 
       "Clearly labels advertising", 
       "Reveals who's in charge, including any possible conflicts of interest",
       "The site provides names of content creators, along with either contact or biographical information"]

#filter data
reply_columns = DVS_REPLIES + COVARIATES + CRITERIA
df_replies = replies[reply_columns] 

first_columns = DVS_FIRST + COVARIATES_FIRST + CRITERIA
df_first = first[first_columns]

#recode criteria columns
for crit in CRITERIA:
    df_replies[crit] = df_replies[crit].replace({"Yes": 0, "No": 1})
    df_first[crit] = df_first[crit].replace({"Yes": 0, "No": 1}) #misinfo is treatment

def compute_full_models(df, dvs, iv, covariates, coeff_path):
    coefficients_df = pd.DataFrame(
        columns=["DV", "Coefficient", "SE",
                 "CI_Lower", "CI_Upper",
                 "P-Value", "R-Squared"])

    for dv in dvs:
        X = df[[iv] + covariates]
        X = sm.add_constant(X)
        y = df[dv]
        model = sm.OLS(y, X).fit()

        #extract the model params
        coef_score = model.params[iv]
        se = model.bse[iv]
        ci_lower, ci_upper = model.conf_int().loc[iv]
        p_value = model.pvalues[iv]
        r_squared = model.rsquared

        #save the results
        coefficients_df = pd.concat(
            [coefficients_df, pd.DataFrame({
                "DV": [dv],
                "Coefficient": [coef_score],
                "SE": [se],
                "CI_Lower": [ci_lower],
                "CI_Upper": [ci_upper],
                "P-Value": [p_value],
                "R-Squared": [r_squared]
            })], ignore_index=True)
        
    #save as csv
    coefficients_df.to_csv(coeff_path, index=False)
    


#define function to bootstrap OLS
# def bootstrap_ols(df, dvs, iv, covariates, n_iter, output_file):
#     bootstrap_results = []
#     n_rows = len(df)
#     for dv in tqdm(dvs, desc="Bootstrapping DVs"):
#         for i in range(n_iter):
#             sample_indices = np.random.choice(n_rows, size=n_rows, replace=True)
#             sample = df.iloc[sample_indices]
#             X = sample[[iv] + covariates]
#             y = sample[dv]
#             X = sm.add_constant(X)
#             model = sm.OLS(y, X).fit()

#             coefficient = model.params[iv]
#             ci_lower = model.conf_int().loc[iv, 0]
#             ci_upper = model.conf_int().loc[iv, 1]
#             p_value = model.pvalues[iv]
#             r_squared = model.rsquared
            
#             result = {
#                 "DV": dv,
#                 "Coefficient_boot": coefficient,
#                 "CI_Lower_boot": ci_lower,
#                 "CI_Upper_boot": ci_upper,
#                 "P-Value_boot": p_value,
#                 "R-Squared_boot": r_squared
#             }
#             bootstrap_results.append(result)

#             #periodically save results every 100 iterations or at the end
#             if (i + 1) % 100 == 0 or (dv == dvs[-1] and i == n_iter - 1):  
                
#                 pd.DataFrame(bootstrap_results).to_csv(output_file, 
#                                                        index=False, 
#                                                        mode='a', 
#                                                        header=not Path(output_file).exists())
#                 bootstrap_results = [] #clear to save memory



for crit in CRITERIA:
    IV = crit
    df_replies = df_replies.dropna(subset=[IV])
    compute_full_models(df_replies, 
                        DVS_REPLIES, 
                        IV,
                        COVARIATES, 
                        join(dst,"./criteria_replies/replies_coeffs_{}.csv".format(IV)
                             )
                        )

    
for crit in CRITERIA:
    IV = crit
    df_first = df_replies.dropna(subset=[IV])
    compute_full_models(df_replies, 
                        DVS_REPLIES, 
                        IV,
                        COVARIATES, 
                        join(dst,
                        "./criteria_first/replies_first_coeffs_{}.csv".format(IV)
                            )
                        )
    
    
    # print("Bootstrapping for first replies...")
    # bootstrap_ols(df_first, 
    #             DVS_FIRST, IV, COVARIATES_FIRST, 
    #             N_ITER,
    #                 "./replies/replies_first_coeffs_boot.csv")