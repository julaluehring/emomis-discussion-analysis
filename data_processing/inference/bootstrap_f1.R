# STEP 8: EVALUATE THE ML PERFORMANCE WITH OPTIMAL CUTPOINTS AND BOOTSTRAPPED CONFIDENCE INTERVALS.
library(readr)
library(dplyr)
library(cutpointr)
library(ggplot2)
set.seed(63)

#start from terminal with Rscript bootstrap_f1.R "your file path"
args <- commandArgs(trailingOnly = TRUE)
file_path <- args[1] 
emo_df <- read_csv(file.path(file_path, "emotion_validation_mode.csv"))
emo_df <- emo_df %>% select(-Text) #remove text column

emotions <- list(
  list(name = "Anger", inference = "anger_inference", manual = "anger_manual"),
  list(name = "Joy", inference = "joy_inference", manual = "joy_manual"),
  list(name = "Sadness", inference = "sadness_inference", manual = "sadness_manual"),
  list(name = "Fear", inference = "fear_inference", manual = "fear_manual"),
  list(name = "Disgust", inference = "disgust_inference", manual = "disgust_manual"),
  list(name = "Enthusiasm", inference = "enthusiasm_inference", manual = "enthusiasm_manual"),
  list(name = "Pride", inference = "pride_inference", manual = "pride_manual"),
  list(name = "Hope", inference = "hope_inference", manual = "hope_manual")
)


validation_results <- list()

for (emotion in emotions) {
  print(emotion$name)
  inference_col <- emo_df[[emotion$inference]]
  manual_col <- emo_df[[emotion$manual]]
  emotion_result <- cutpointr(
    data = emo_df,
    x = inference_col,
    class = manual_col,
    method = maximize_metric,
    metric = F1_score,
    boot_runs = 10000,  #increase for more stable results
    pos_class = 1,
    neg_class = 0,
    direction = ">="
  ) %>%
    add_metric(list(precision, recall)) %>%
    select(optimal_cutpoint, recall, precision, F1_score, acc, boot)

  f1_ci <- boot_ci(emotion_result, "F1_score", in_bag = FALSE, alpha = 0.05)
  precision_ci <- boot_ci(emotion_result, "precision", in_bag = FALSE, alpha = 0.05)
  recall_ci <- boot_ci(emotion_result, "recall", in_bag = FALSE, alpha = 0.05)
  
  f1_ci_lower <- f1_ci %>% filter(quantile == 0.025) %>% pull(values)
  f1_ci_upper <- f1_ci %>% filter(quantile == 0.975) %>% pull(values)
  
  precision_ci_lower <- precision_ci %>% filter(quantile == 0.025) %>% pull(values)
  precision_ci_upper <- precision_ci %>% filter(quantile == 0.975) %>% pull(values)
  
  recall_ci_lower <- recall_ci %>% filter(quantile == 0.025) %>% pull(values)
  recall_ci_upper <- recall_ci %>% filter(quantile == 0.975) %>% pull(values)

  emotion_result <- emotion_result %>%
    mutate(
      F1_ci_lower = f1_ci_lower,
      F1_ci_upper = f1_ci_upper,
      precision_ci_lower = precision_ci_lower,
      precision_ci_upper = precision_ci_upper,
      recall_ci_lower = recall_ci_lower,
      recall_ci_upper = recall_ci_upper,
      error = 1 - acc
    ) %>%
    select(optimal_cutpoint, F1_score, F1_ci_lower, F1_ci_upper,
           precision, precision_ci_lower, precision_ci_upper,
           recall, recall_ci_lower, recall_ci_upper, acc, error)

validation_results[[emotion$name]] <- emotion_result
}

validation_results_df <- bind_rows(validation_results, .id = "emotion")

#calculate macro average for each metric and add in another row called "Macro"
macro_avg <- validation_results_df %>%
  summarise(
    F1_score = mean(F1_score),
    precision = mean(precision),
    recall = mean(recall),
    acc = mean(acc),
    error = mean(error)
  ) %>%
  mutate(emotion = "Macro")

validation_results_df <- bind_rows(validation_results_df, macro_avg)

write.csv(validation_results_df, "~/emomis/emomis-discussion-analysis/inference/emotions/validation_results_collapsed.csv", 
              row.names = FALSE)

macro_f1 <- validation_results_df %>%
    filter(emotion == "Macro") %>%
    pull(F1_score)

p <- validation_results_df %>% 
    filter(emotion != "Macro") %>%
    ggplot(aes(
        y = emotion,
        x = F1_score,
        ymin = F1_ci_lower,
        ymax = F1_ci_upper
         )) + 
        geom_errorbarh(aes(xmin = F1_ci_lower, xmax = F1_ci_upper), height = 0.2) +
        geom_point(size=4) + 
        geom_text(aes(label = round(F1_score, 2)), 
                     vjust = -0.5, 
                     hjust = 0.5,
                     size=7) +
        geom_vline(xintercept = macro_f1, 
                     linetype="dashed", 
                     color = "red", 
                     alpha=0.3) +
        theme_classic() +
        theme(
            axis.text.x = element_text(size=20),
            axis.text.y = element_text(size=20),
            axis.title.x = element_text(size = 24, vjust=-0.3),
            axis.title.y = element_text(size = 24),
            title = element_text(size = 24)
            )+
       labs(x = "F1", y = "Emotion")+
       scale_x_continuous(limits = c(0, 1))         


ggsave("~/emomis/emomis-discussion-analysis/inference/emotions/validation_results_collapsed.pdf", 
       plot = p,
       width = 12, 
       height = 10,
       bg = "white",
       units = "in", 
       dpi = 300)