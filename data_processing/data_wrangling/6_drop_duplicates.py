# STEP 6: DROP DUPLICATES FROM DATAFRAME.
import pandas as pd
import pickle as pkl
import os
import sys

src = sys.argv[1]
with open(os.path.join(src, "dtypes_config.pickle"), "rb") as file:
    DTYPES = pkl.load(file)

df = pd.read_csv(os.path.join(src,"german_newsguard_tweets_anonymized.csv.gz"), 
                                compression="gzip",
                                dtype=DTYPES, 
                                #nrows=10000 #testing
                )
print(f'Length of df with duplicates: {len(df)}')

df.drop_duplicates(subset=["id", "domain"], inplace=True)
print(f'Length of df without duplicates: {len(df)}')

df.to_csv(os.path.join(src, "german_newsguard_tweets_anonymized.csv.gz"), 
                        compression="gzip")