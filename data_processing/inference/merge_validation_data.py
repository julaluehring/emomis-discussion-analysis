import pandas as pd
from os.path import join
import os
import sys
import pickle
import re

DIR_PATH = sys.argv[1]
VAL_PATH = join(DIR_PATH, "validation/")

with open(join(DIR_PATH, 
               "dtypes_config.pickle"),
                "rb") as file:
    DTYPES = pickle.load(file)

''' LOAD INFERENCES '''
df_inference = pd.read_csv(join(
                    DIR_PATH,
                    "german_newsguard_tweets_inference.csv.gz"),
                 compression="gzip",
                 usecols=["id", 
                          "anger", "fear", "disgust", "sadness", 
                          "joy", "pride", "enthusiasm", "hope"],
                 dtype=DTYPES
                 )
print(f'Inference data: {df_inference["id"].nunique()} tweets.')

''' LOAD ROUND 1 ANNOTATIONS '''
dfs = []
emotion_cols = ["Wut", "Angst", "Ekel", "Traurigkeit",
                "Freude", "Begeisterung", "Stolz", "Hoffnung"]

files = [f for f in os.listdir(VAL_PATH) 
         if re.match(r"Emotion.*\.xlsx", f)]

for f in files:
        df = pd.read_excel(join(VAL_PATH, f), 
                           usecols=["ID", "Text"] + emotion_cols,
                           dtype={"ID": int,
                                  "Text": str})
        number = re.search(r"Task_(\d+)-finished\.xlsx", f).group(1)
        df["annotator"] = number
        df.rename(columns={"ID": "id"}, inplace=True)
        dfs.append(df)

''' ROUND 2 ANNOTATIONS '''
emotion_cols_2 = ["Wut", "Angst", "Ekel", "Trauer",
                "Freude", "Enthusiasmus", "Stolz", "Hoffnung"]

files = [f for f in os.listdir(VAL_PATH) 
         if re.match(r"Annotations.*\.xlsx", f)]

for f in files:
        df = pd.read_excel(join(VAL_PATH, f), 
                           usecols=["id", "text"] + emotion_cols_2,
                           dtype={"id": int, 
                                  "text": str})
        number = re.search(r"_([A-Z])\.xlsx", f).group(1)
        df["annotator"] = number
        df.rename(columns={"Trauer": "Traurigkeit"}, inplace=True)
        df.rename(columns={"Enthusiasmus": "Begeisterung"}, inplace=True)
        df.rename(columns={"text": "Text"}, inplace=True)
        dfs.append(df)

''' CONCACENATE ROUNDS '''
df_manual = pd.concat(dfs, ignore_index=True)
for emotion in emotion_cols:
    df_manual[emotion] = df_manual[emotion]\
                        .fillna(0)\
                        .replace("x", 1)\
                        .replace("X", 1)\
                        .apply(lambda x: 0 if x not in [0, 1] else x)
    
print(f'Manual data: {df_manual["id"].nunique()} tweets.')

df_long = pd.melt(df_manual,
                   id_vars=["id", "Text", "annotator"],
                   value_vars=emotion_cols,
                   var_name="emotion",
                   value_name="value")

df_wide = df_long.pivot_table(index=["id", "Text", "emotion"],
                              columns="annotator",
                              values="value")\
                                .reset_index()

def calculate_mode(row):
    modes = row.mode() #take the mode
    return modes.min() #if there is a tie, take the smallest (0)

df_wide["Mode"] = df_wide[["01", "02", "03",
                             "04", "05", "06",
                             "A", "B"]]\
                                .apply(calculate_mode, axis=1)

df_wide = df_wide.drop(columns=["01", "02", "03",
                        "04", "05", "06",
                        "A", "B"])\
                 .copy()

df_wide["emotion"] = \
    df_wide["emotion"]\
        .replace(
            {"Freude": "joy",
            "Traurigkeit": "sadness",
            "Wut": "anger",
            "Ekel": "disgust",
            "Begeisterung": "enthusiasm",
            "Angst": "fear",
            "Stolz": "pride",
            "Hoffnung": "hope"})

#emotion as columns 
df_wide = df_wide.pivot_table(index=["id", "Text"],
                              columns="emotion",
                              values="Mode")\
                                .reset_index()

print(f'After recoding: {df_wide["id"].nunique()} tweets.')

''' MERGE DATA '''
df_validation = df_wide\
    .merge(df_inference,
           left_on="id",
           right_on="id",
           suffixes=("_manual", "_inference"),
           how="left")

print(f'Validation data shape: {df_validation.shape}.')
print(f'Number of unique tweets: {df_validation["id"].nunique()}.')
                                  
df_validation.to_csv(join(VAL_PATH, 
                          "emotion_validation_mode.csv"), 
                          index=False)