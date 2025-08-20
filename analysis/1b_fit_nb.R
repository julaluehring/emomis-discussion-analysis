# R version 4.4.1
require(tidyverse)
require(purrr)
require(broom)
require(lmtest)
require(MASS)
require(DHARMa)
require(car)
set.seed(636)
options(scipen = 999) 

# get the DV from command line argument
args <- commandArgs(trailingOnly = TRUE)
dv <- args[1]

src <- args[2]
dst <- "./nb/"
df <- read_csv(file.path(src, 
                "matched_starters_mahalanobis.csv"),
                col_types = cols()) %>%
      suppressMessages()


iv <- c("Rating")
covariates <- c(
  "Bias", 
  "anger_log", "fear_log", "disgust_log", "sadness_log", 
  "joy_log", "pride_log", "hope_log", 
  "word_count_log", 
  "author.followers_count_log", 
  "author.following_count_log",
  "author.tweet_count_log"
)

# --> DATA PREPARATION <-- 
# rename Orientation column in DF to Bias
names(df)[names(df) == "Orientation"] <- "Bias"

# select data and drop missing values
df_regression <- na.omit(df[, c(iv, dv, covariates)])

# scale the following variables to range from 0 to 1
continuous_covariates <- c("anger_log", "fear_log", "disgust_log", 
                           "sadness_log", 
                           "joy_log", "pride_log", "hope_log", 
                           "word_count_log",
                           "author.tweet_count_log",
                           "author.following_count_log",
                           "author.followers_count_log")


df_regression[, continuous_covariates] <- lapply(df_regression[, continuous_covariates], 
                                                function(x) c(scale(x)))


# --> MODEL FITTING <-- 
message("Fitting negative binomial models for dv = ", dv)
start_time <- Sys.time()

# Store all successful models for comparison
model_list <- list()
model_comparison <- data.frame()

# incrementally add predictors
current_predictors <- iv
last_model <- NULL

for (cov in covariates) {
  proposed_predictors <- c(current_predictors, cov)
    
  # prepare formula
  formula_str <- paste(dv, "~", paste(proposed_predictors, collapse = " + "))
  current_formula <- as.formula(formula_str)

  successful_model <- tryCatch({

    # Multicollinearity check
    if (length(proposed_predictors) > 1) { # VIF requires more than one predictor
      model_vif <- lm(current_formula, data = df_regression)
      vif_values <- vif(model_vif)

      # warning if multicollinearity detected
      if (any(vif_values > 3)) { # threshold for very high VIF
        warning("High multicollinearity detected for ", cov, ": ", vif_values[cov], 
                " in model = ", dv, ". Skipping this covariate.")
        next
      }
    }

    # fitting negative binomial model
    nb_model <- glm.nb(current_formula, 
                      data = df_regression,
                      na.action = na.omit,
                      maxit=10000)
    
    # store model info
    model_name <- paste(proposed_predictors, collapse = "_")
    model_list[[model_name]] <- nb_model
    
    model_comparison <- rbind(model_comparison, data.frame(
      model_name = model_name,
      n_predictors = length(proposed_predictors),
      AIC = AIC(nb_model),
      BIC = BIC(nb_model),
      logLik = as.numeric(logLik(nb_model)),
      theta = nb_model$theta,
      deviance = deviance(nb_model),
      stringsAsFactors = FALSE
    ))

    current_predictors <- proposed_predictors
    last_model <- nb_model

    TRUE

  }, error = function(e) {
    message("Error fitting model for dv = ", dv, " and covariate = ", cov)
    message(e$message)

    FALSE
  })
  if (!successful_model) next
    
} # end of model fitting

# --> MODEL SELECTION <-- 
if (nrow(model_comparison) > 0) {
  
  # find best model by AIC
  best_model_name <- model_comparison$model_name[which.max(model_comparison$n_predictors)]
  best_model <- model_list[[best_model_name]]
  write.csv(model_comparison, 
            file.path(dst, paste0(dv, "_nb_model_comparison.csv")),
            row.names = FALSE)

  model_coeffs <- tidy(best_model, conf.int = TRUE)
  model_coeffs$IRR <- exp(model_coeffs$estimate)
  model_coeffs$PC <- (model_coeffs$IRR - 1) * 100

  write.csv(model_coeffs,
            file.path(dst, paste0(dv, "_nb_summary.csv")),
            row.names = FALSE)

  # extract model fit information
  fit_stats <- glance(best_model)

  write.csv(fit_stats, 
            file.path(dst, paste0(dv, "_nb_fit.csv")),
            row.names = FALSE)

  # --> SAVE MODEL <--
  model_data <- list(
    model = best_model,
    data = df_regression,
    model_comparison = model_comparison,
    dv = dv,
    formula = formula(best_model),
    fitted_values = fitted(best_model),
    residuals = residuals(best_model, type = "response")
  )

  saveRDS(model_data, file.path(dst, paste0(dv, "_nb_model.rds")))

  # --> MODEL DIAGNOSTICS <--
  cat("Running DHARMa simulations for negative binomial...\n")
  resid_fit <- simulateResiduals(fittedModel = best_model,
                                    n = 1000,
                                    plot=FALSE,
                                    seed=636)
  saveRDS(resid_fit, file = file.path(dst, paste0(dv, "_nb_dharma.rds")))

  # print summary to terminal
  cat("\n=== MODEL SUMMARY ===\n")
  cat("Best model formula:", deparse(formula(best_model)), "\n")
  cat("AIC:", round(AIC(best_model), 2), "\n")
  cat("Theta:", round(best_model$theta, 4), "\n")
  cat("Rating coefficient:", round(coef(best_model)["Rating"], 4), "\n")
  cat("Rating IRR:", round(exp(coef(best_model)["Rating"]), 4), "\n")
} else {
  message("No successful models fitted")
}

end_time <- Sys.time()
elapsed_time <- as.numeric(difftime(end_time, start_time, units = "mins"))
cat("Completed ", dv, " in ", round(elapsed_time, 2), " mins\n")
