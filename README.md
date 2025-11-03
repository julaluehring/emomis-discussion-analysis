# Quantifying the Causal Effects of Misinformation on Engagenemt and Emotions on Social Media

Public repository for the data collection and analysis code reproduce the statistical analysis. After downloading this repository, place the data folder into the main directory of this repository (i.e. on the same level as the ``analysis`` folder). 
We also provide an ``environment.yml``, with which you can re-create our conda environment and install all dependencies via the terminal (``conda env create -f environment.yml``).

## Reproduction of analysis
The repository is organized into two sections: ``data_processing`` and ``analysis``. 

* ``data_processing`` contains exemplary scripts for the data collection, wrangling, text processing and non-parametric matching. The resulting datasets are used for the statistical analysis. _Note._ Most of these steps cannot be reproduced (see Restrictions).
* In ``analysis``, you will find the scripts to reproduce all the results of the statistical analysis (i.e., all scripts in ``analysis``).

### Restrictions
There are two major restrictions to publishing all data and scripts required to fully reproduce the study: 

1. Data collection: Due to data protection reasons, Twitter's usage agreement for the use of its API, and the closed access of the Twitter academic API v2, we cannot publish the text of the tweets. We removed the tweet text, randomized author IDs and publish the datasets with the tweet or conversation IDs and the variables that were used in the statistical analysis, such as the emotion scores. 

2. NewsGuard scores: The NewsGuard database is proprietary, which is why we cannot publish NewsGuard domain labels or domain names. Since we collected our data based on the list of domains, the data collection cannot be reproduced without acquiring the NewsGuard database either.

## Data collection
We used the list of NewsGuard-rated domains to estimate the tweet volume with ``1_get_domain_counts.sh``, after which we downloaded all tweets mentioning any of the domains within the given time frame (but excluding retweets) in ``2_get_domain_counts.sh``. Using twarc, we converted the json-files into csv (see ``3_convert_json_to_csv.sh`` and randomly selected conversation IDs from the domain tweets. In a last step, we re-hydrated the full conversations with ``4_get_conversations.sh``. 

## Data wrangling
We created the merged dataset with ``1_concat_domains.py``, ``4_concat_conversations.py`` and ``5_merge_domains_with_convos.py``. In order to add the domain rating to the data, we created a superset of NewsGuard ratings for all relevant domains with timestamps (in ``2_create_newsguard_time_series``). We then add the ratings to the dataset dynamically (based on the domain name and the date) with ``3_add_domain_ratings.py``. Lastly, we drop duplicates ``6_drop_duplicates.py``.

We also created a pickle-file to save and load the data types when loading the data that we re-use in subsequent scripts (``7_config_dtypes.ipynb``). The pickle-file is stored with the data. 
By the end of this part, we created the dataset ``german_newsguard_tweets.csv.gz``, which was then used for all subsequent steps. 

## Inference
First, we cleaned the text with ``1_prepare_text.py`` so that we can apply the ELECTRA-based classifier in ``2_infer_emotion.py`` (and merge it back with the dataframe in ``3_merge_inference.py`` as well as adding additional variables in ``4_add_engagement_metrics.py``).

For the validation data (merged in ``5_merge_validation_data.py``), we calculated the percentage agreement in ``6_shuffle_percentage_agreement.py`` and plotted the area under the curve in ``7_plot_ruc.ipynb``. 


## Non-parametric matching
We subsetted only the discussions, i.e., the tweets that have received replies from our dataset (``1_subset_discussions.ipynb``). 

**If you want to reproduce the matching & analysis, you can start here with aggregating datasets for the a) replies and first replies in the discussions.** 

Then, we aggregated the datasets in ``2a_aggregate_replies.ipynb`` and ``2b_aggregate_starters.ipynb``.

Now, we have the separate input datasets and scripts for the matching: 

* ``3a_match_replies.R``:
      * input: "discussions_replies_aggregates.csv"
      * ouput: "matched_replies_mahalanobis.csv" & "matched_replies_glm.csv"
* ``3b_match_replies_first.R``:
      * input: "first_replies_aggregates.csv"
      * output: "matched_replies_first_mahalanobis.csv" & "matched_replies_first_glm.csv"

* ``3c_match_starters.R``:
      * input: "discussions_starters_aggregates.csv"
      * output: "matched_starters_mahalanobis.csv" & "matched_starters_glm.csv"

To evaluate the matching and plot: ``4_eval_matching.ipynb``.

## Statistical analysis
The statistical analyses can be reproduced using the following scripts: 
To test the effects on engagement and try the different Generalized Linear Models (``1a_fit_poisson.R``, ``1b_fit_nb.R`` and ``1c_fit_zinb.R``), bootstrap the marginal effects (``2_boot_marginal_effects.R``), and evaluate the models in ``3a_evaluate_zinb.Rmd`` and ``3b_plot_cdf.ipynb``.

To run the regression models for the effects on emotions (``4a_boot_discussions.py``), evaluate the results (``4b_test_discussions.ipynb``), test the false discovery rate (``4c_test_fdr.Rmd``). To test within-user differences (``5a_fit_lmem.R``, ``5b_evaluate_lmem.Rmd``) and describe user groups in our sample (``6_describe_users.ipynb``)
For several robustness checks, see ``7_test_components.py``), ``7_visualize_components.ipynb``, and ``7_test_newsguard_thresholds.ipynb``. 


## Scripts to reproduce figures from the article: 

* Fig. 1 (Panel b&c), Fig. 2 and Fig. 3: ``plot_main_figures.ipynb``
* Fig. S1: ``test_newsguard_thresholds.ipynb``
* Fig. S2: ``shuffle_percentage_agreement.py``
* Fig. S3: ``plot_ruc.ipynb``
* Fig. S4: ``eval_matching.ipynb``
* Fig. S5: ``plot_cdf.ipynb``
* Fig. S6 & S7: ``evaluate_zinb.Rmd``
* Fig. S8 & S9: ``test_discussions.ipynb``
* Fig. S10-S13: ``describe_users.ipynb``
* Fig. S14: ``visualize_components.ipynb``

