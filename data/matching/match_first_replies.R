library("MatchIt")
library(readr)
library(arrow)
library(corrplot)
library(dplyr)
library("Hmisc")
library(knitr)
library("jtools")
library(stargazer)
library(ggplot2)
library(reshape2)

# Run in CMD: Rscript match_first_replies.R /raid5pool/tank/luehring/german_newsguard_tweets/discussions/
args <- commandArgs(trailingOnly = TRUE)
DIR_PATH <- args[1]
FILE_PATH <- file.path(DIR_PATH, "first_replies_aggregates.csv")
OUTPUT_PATH <- "./replies/first_replies/log/"

matching_df <- read_csv(FILE_PATH,
                col_types = cols(
                  conversation_id = col_character(),
                  id = col_character(),
                  Rating = col_double(),
                  Orientation = col_double(),

                  anger_log = col_double(),
                  fear_log = col_double(),
                  disgust_log = col_double(),
                  sadness_log = col_double(),
                  joy_log = col_double(),
                  pride_log = col_double(),
                  hope_log = col_double(),

                  anger_first = col_double(),
                  fear_first = col_double(),
                  disgust_first = col_double(),
                  sadness_first = col_double(),
                  joy_first = col_double(),
                  pride_first = col_double(),
                  hope_first = col_double(),
                  
                  word_count_log = col_double(),
                  author.followers_count_log = col_double(),
                  author.following_count_log = col_double(),
                  author.tweet_count_log = col_double(),
                  author.tweet_count_first_log = col_double()
                )
)

formula <- as.formula("Rating ~ 
                        Orientation +
                        anger_log + 
                        fear_log + 
                        disgust_log + 
                        sadness_log +
                        joy_log + 
                        pride_log + 
                        hope_log +
                        word_count_log +
                        author.followers_count_log +
                        author.following_count_log +
                        author.tweet_count_log +
                        author.tweet_count_first_log")

#replace infite values with NA 
matching_df <- data.frame(lapply(matching_df, 
                              function(x) ifelse(is.infinite(x), NA, x))) 

#replace NAs with 0
matching_df <- matching_df %>%
  mutate(across(everything(), 
          ~ifelse(is.na(.), 0, .)))


# Correlation Analysis
## Correlations between dependent and independent variables
dviv <- matching_df[c("Rating", 
                      "anger_first", "fear_first", "disgust_first", "sadness_first", 
                      "joy_first", "pride_first", "hope_first"
                      )]

means <- round(colMeans(dviv), 2)
std_devs <- round(apply(dviv, 2, sd), 2)
summary_stats <- data.frame(
                              Variable = names(dviv), 
                              Mean = means, 
                              SD = std_devs)

write.csv(summary_stats,
          file = file.path(OUTPUT_PATH, "summary_stats_first_dviv.csv"))

#define correlation function
correlation_matrix <- function(df, 
                               type = "pearson",
                               digits = 3, 
                               decimal.mark = ".",
                               use = "all", 
                               show_significance = TRUE, 
                               replace_diagonal = FALSE, 
                               replacement = ""){
  
  stopifnot({
    is.numeric(digits)
    digits >= 0
    use %in% c("all", "upper", "lower")
    is.logical(replace_diagonal)
    is.logical(show_significance)
    is.character(replacement)
  })
  #we need the Hmisc package for this
  require(Hmisc)
  
  #retain only numeric and boolean columns
  isNumericOrBoolean = vapply(df, function(x) is.numeric(x) | is.logical(x), logical(1))
  if (sum(!isNumericOrBoolean) > 0) {
    cat("Dropping non-numeric/-boolean column(s):", paste(names(isNumericOrBoolean)[!isNumericOrBoolean], collapse = ", "), "\n\n")
  }
  df = df[isNumericOrBoolean]
  
  #transform input data frame to matrix
  x <- as.matrix(df)
  
  #run correlation analysis using Hmisc package
  correlation_matrix <- Hmisc::rcorr(x, type = )
  R <- correlation_matrix$r # Matrix of correlation coeficients
  p <- correlation_matrix$P # Matrix of p-value 
  
  #transform correlations to specific character format
  Rformatted = formatC(R, format = "f", digits = digits, decimal.mark = decimal.mark)
  
  if (sum(R < 0) > 0) {
    Rformatted = ifelse(R > 0, paste0(" ", Rformatted), Rformatted)
  }
  
  #add significance levels if desired
  if (show_significance) {
    #define notions for significance levels; spacing is important.
    stars <- ifelse(is.na(p), "   ", ifelse(p < .001, "***", ifelse(p < .01, "** ", ifelse(p < .05, "*  ", "   "))))
    Rformatted = paste0(Rformatted, stars)
  }
  #build a new matrix that includes the formatted correlations and their significance stars
  Rnew <- matrix(Rformatted, ncol = ncol(x))
  rownames(Rnew) <- colnames(x)
  colnames(Rnew) <- paste(colnames(x), "", sep =" ")
  
  #replace undesired values
  if (use == "upper") {
    Rnew[lower.tri(Rnew, diag = replace_diagonal)] <- replacement
  } else if (use == "lower") {
    Rnew[upper.tri(Rnew, diag = replace_diagonal)] <- replacement
  } else if (replace_diagonal) {
    diag(Rnew) <- replacement
  }
  
  return(Rnew)
}

save_correlation_matrix = function(df, filename, ...) {
  write.csv2(correlation_matrix(df, ...), file = filename)
}

save_correlation_matrix(df = dviv,
                        filename = file.path(OUTPUT_PATH, "correlation_matrix_first_dviv.csv"),
                        digits = 2,
                        use = "lower")
                        
corr_matrix_dviv <- cor(dviv)
correlation_data_dviv <- melt(corr_matrix_dviv)

#plot heatmap using ggplot2
heatmap <- ggplot(correlation_data_dviv, aes(Var1, Var2, fill = value)) +
  geom_tile() + 
  scale_fill_gradient2(low = "white", 
                        mid  = "#60c4ec", 
                        high = "black",  
                        midpoint = 0.4) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(size = 14, angle = 45, hjust = 1),  
    axis.text.y = element_text(size = 14),
    axis.title = element_blank()
  )


