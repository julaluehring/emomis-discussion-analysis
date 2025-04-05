import pandas as pd
import os
import pickle
import sys

## Notes:
# There are two dfs: c_ refers to ``conversations``, whereas d_ refers to ``domains``. 
# There are two sets of IDs: tweet IDs (tweet_ids) and conversation IDs (conv_ids)

# Step 1: Get a list of all sampled conversation IDs
def extract_ids(dir, conversations, chunk_size):
    print(f'Extracting IDs from {conversations}...')

    try:

        # using sets for faster lookup:
        c_conv_ids = set() 
        c_tweet_ids = set()

        # reading the conversations df chunk by chunk:
        with pd.read_csv(os.path.join(dir, conversations),
                        compression="gzip", usecols=["id", "conversation_id"],
                        dtype={"id":str, "conversation_id":str},
                        chunksize=chunk_size) as reader: 

            # extracting all unique IDs from the conversation dataset:         
            for chunk in reader: 
                c_conv_ids.update(chunk["conversation_id"].unique())
                c_tweet_ids.update(chunk["id"].unique())
        print(f'Found {len(c_tweet_ids)} tweet IDs and {len(c_conv_ids)} conversation IDs in the conversations df.')

        # returning the two sets of IDs to use later        
        return c_conv_ids, c_tweet_ids

    except Exception as e:
        print(f'An error occured during extract_ids: {str(e)}')
        raise e

# Step 2: Merge sampled conversations with conversation starters from ``domains``
def merge_starters(dir, domains, chunk_size, dtypes, c_conv_ids, c_tweet_ids, output_file):
    print(f'Merging conversation starters...')

    try:
        # extract matching rows from domains:
        print(f'Extracting all matching rows from {domains}...')
        d_matching_tweets = pd.DataFrame()
        with pd.read_csv(os.path.join(dir, domains), compression="gzip", 
                        dtype=dtypes, 
                        parse_dates=["created_at", "author.created_at", "Rating_Date"],
                        chunksize=chunk_size) as reader:
            for chunk in reader:
                matching_chunk = chunk[chunk["conversation_id"].isin(c_conv_ids)]
                d_matching_tweets = pd.concat([d_matching_tweets, matching_chunk])
        print(f'Found {len(d_matching_tweets)} related tweets in the domain data,')
        print(f'corresponding to {d_matching_tweets["conversation_id"].nunique()} unique conversation IDs.')
        print(f'There seem to be {(d_matching_tweets["id"] == d_matching_tweets["conversation_id"]).sum()} conversation starters.') 

        # merge datasets based on matching rows 
        print(f'Merging datasets based on matching tweet ID...')
        c_tweet_ids_df = pd.DataFrame(list(c_tweet_ids), columns=["id"])
        merged_tweets = pd.merge(d_matching_tweets, c_tweet_ids_df, on=["id"], how="inner")
        merged_tweets.to_csv(os.path.join(dir, output_file), mode="a",
                            index=False, header=True, compression="gzip")
        print(f'Merged {len(merged_tweets)} matching tweets.')

        # save merged tweet IDs for faster lookup 
        merged_ids = set(merged_tweets["id"])

        # return the merged tweet IDs
        return merged_ids

    except Exception as e:
        print(f'An error occurred during merge_starters: {str(e)}')
        raise e

# Step 3: Append missing tweets from ``conversation``to the output file
def append_conversations(dir, conversations, chunk_size, dtypes, output_file, merged_ids):
    print(f'Appending conversation tweets to {output_file} based on merged IDs...')

    try:
        with pd.read_csv(os.path.join(dir, conversations),
                        compression="gzip",
                        dtype=dtypes, 
                        parse_dates=["created_at", "author.created_at"],
                        chunksize=chunk_size) as reader:

            for chunk in reader:
                # finding the tweets in the chunk that not in the final df
                # and appending them to the csv:
                chunk[~(chunk["id"].isin(merged_ids))].to_csv(
                    os.path.join(dir, output_file), mode="a", index=False, 
                                                    header=False, compression="gzip")

    except Exception as e:
        print(f'Error occured during append_conversations: {str(e)}')
        raise e

# Step 4: Append missing tweets from ``domains``to the output file
def append_domains(dir, domains, chunk_size, dtypes, output_file, merged_ids):

    print(f'Appending missing domain tweets to {output_file} based on merged IDs...')

    try:
        with pd.read_csv(os.path.join(dir, domains),
                        compression="gzip",
                        parse_dates=["created_at", "author.created_at", "Rating_Date"],
                        dtype=dtypes, chunksize=chunk_size) as reader:

            for chunk in reader:
                # finding the tweets in the chunk that are not in the final df
                # and appending the missing tweets to the csv:
                chunk[~(chunk["id"].isin(merged_ids))].to_csv(os.path.join(dir, output_file), 
                                mode="a", index=False, 
                                header=False, compression="gzip")

    except Exception as e:
        print(f'Error occured during append_domains: {str(e)}')
        raise e

# Step 5: Call all functions in a main function
def main():
    dir = sys.argv[1]
    conversations = "conversation_tweets.csv.gz"
    domains = "domain_tweets.csv.gz"
    output_file = "german_newsguard_tweets.csv.gz"
    chunk_size = 500000
    with open(os.path.join(dir,"dtypes_config.pickle"), "rb") as file:
        dtypes = pickle.load(file)

    c_conv_ids, c_tweet_ids = extract_ids(dir, conversations, chunk_size)
    merged_ids = merge_starters(dir, domains, chunk_size, dtypes, c_conv_ids, c_tweet_ids, output_file)
    append_conversations(dir, conversations, chunk_size, dtypes, output_file, merged_ids)
    append_domains(dir, domains, chunk_size, dtypes, output_file, merged_ids)
    
# Final step: Execute the merge
if __name__ == "__main__":
    main()

print(f'Files merged successfully!')