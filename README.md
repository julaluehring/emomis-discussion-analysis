# Effects of misinformation on online interactions

Public repository for the data collection and analysis code for [LINK TO PAPER]. 

Here you find the scripts to reproduce the statistical analysis. Due to the size of the dataset, the data subsets are [this](https://osf.io/ach37/?view_only=72f3f04de55947c48bad52d84583e4f5) repository (currently view-only). After downloading this repository, place the data folder contained in the aforementioned OSF repository and copy it into the main directory of this repository (i.e. on the same level as the code folders).

## Reproduction of analysis
The repository is organized into two sections: ``data`` and ``analysis``. 

* ``data`` contains exemplary scripts for the data collection, wrangling, text processing and non-parametric matching. The resulting datasets are used for the statistical analysis. _Note._ Most of these steps cannot be reproduced (see Restrictions).
* In ``analysis``, you will find the scripts to reproduce the results of the statistical analysis. The datasets used for each analysis can be found [here](https://osf.io/ach37/?view_only=72f3f04de55947c48bad52d84583e4f5).

### Restrictions
There are two major restrictions to publishing all data and scripts required to fully reproduce the study: 

1. Data collection: Due to data protection reasons, Twitter's usage agreement for the use of its API, and the closed access of the Twitter academic API v2, we cannot publish the text of the tweets. We removed the tweet text, randomized author IDs and publish the datasets with the tweet or conversation IDs and the variables that were used in the statistical analysis, such as the emotion scores. 

2. NewsGuard scores: The NewsGuard database is proprietary, which is why we cannot publish NewsGuard domain labels or domain names. Since we collected our data based on the list of domains, the data collection cannot be reproduced without acquiring the NewsGuard database either.

## Data collection
We used the list of NewsGuard-rated domains to estimate the tweet volume with ``get_domain_counts.sh``, after which we downloaded all tweets mentioning any of the domains within the given time frame (but excluding retweets) in ``get_domain_counts.sh``. Using twarc, we converted the json-files into csv (see ``convert_domain_tweets_to_csv.sh`` and randomly selected conversation IDs from the domain tweets. IN a last step, we re-hydrated the full conversations with ``get_conversations.sh``. 

## Data wrangling
We created the merged dataset with ``concat_domains.py``, ``concat_conversations.py`` and ``merge_domains_with_convos.py``. In order to add the domain rating to the data, we created a superset of NewsGuard ratings for all relevant domains with timestamps. We then add the ratings to the dataset dynamically (based on the domain name and the date) with ``add_domain_ratings.py``. Lastly, we drop duplicates ``drop_duplicates.py``. 

We also created a pickle-file to save and load the data types when loading the data that we re-use in subsequent scripts (``config_dtypes.ipynb``). The pickle-file is stored with the data. 

## Inference
Here, we save all files for the emotion classification. First, we cleaned the text with ``prepare_text.py`` so that we can apply the ELECTRA-based classifier in ``infer_emotion.py`` (and merged back with the dataframe in ``merge_inference.py`` and adding additional variables in ``add_engagement_metrics.py``).

For the validation, we calculate the percentage agreement in ``shuffle_percentage_agreement.py``, compute F1s in ``bootstrap_f1.R``and plot the area under the curve in ``plot_ruc.ipynb``. 

## Non-parametric matching
For the non-parametric matching and subsequent analysis of discussions, we first subset only the discussions, i.e., the tweets that have received replies from our dataset (``subset_discussions.ipynb``). Then, we aggregate emotions and a list of covariates per discussion (``aggregate_starters.ipynb``) and news tweets (``aggregate_starters.ipynb``) separately. Now, we have the separate input datasets and scripts for matching: 

* ``match_starters.R``:
      * input: "discussions_starters_aggregates.csv"
      * output: "matched_starters.csv"
* ``match_replies.R``:
      * input: "discussions_replies_aggregates.csv"
      * ouput: "matched_replies.csv"
* ``match_first:replies.R``:
      * input: "first_replies_aggregates.csv"
      * output: "matched_replies_first.csv"

To evaluate the matching and plot: ``eval_matching.ipynb``

## Statistical analysis
The statistical analyses can be reproduced using the following dataset files: 
1. To run the regression models for the effects on emotions ``boot_discussions.py`` and to evaluate the results ``test_discussions.ipynb``
2. To test within-user differences: ``test_same_users.ipynb``
3. To run the zero-inflated negative binomial models to test the effects on engagement ``test_engagement_zinb.R`` 
4. For several robustness checks: ``explore_users.ipynb``, ``test_components.py``, ``visualize_components.ipynb``, ``test_newsguard_thresholds.ipynb``, ``boot_covariates.py``, ``test_covariates.ipynb``


## Scripts to reproduce figures from the article: 

* Figure 1 & Figure 2: plot_main_figures.ipynb
* Fig. S1: ``test_newsguard_thresholds.ipynb``
* Fig. S2: ``shuffle_percentage_agreement.py``
* Fig. S3: ``plot_ruc.ipynb``
* Fig. S4 & S5: ``test_covariates.ipynb``
* Fig. S6: ``eval_matching.ipynb``
* Fig. S7 & S8: ``test_discussions.ipynb``
* Fig. S9: ``test_same_users.ipynb``
* Fig. S10: ``test_engagement_zinb.R``
* Fig. S11 & S12: ``explore_users.ipynb``
* Fig. S13: ``visualize_components.ipynb``