svg(file.path(OUTPUT_PATH, "heatmap_first_dviv.svg"), 
                width = 8, height = 6)
print(heatmap)
dev.off()

pdf(file = file.path(OUTPUT_PATH, "heatmap_first_dviv.pdf"),
                      width = 8, height = 6)
print(heatmap)
dev.off()

## Correlation between Covariates
cov <- matching_df[c("Orientation",
                      "anger_log", "fear_log", "disgust_log", "sadness_log", 
                      "joy_log", "pride_log", "hope_log",
                      "word_count_log",
                      "author.followers_count_log",
                      "author.following_count_log",
                      "author.tweet_count_log",
                      "author.tweet_count_first_log")
                    ]

means <- round(colMeans(cov), 2)

#calculate standard deviation of each column
std_devs <- round(apply(cov, 2, sd), 2)

#combine means and standard deviations into a new dataframe
summary_stats_cov <- data.frame(Variable = names(cov), 
                              Mean = means, 
                              SD = std_devs)

#save as csv
write.csv(summary_stats_cov, 
          file = file.path(OUTPUT_PATH, "summary_stats_first_cov.csv")
          )

#save as latex table
stargazer(summary_stats_cov, type = "latex", 
          out = file.path(OUTPUT_PATH,"summary_stats_first_cov.tex")
      )

#create correlation matrix
save_correlation_matrix(df = cov,
                        filename = file.path(OUTPUT_PATH,"correlation_matrix_first_cov.csv"),
                        digits = 2,
                        use = "lower")

#save as latex table
stargazer(cov, type = "latex", 
          out = file.path(OUTPUT_PATH, "correlation_matrix_first_cov.tex")
          )

