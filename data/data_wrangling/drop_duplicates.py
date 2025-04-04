# STEP 6: DROP DUPLICATES FROM DATAFRAME.
import pandas as pd
import pickle as pkl
import os
import sys

DATA_DIR = sys.argv[1]
with open(os.path.join(DATA_DIR, "dtypes_config.pickle"), "rb") as file:
    DTYPES = pkl.load(file)

df = pd.read_csv(os.path.join(DATA_DIR,"german_newsguard_tweets.csv.gz"), 
                                compression="gzip",
                                dtype=DTYPES, 
                                #nrows=10000 #testing
                )
print(f'Length of df with duplicates: {len(df)}')

df.drop_duplicates(subset=["id", "domain"], inplace=True)
print(f'Length of df without duplicates: {len(df)}')

df.to_csv(os.path.join(DATA_DIR, "german_newsguard_tweets.csv.gz"), 
                        compression="gzip")