require(lme4)
require(lmerTest)
require(boot)

n_boot <- 10000
n_cores <- 25

args <- commandArgs(trailingOnly = TRUE)
src <- args[1]
dst <- "./users/"
if (!dir.exists(dst)) {
  dir.create(dst, recursive = TRUE)
}
user_data <- read.csv(file.path(src, "same_author_replies.csv"))
user_data$Bias <- abs(user_data$Orientation)

dvs <- c('anger_first', 'fear_first', 'disgust_first', 'sadness_first', 
         'joy_first', 'hope_first', 'pride_first')

formula_template <- "dv ~ Rating + 
  Bias + 
  anger_log + disgust_log + fear_log + sadness_log + 
  joy_log + pride_log + hope_log + 
  word_count_log + author.tweet_count_log +
  author.following_count_log + author.followers_count_log +
  author.tweet_count_first_log +
  (1|same_author_id)"

model_summaries <- list()
models <- list()

for (dv in dvs) {
  cat("Processing:", dv, "\n")
  
  current_formula <- as.formula(gsub("dv", dv, formula_template))

  models[[dv]] <- lmer(
    current_formula,
    data = user_data
  )
  
  saveRDS(models[[dv]], file = paste0(dst, dv, "_lmem.rds"))
  
  # bootstrap parameter uncertainty based on sampled residuals
  model <- models[[dv]]
  original_data <- user_data
  fitted_vals <- fitted(model)
  residuals_orig <- residuals(model, type = "response")

  bootstrap_uncertainty <- function(residuals, indices, 
                                    fitted_vals, original_data, 
                                    model_formula, dv) {
  
    # sample residuals with replacement using indices
    boot_residuals <- residuals[indices]
    
    # create new response variable by adding bootstrapped residuals to fitted values
    boot_response <- fitted_vals + boot_residuals

    # create new dataset with bootstrapped response
    boot_data <- original_data
    boot_data[[dv]] <- boot_response

    boot_model <- tryCatch({
      suppressWarnings({
        suppressMessages({
          lmer(model_formula, data = boot_data,
          control = lmerControl(check.conv.singular = "ignore"))
        })
      })
    }, error = function(e) NULL)
    
    if (!is.null(boot_model)) {
      boot_coeffs <- tryCatch({
        fixef(boot_model)
      }, error = function(e) {
        rep(NA, length(fixef(model)))  # Use original model for length reference
      })
      
      return(boot_coeffs)
    } else {
      return(rep(NA, length(fixef(model))))  # Use original model for length reference
    }
  }

  cat("Starting bootstrap with", n_boot, "iterations on", n_cores, "cores...\n")
  start_time <- Sys.time()

  boot_results <- boot(
    data = residuals_orig,
    statistic = bootstrap_uncertainty,
    R = n_boot,
    parallel = "multicore", # use parallel processing
    ncpus = n_cores,
    fitted_vals = fitted_vals,
    original_data = original_data,
    model_formula = current_formula,
    dv = dv
  )

  end_time <- Sys.time()
  elapsed_time <- as.numeric(difftime(end_time, start_time, units = "mins"))
  cat("Bootstrap completed in", round(elapsed_time, 2), "minutes\n")

  bootstrap_matrix <- boot_results$t
  colnames(bootstrap_matrix) <- names(fixef(model))

  write.csv(bootstrap_matrix, file.path(dst, paste0(dv, "_bootstraps.csv")), row.names = FALSE)

  # save coefficients and 95% confidence intervals
  coef_table <- coef(summary(model))
  coef_df <- data.frame(
    parameter = rownames(coef_table),
    estimate = coef_table[, "Estimate"],
    std_error = coef_table[, "Std. Error"],
    t_value = coef_table[, "t value"],
    p_value = coef_table[, "Pr(>|t|)"],
    stringsAsFactors = FALSE
  )
  
  rownames(coef_df) <- NULL

  # calculate 95% confidence intervals
  pLL <- apply(bootstrap_matrix, 2, quantile, probs = 0.025, na.rm = TRUE)
  pUL <- apply(bootstrap_matrix, 2, quantile, probs = 0.975, na.rm = TRUE)

  coef_df$pLL <- pLL[coef_df$parameter]
  coef_df$pUL <- pUL[coef_df$parameter]
  coef_df$dependent_variable <- dv

  # save coefficients and confidence intervals to CSV
  write.csv(coef_df, file.path(dst, paste0(dv, "_coefficients.csv")), row.names = FALSE)


  cat("Results saved for", dv, "\n\n")

}