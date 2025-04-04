import pandas as pd
import glob
import os
import pickle as pkl
import sys

DIR = sys.argv[1]

with open(os.path.join(DIR, "dtypes_config.pickle"), "rb") as file:
    DTYPES = pkl.load(file)
    
#select all of the above columns
dcolumns = list(DTYPES.keys())

#step 1: defining a function to merge all the csvs in a directory (I will have to do it three times)
def concat_domains(dir, year, round, print_header): #input arguments
    file_name = os.path.join(dir, "*.csv") #extracting only csv-files in repository
    file_paths = glob.glob(file_name) #using glob to get a list of all file paths that match the above pattern

    for i, file_path in enumerate(file_paths): #looping through each file
        df = pd.read_csv(file_path, 
                         dtype=DTYPES, 
                         usecols=dcolumns,
                        parse_dates=["created_at", "author.created_at"]) 
        domain = os.path.basename(file_path) #extracting the domain name from file name
        df["domain"] = domain[:-4] #adding domain name as column
        df["round"] = round #the round of data collection, i.e., intial or missing (second round)
        df["year"] = year #time frame
        df.to_csv("/data/german_newsguard_tweets/domain_tweets.csv.gz", 
                  mode="a", 
                  header=print_header and (i==0), 
                  index=False, compression="gzip") #writing to one compressed csv
    print("Done processing", round, "round for", year) #printing

#step 2: running per year
##2020
year = "2020"
dir_20 = os.path.join(DIR + year + "/domain_tweets_csv")
round = "initial"
print_header = True
concat_domains(dir_20, year, round, print_header)

##appending missing tweets to the same csv-file 
year = "2020"
round = "missing"
print_header = False
dir_20_mis= os.path.join(DIR + year + "/domain_tweets_missing_csv")
concat_domains(dir_20_mis, year, round, print_header)

##2021
year = "2021"
round = "initial"
dir_21 = os.path.join(DIR + year + "/domain_tweets_csv")
print_header = False
concat_domains(dir_21, year, round, print_header)

##2022
year = "2022"
round = "initial"
dir_22 = os.path.join(DIR + year + "/domain_tweets_csv")
print_header = False
concat_domains(dir_22, year, round, print_header)

##missing
year = "2022"
round = "missing"
dir_22_mis = os.path.join(DIR + year + "/domain_tweets_missing_csv")
print_header = False
concat_domains(dir_22_mis, year, round, print_header)

print("Processing complete.")