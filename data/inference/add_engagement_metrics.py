import pandas as pd
from os.path import join
import pickle
import sys

DATA_DIR = sys.argv[1]

#specify data types
with open(join(DATA_DIR, "dtypes_config.pickle"), "rb") as file:
    DTYPES = pickle.load(file)

#read in csv
df = pd.read_csv(join(DATA_DIR, 
                      "german_newsguard_tweets_inference.csv.gz"),
                    compression="gzip",
                    dtype=DTYPES,
                    parse_dates=["created_at"],
                    )

#modify columns
df.drop(columns=["Unnamed: 0"], inplace=True)
df.columns = [col.replace("public_metrics.", "") 
              if "public_metrics." in col 
              else col for col in df.columns]

df.columns = [col.replace("_v2", "") 
              if "_v2" in col 
              else col for col in df.columns]

#add columns
df["type"] = df.apply(lambda row: "starter" 
                      if row["conversation_id"] == row["id"]
                      else "reply", axis=1)

df["status"] = "incomplete"
df.loc[(df["type"] == "starter") & (df["reply_count"] == 0), 
       "status"] = "complete"

conversations = set(pd.read_csv(join(DATA_DIR, 
                                 "full_conversation_ids.csv"),
                            dtype=DTYPES)\
                    ["conversation_id"])


df.loc[df["conversation_id"].isin(conversations), 
       "status"] = "complete"

#save data
df.to_csv(join(DATA_DIR, 
               "german_newsguard_tweets_inference.csv.gz"),
            compression="gzip", 
            index=False)
