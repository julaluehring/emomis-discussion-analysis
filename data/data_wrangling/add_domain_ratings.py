# Author: Jula Luehring

import pandas as pd
import os
import sys
import pickle as pkl

DIR = sys.argv[1]
with open(os.path.join(DIR, "dtypes_config.pickle"), "rb") as file:
    DTYPES = pkl.load(file)

def add_ratings(dir, dtypes, parse_dates):
    # read files
    domain_tweets = pd.read_csv(os.path.join(dir,
                                             "domain_tweets.csv.gz"), 
                                compression="gzip", 
                                dtype=dtypes, parse_dates=parse_dates)
    newsguard = pd.read_csv(os.path.join(dir,
                                         "newsguard_de.csv.gz"), 
                                compression="gzip")

    # preprocess dtypes and dates
    newsguard.rename(columns={'Domain': 'domain'}, inplace=True)
    newsguard["month"] = pd.to_datetime(newsguard["Date"])\
        .dt.strftime("%Y-%m")
    newsguard.rename(columns={'Date': 'Rating_Date'}, inplace=True)
    domain_tweets["month"] = domain_tweets["created_at"]\
        .dt.strftime("%Y-%m")

    # merge
    tweet_ratings = pd.merge(domain_tweets, newsguard, 
                            on=["domain", "month"], 
                            how="left")

    # save merged dataframe
    tweet_ratings.to_csv(os.path.join(dir,"domain_tweets.csv.gz"), 
                        index=False, compression="gzip")


parse_dates = ["created_at", "author.created_at"]

add_ratings(
    dir=DIR,
    dtypes=DTYPES,
    parse_dates=parse_dates
)