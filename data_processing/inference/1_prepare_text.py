import pandas as pd
import os
import re
import sys

#load data set with dtypes
dir = sys.argv[1]

df = pd.read_csv(os.path.join(dir,"german_newsguard_tweets.csv.gz"), 
                                compression="gzip",
                                usecols=["id", "domain", "lang", "text"],
                                dtype={"id": str, "domain":str, "lang":str, "text":str}, 
                                #nrows=10000, #testing
                )

print(f'Length of unprocessed df: {len(df)}')

#keep only german tweets where lang == "de"
df_de = df[df["lang"] == "de"]
print(f'Length of only German df: {len(df_de)}')

# clean text
def clean_text(df):
    tweet_text = df["text"].tolist()
    df_new = df.copy()
    tweet_text_lst_clean = []
    emoji_pattern = re.compile("["
                        u"\U0001F600-\U0001F64F"  # emoticons
                        u"\U0001F300-\U0001F5FF"  # symbols & pictographs
                        u"\U0001F680-\U0001F6FF"  # transport & map symbols
                        u"\U0001F700-\U0001F77F"  # alchemical symbols
                        u"\U0001F780-\U0001F7FF"  # Geometric Shapes Extended
                        u"\U0001F800-\U0001F8FF"  # Supplemental Arrows-C
                        u"\U0001F900-\U0001F9FF"  # Supplemental Symbols and Pictographs
                        u"\U0001FA00-\U0001FA6F"  # Chess Symbols
                        u"\U0001FA70-\U0001FAFF"  # Symbols and Pictographs Extended-A
                        u"\U00002702-\U000027B0"  # Dingbats
                        u"\U000024C2-\U0001F251" 
                        "]+", flags=re.UNICODE)
    
    for item in tweet_text:
        item_new = emoji_pattern.sub(r'', item) # remove emojis
        item_new = re.sub("https.*", "", item_new)  # remove links
        item_new = re.sub("@\w+", "", item_new) # remove @-handles
        item_new = item_new.replace('\\n', ' ') # remove line breaks
        item_new = item_new.replace('\\', '') # remove backslash
        tweet_text_lst_clean.append(item_new)
        
    df_new["text_cleaned"] = tweet_text_lst_clean
    return df_new

df_cleaned = clean_text(df_de)
print(f'Length of cleaned df: {len(df_cleaned)}')

df_cleaned.dropna(subset=["text_cleaned"], inplace=True) 
print(f'Length of cleaned df without NAs: {len(df_cleaned)}')

df_cleaned = df_cleaned[df_cleaned["text_cleaned"] != ""] #remove empty strings
print(f'Length of cleaned df without empty strings: {len(df_cleaned)}')

#save cleaned data
df_cleaned.to_csv(os.path.join(dir, "german_newsguard_text.csv.gz"), 
                            mode="w", compression="gzip", 
                            columns=["id", "domain", "text_cleaned"],
                            header=True)