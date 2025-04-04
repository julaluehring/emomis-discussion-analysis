#!/bin/bash

key_dst=/home/jluehring/utilities/twitter_API_keys

key="name1"
source ${key_dst}/twitter_API_${key}.txt
cat ./conversation_IDs_1.txt | xargs -I _replace_ sh -c "twarc2 --bearer-token $bearer_token conversation --archive _replace_ /data/german_newsguard_tweets/2022/conversations/_replace_.jsonl" &

key="name2"
source ${key_dst}/twitter_API_${key}.txt
cat ./conversation_IDs_2.txt | xargs -I _replace_ sh -c "twarc2 --bearer-token $bearer_token conversation --archive _replace_ /data/german_newsguard_tweets/2022/conversations/_replace_.jsonl" &

key="name3"
source ${key_dst}/twitter_API_${key}.txt
cat ./conversation_IDs_3.txt | xargs -I _replace_ sh -c "twarc2 --bearer-token $bearer_token conversation --archive _replace_ /data/german_newsguard_tweets/2022/conversations/_replace_.jsonl" 

echo "Collected random 50% conversations!"