corr_matrix_cov <- cor(cov)
correlation_data_cov <- melt(corr_matrix_cov)

#plot heatmap using ggplot2
heatmap <- ggplot(correlation_data_cov, aes(Var1, Var2, fill = value)) +
  geom_tile() +
  scale_fill_gradient2(low = "white", 
                        mid  = "#60c4ec", 
                        high = "black",  
                        midpoint = 0.4) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(size = 14, angle = 45, hjust = 1),  
    axis.text.y = element_text(size = 14),
    axis.title = element_blank()
  )

svg(file.path(OUTPUT_PATH, "heatmap_first_cov.svg"), 
                width = 8, height = 6)
print(heatmap)
dev.off()

pdf(file = file.path(OUTPUT_PATH, "heatmap_first_cov.pdf"),
                      width = 8, height = 6)
print(heatmap)
dev.off()
  
# Matching
## Pre-Matching Object

print('Pre-Matching Object')
#constructing a pre-match matchit object
m.nomatch <- matchit(formula,
                      data = matching_df, 
                      method = NULL, 
                      distance = "glm")

summary_table <- summary(m.nomatch)
print('Problematic variables:')
print(summary_table$Problematic)

summary_final <- as.data.frame(summary_table$sum.all)
summary_final <- round(summary_final, digits = 4)
write.csv(summary_final, 
          file = file.path(OUTPUT_PATH, "summary_pre_match_first.csv")
          )

#save as latex table
stargazer(summary_final, type = "latex", 
          out = file.path(OUTPUT_PATH,"summary_pre_match_first.tex")
          )

## Nearest neighbor matching
### Mahalanobis distance
print('Mahalanobis distance')
m.out_nearest_mahalanobis <- matchit(formula,
                                      data = matching_df, 
                                      method = "nearest", 
                                      distance = "mahalanobis")

#save matched data
m.data_nearest_mahalanobis <- match.data(m.out_nearest_mahalanobis)
MATCHED_PATH <- file.path(DIR_PATH, "matched_replies_first_mahalanobis_log.csv")
write.csv(m.data_nearest_mahalanobis, file = MATCHED_PATH)

#save summary values after matching
summary_table <- summary(m.out_nearest_mahalanobis)
print('Mahalanobis problematic variables:')
print(summary_table$Problematic) 

summary_final <- as.data.frame(summary_table$sum.matched)
summary_final <- round(summary_final, digits = 4)
write.csv(summary_final, 
          file = file.path(OUTPUT_PATH,"summary_nearest_mahalanobis_first.csv")
          )

#save plot
pdf(file = file.path(OUTPUT_PATH, "mahalanobis_plot_first.pdf"),
      width = 8, height = 6)
plot(summary_table)
dev.off()

svg(file.path(OUTPUT_PATH, "mahalanobis_plot_first.svg"), 
                width = 8, height = 6)
plot(summary_table)
dev.off()
        
### GLM distance
print('GLM distance')
m.out_nearest_glm <- matchit(formula,
                              data = matching_df, 
                              method = "nearest", 
                              distance = "glm")

#save data
m.data_nearest_glm <- match.data(m.out_nearest_glm)
MATCHED_PATH <- file.path(DIR_PATH, "matched_replies_first_glm_log.csv")
write.csv(m.data_nearest_glm, file = MATCHED_PATH)

#save summary table
summary_table <- summary(m.out_nearest_glm)
print('GLM problematic variables:')
print(summary_table$Problematic) 

summary_final <- as.data.frame(summary_table$sum.matched)
summary_final <- round(summary_final, digits = 4)
write.csv(summary_final, 
            file = file.path(OUTPUT_PATH,"summary_nearest_glm_first.csv")
            )

#save plot
pdf(file = file.path(OUTPUT_PATH, "glm_plot_first.pdf"),
      width = 8, height = 6)
plot(summary_table)
dev.off()

svg(file.path(OUTPUT_PATH, "glm_plot_first.svg"), 
                width = 8, height = 6)
plot(summary_table)
dev.off()
