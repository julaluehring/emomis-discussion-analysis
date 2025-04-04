import pandas as pd
from os.path import join
import re
import os
from irrCAC.raw import CAC
import sys
import numpy as np
np.random.seed(63) 

DIR_PATH = sys.argv[1] 
OUTPUT_PATH = sys.argv[2] 
dfs = []

''' ROUND 1 ANNOTATIONS '''
emotion_cols = ["Wut", "Angst", "Ekel", "Traurigkeit",
                "Freude", "Begeisterung", "Stolz", "Hoffnung"]

files_r1 = [f for f in os.listdir(DIR_PATH) 
         if re.match(r"Emotion.*\.xlsx", f)]

for f in files_r1:
        df1 = pd.read_excel(join(DIR_PATH, f), 
                           usecols=["ID", "Text"] + emotion_cols,
                           dtype={"ID": str,
                                  "Text": str})
        number = re.search(r"Task_(\d+)-finished\.xlsx", f).group(1)
        df1["Annotator"] = number
        df1["Round"] = 1
        dfs.append(df1)

''' ROUND 2 ANNOTATIONS '''
files_r2 = [f for f in os.listdir(DIR_PATH) 
         if re.match(r"Annotations.*\.xlsx", f)]

for f in files_r2:
        df2 = pd.read_excel(join(DIR_PATH, f), 
                           usecols=["ID", "Text"] + emotion_cols,
                           dtype={"ID": str, 
                                  "Text": str})
        number = re.search(r"_([A-Z])\.xlsx", f).group(1)
        df2["Annotator"] = number
        df2["Round"] = 2
        dfs.append(df2)

''' CONCACENATE ROUNDS '''
df_manual = pd.concat(dfs, ignore_index=True)
for emotion in emotion_cols:
    df_manual[emotion] = df_manual[emotion]\
                        .fillna(0)\
                        .replace("x", 1)\
                        .replace("X", 1)\
                        .apply(lambda x: 0 if x not in [0, 1] else x)
    
''' DEFINE AGREEMENT FUNCTIONS '''
def calculate_agreement(row):
    counts = row.value_counts()
    max_count = counts.max() 
    agreement_perc = (max_count / len(row)) * 100
    return agreement_perc

def take_mode(row):
    modes = row.mode() #take the mode
    return modes.min() #if there is a tie, take the smallest (0)

''' CALCULATE AGREEMENT FOR ALL TWEETS '''
results_collapsed = []
for emotion in emotion_cols:
    df_all_tweets = df_manual.pivot(index=["ID", "Text"],
                                columns="Annotator",
                                values=emotion)\
                            .reset_index()\
                            .rename_axis(None, axis=1)
    
    #extract tweets that were rated by all annotators
    df_overlap = df_all_tweets.dropna(subset=["01", "02"])\
                            .copy()

    #keep only tweets with no overlap across rounds
    df_all_tweets = df_all_tweets[~df_all_tweets["ID"]\
                                  .isin(df_overlap["ID"])]
    
    df_all_tweets["R1"] = df_all_tweets[["01", "02", "03",
                                        "04", "05", "06"]]\
                                .apply(take_mode, axis=1)
    
    df_all_tweets["R2"] = df_all_tweets[["A", "B"]]\
                                .apply(take_mode, axis=1)
    
    df_all_tweets = df_all_tweets[["ID", "Text","R1", "R2"]]
    
    df_all_tweets["perc_agree"] = df_all_tweets[["R1", "R2"]]\
                                .apply(calculate_agreement, axis=1)
    perc_agree = df_all_tweets["perc_agree"].mean()
    perc_agree_std = df_all_tweets["perc_agree"].std()
    n_tweets = df_all_tweets["ID"].nunique()
    agree_below_60 = df_all_tweets[df_all_tweets["perc_agree"] < 60].head(5)
    examples = agree_below_60["Text"].tolist()
    examples_str = ",".join(examples)


    ''' CHANCE AGREEMENT '''
    shuffled_means = []
    shuffled_stds = []
    shuffled_lower = []
    shuffled_upper = []

    for _ in range(10000):
        df_all_tweets["R_shuff"] = np.random.permutation(df_all_tweets["R1"])

        df_all_tweets["perc_agree_shuff"] = \
            df_all_tweets[["R_shuff", "R2"]]\
                .apply(calculate_agreement, axis=1)
        
        #calculate the mean and std of each shuffled df
        means = df_all_tweets["perc_agree_shuff"].mean()
        std = df_all_tweets["perc_agree_shuff"].std()

        #save to lists
        shuffled_means.append(means)
        shuffled_stds.append(std)

    #save the shuffled means
    shuffled_metrics_df = pd.DataFrame(shuffled_means, 
                                       columns=["perc_agree_shuff"])
    shuffled_metrics_df.to_csv(join(OUTPUT_PATH,
                                f'./permutations/{emotion}_shuffled.csv'),
                                index=False)

    #save summary statistics
    results_collapsed.append({
        "emotion": emotion,
        "n_tweets": n_tweets,
        "perc_agree": perc_agree,
        "perc_agree_std": perc_agree_std,
        "perc_agree_shuff": np.mean(shuffled_means),
        "perc_agree_shuff_std": np.mean(shuffled_stds),
        "perc_agree_shuff_25": np.quantile(shuffled_means, 0.25),
        "perc_agree_shuff_75": np.quantile(shuffled_means, 0.75),
        "n_shuffles": len(shuffled_means),
        "agree_below_60": examples_str
    })

df_results_collapsed = pd.DataFrame(results_collapsed)
df_results_collapsed.to_csv(join(OUTPUT_PATH, 
                                 "agreement_perc_collapsed_800.csv"),
                        index=False)      
    
print("Done!")