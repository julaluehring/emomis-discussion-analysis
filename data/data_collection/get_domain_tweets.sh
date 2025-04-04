#!/bin/bash

key_dst=/home/jluehring/utilities/twitter_API_keys
start="2022-01-01"
end="2022-03-31"

key="name1"
source ${key_dst}/twitter_API_${key}.txt
cat ./domains_to_collect_1.txt | xargs -I _replace_ sh -c "twarc2 --bearer-token $bearer_token search --start-time $start --end-time $end --archive --no-context-annotations 'lang:de _replace_ -is:retweet' /data/german_newsguard_tweets/2022/domain_tweets/_replace_.jsonl" &

key="name2"
source ${key_dst}/twitter_API_${key}.txt
cat ./domains_to_collect_2.txt | xargs -I _replace_ sh -c "twarc2 --bearer-token $bearer_token search --start-time $start --end-time $end --archive --no-context-annotations 'lang:de _replace_ -is:retweet' /data/german_newsguard_tweets/2022/domain_tweets/_replace_.jsonl" &

key="name3"
source ${key_dst}/twitter_API_${key}.txt
cat ./domains_to_collect_3.txt | xargs -I _replace_ sh -c "twarc2 --bearer-token $bearer_token search --start-time $start --end-time $end --archive --no-context-annotations 'lang:de _replace_ -is:retweet' /data/german_newsguard_tweets/2022/domain_tweets/_replace_.jsonl" &

key="name4"
source ${key_dst}/twitter_API_${key}.txt
cat ./domains_to_collect_4.txt | xargs -I _replace_ sh -c "twarc2 --bearer-token $bearer_token search --start-time $start --end-time $end --archive --no-context-annotations 'lang:de _replace_ -is:retweet' /data/german_newsguard_tweets/2022/domain_tweets/_replace_.jsonl" &

key="name5"
source ${key_dst}/twitter_API_${key}.txt
cat ./domains_to_collect_5.txt | xargs -I _replace_ sh -c "twarc2 --bearer-token $bearer_token search --start-time $start --end-time $end --archive --no-context-annotations 'lang:de _replace_ -is:retweet' /data/german_newsguard_tweets/2022/domain_tweets/_replace_.jsonl" 

echo "Done"