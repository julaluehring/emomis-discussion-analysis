require(boot)
require(readr)
require(tidyverse)
set.seed(636)


args <- commandArgs(trailingOnly = TRUE)
dv <- args[1]
src <- args[2]

cat("Loading model data for", dv, "...\n")

df <- read_csv(file.path(src, 
                "matched_starters.csv"),
                col_select = c("Rating", all_of(dv)),
                col_types = cols(
                  Rating = col_factor(levels = c("0", "1")),
                  !!dv := col_integer()
                )) %>%
  suppressMessages()
  
boot_means <- function(df, indices) {
  resampled_data <- df[indices, ]
  mean_trustworthy <- mean(resampled_data[[dv]][resampled_data$Rating == "0"], na.rm = TRUE)
  mean_untrustworthy <- mean(resampled_data[[dv]][resampled_data$Rating == "1"], na.rm = TRUE)
  return(c(mean_trustworthy, mean_untrustworthy))
}


start_time <- Sys.time()

res <- boot(data = df,
            statistic = boot_means, 
            R = 10000)

end_time <- Sys.time()
elapsed_time <- as.numeric(difftime(end_time, start_time, units = "mins"))
cat("Bootstrap completed in", round(elapsed_time, 2), "minutes\n")

bootstrap_results <- data.frame(
  replicate = 1:res$R,
  mean_trustworthy = res$t[, 1],
  mean_untrustworthy = res$t[, 2]
)

obs_mean_trustworthy <- mean(df[[dv]][df$Rating == "0"], na.rm = TRUE)
obs_mean_untrustworthy <- mean(df[[dv]][df$Rating == "1"], na.rm = TRUE)
boot_mean_trustworthy <- mean(bootstrap_results$mean_trustworthy)
boot_mean_untrustworthy <- mean(bootstrap_results$mean_untrustworthy)
ci_trustworthy <- quantile(res$t[, 1], c(0.025, 0.975))
ci_untrustworthy <- quantile(res$t[, 2], c(0.025, 0.975))

summary_df <- data.frame(
  group = c("0", "1"),
  original_mean = c(obs_mean_trustworthy, obs_mean_untrustworthy),
  bootstrap_mean = c(boot_mean_trustworthy, boot_mean_untrustworthy),
  ci_lower = c(ci_trustworthy[1], ci_untrustworthy[1]),
  ci_upper = c(ci_trustworthy[2], ci_untrustworthy[2])
)

# concenate the summaries
boot_file <- file.path("./engagement/", paste0(dv, "_means_boot.csv"))
summary_file <- file.path("./engagement/", paste0(dv, "_means_summary.csv"))

write.csv(bootstrap_results, boot_file, row.names = FALSE)
write.csv(summary_df, summary_file, row.names = FALSE)
