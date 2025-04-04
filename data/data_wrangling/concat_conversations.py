import pandas as pd
import glob
import os
import sys 
import pickle as pkl

DIR = sys.argv[1]
with open(os.path.join(DIR, "dtypes_config.pickle"), "rb") as file:
    DTYPES = pkl.load(file)

# defining a function to merge all the csvs in a directory 
def concat_convos(dir, print_header): #input arguments
    file_name = os.path.join(dir, "*.csv") #extracting only csv-files in repository
    file_paths = glob.glob(file_name) #using glob to get a list of all file paths that match the above pattern

    for i, file_path in enumerate(file_paths): #looping through each file
        df = pd.read_csv(file_path, usecols=usecols, 
                        dtype=DTYPES, 
                        parse_dates=parse_dates)
        df.to_csv("/data/german_newsguard_tweets/conversation_tweets.csv.gz", mode="a", header=print_header and (i==0), index=False, compression="gzip") #writing to one compressed csv

usecols = list(DTYPES.keys())
parse_dates = ["created_at", "author.created_at"]

#creating file and appending 2020 data
DIR_2020 = os.path.join(DIR, "2020/conversations_csv")
print_header = True
concat_convos(DIR_2020, print_header)
print("2020 done.")

#appending 2021
DIR_2021 = os.path.join(DIR,"2021/conversations_csv")
print_header = False
concat_convos(DIR_2021, print_header)
print("2021 done.")

#appending 2022
DIR_2022 = os.path.join(DIR, "2022/conversations_csv")
print_header = False
concat_convos(DIR_2022, print_header)
print("2022 done.")