#!/bin/bash

cat ./domains_collected_2022.txt | xargs -I _replace_ sh -c 'twarc2 csv --input-data-type tweets --extra-input-columns "public_metrics.impression_count,edit_history_tweet_ids" /data/german_newsguard_tweets/2022/domain_tweets/_replace_.jsonl /data/german_newsguard_tweets/2022/domain_tweets_csv/_replace_.csv' 