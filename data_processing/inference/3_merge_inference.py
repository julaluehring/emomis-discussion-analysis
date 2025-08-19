import pandas as pd
from os.path import join
import pickle
import sys

src = sys.argv[1]

with open(join(src, "dtypes_config.pickle"), 
          'rb') as file:
    DTYPES = pickle.load(file)

df = pd.read_csv(join(src, 
                      "german_newsguard_tweets.csv.gz"), 
                    #usecols=["id", "domain"], #check len
                    dtype = DTYPES,
                    #parse_dates = ["created_at", "author.created_at"],
                    #nrows=1000, #check cols
                    index_col=["id", "domain"],
                    compression="gzip")

print(f'Length of df: {len(df)}')

emos = pd.read_csv(join(src, 
                        "inference/emotion_inference.csv.gz"), 
                    compression="gzip",
                    usecols = ["id", "domain", #identifier
                    "anger_v2", "fear_v2", "disgust_v2", "sadness_v2", #neg emotions
                     "joy_v2", "enthusiasm_v2", "pride_v2", "hope_v2"], #pos emotions
                    dtype = DTYPES,
                    index_col=["id", "domain"],
                    #nrows=1000
                    )
print(f'Length of emos: {len(emos)}')

df_emos = pd.merge(df, emos, 
                left_index=True, right_index=True, #multi-index merge
                how="left" # left join to match inference with original df
                ) 
print(f'Length of merged df_emos: {len(df_emos)}')
del df, emos

df_groups = pd.read_csv(join(src, "inference/group_inference_condensed.csv.gz"), 
                    compression="gzip",
                    sep=";",
                    usecols = ["id", "domain", #identifier
                    "group", "not_out", "out"], #pos emotions
                    dtype = DTYPES, 
                    #nrows=1000,
                    index_col=["id", "domain"]
                    )

df_inf = pd.merge(df_emos, df_groups, 
                left_index=True, right_index=True, #multi-index merge
                how="left" # left join to match inference with original df
                ) 
del df_groups, df_emos

print(f'Length of merged df_inf: {len(df_inf)}')

df_inf.to_csv(join(src, "german_newsguard_tweets_inference.csv.gz"),
                compression="gzip", index=True)