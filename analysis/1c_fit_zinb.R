# R version 4.4.1
require(tidyverse)
require(purrr)
require(broom)
require(lmtest)
require(MASS)
require(DHARMa)
require(pscl) # zeroinfl()
require(car)
require(VGAM)
set.seed(636)

# get the DV from command line argument
args <- commandArgs(trailingOnly = TRUE)
dv <- args[1]
src <- args[2]
dst <- "./engagement/"

if (!dir.exists(dst)) {
  dir.create(dst, recursive = TRUE)
}

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

# df_regression <- df_regression[sample(nrow(df_regression), 10000), ]

# scale the following variables to range from 0 to 1
continuous_covariates <- c("anger_log", "fear_log", "disgust_log", 
                           "sadness_log", 
                           "joy_log", "pride_log", "hope_log", 
                           "word_count_log", 
                           "author.followers_count_log", 
                           "author.following_count_log",
                           "author.tweet_count_log")

df_regression[, continuous_covariates] <- lapply(df_regression[, continuous_covariates], scale)

# --> MODEL FITTING <-- 
message("Fitting ZINB for dv = ", dv)
start_time <- Sys.time()

# store all successful models for comparison
model_list <- list()
model_comparison <- data.frame()

# incrementally add predictors
current_predictors <- iv
last_model <- NULL

for (cov in covariates) {
  proposed_predictors <- c(current_predictors, cov)
    
  # prepare formula
  formula_str <- paste(dv, "~", paste(proposed_predictors, collapse = " + "))
  last_formula <- as.formula(formula_str)

  successful_model <- tryCatch({

    # Multicollinearity check
    if (length(proposed_predictors) > 1) { # VIF requires more than one predictor
      model_vif <- lm(last_formula, data = df_regression)
      vif_values <- vif(model_vif)

      # warning if multicollinearity detected
      if (any(vif_values > 5)) { # threshold for very high VIF
        warning("High multicollinearity detected for ", cov, ": ", 
                if(is.matrix(vif_values)) max(vif_values[cov,]) else vif_values[cov], 
                " in model = ", dv, ". Skipping this covariate.")
        return(FALSE)
      }
    }

    # fitting zero-inflated negative binomial model
    zeroinfl_model <- zeroinfl(last_formula, 
                              data = df_regression, 
                              dist = "negbin",
                              na.action = na.omit,
                              control = zeroinfl.control(
                                method = "Nelder-Mead",
                                maxit = 10000, # increase max iterations
                                tol = 1e-8)) # set tolerance for convergence
  
    if (is.null(zeroinfl_model$converged) || !zeroinfl_model$converged) {
      warning("Model failed to converge for predictors: ", paste(proposed_predictors, collapse = ", "))
      return(FALSE)
    }

    model_name <- paste(proposed_predictors, collapse = "_")
    model_list[[model_name]] <- zeroinfl_model

    model_comparison <- rbind(model_comparison, data.frame(
      model_name = model_name,
      n_predictors = length(proposed_predictors),
      AIC = AIC(zeroinfl_model),
      BIC = BIC(zeroinfl_model),
      stringsAsFactors = FALSE
    ))

    current_predictors <- proposed_predictors
    last_model <- zeroinfl_model

    TRUE

  }, error = function(e) {
    message("Error fitting model for dv = ", dv, " and covariate = ", cov)
    message(e$message)

    FALSE
  })

  if (!successful_model) next
    
} # end of model fitting

# save model comparison results
write.csv(model_comparison, 
            file.path(dst, paste0(dv, "_zinb_model_comparison.csv")),
            row.names = FALSE)

# select the model with the most predictors
best_model_name <- model_comparison$model_name[which.max(model_comparison$n_predictors)]
best_model <- model_list[[best_model_name]]

# --> MODEL RESULTS PROCESSING <-- 
zero_model_summary <- summary(best_model)

# extracting confidence intervals
zeroinfl_ci <- confint(best_model)

count_ci <- zeroinfl_ci[grep("^count_", rownames(zeroinfl_ci)), , drop = FALSE]
zero_ci <- zeroinfl_ci[grep("^zero_", rownames(zeroinfl_ci)), , drop = FALSE]
count_coef <- zero_model_summary$coefficients$count
zero_coef <- zero_model_summary$coefficients$zero
theta_coef <- count_coef["Log(theta)", , drop = FALSE]
count_coef <- count_coef[rownames(count_coef) != "Log(theta)", , drop = FALSE]
  
count_df <- data.frame(
    component = "count",
    term = rownames(count_coef), 
    estimate = count_coef[, "Estimate"],
    std_error = count_coef[, "Std. Error"],
    p_value = count_coef[, "Pr(>|z|)"],
    row.names = NULL
  )

zero_df <- data.frame(
    component = "zero",
    term = rownames(zero_coef), 
    estimate = zero_coef[, "Estimate"],
    std_error = zero_coef[, "Std. Error"],
    p_value = zero_coef[, "Pr(>|z|)"],
    row.names = NULL
  )

count_ci_df <- data.frame(
    component = "count",
    term = sub("^count_", "", rownames(count_ci)), # remove "count_" prefix
    conf_low = count_ci[, 1],
    conf_high = count_ci[, 2],
    row.names = NULL
  )

zero_ci_df <- data.frame(
    component = "zero",
    term = sub("^zero_", "", rownames(zero_ci)), # remove "zero_" prefix
    conf_low = zero_ci[, 1],
    conf_high = zero_ci[, 2],
    row.names = NULL
  )
print(zero_ci_df)

theta_df <- data.frame(
    component = "theta",
    term = "Log(theta)",
    estimate = theta_coef[, "Estimate"],
    std_error = theta_coef[, "Std. Error"],
    p_value = theta_coef[, "Pr(>|z|)"],
    conf_low = NA,
    conf_high = NA, 
    row.names = NULL
  )

count_summary <- merge(count_df, count_ci_df, by = c("component", "term"))
zero_summary <- merge(zero_df, zero_ci_df, by = c("component", "term"))
summary_df <- rbind(count_summary, zero_summary, theta_df)

write.csv(summary_df, 
            file.path(dst, paste0(dv, "_zinb_summary.csv")),
            row.names = FALSE)

# extract additional model fit information
log_likelihood <- logLik(best_model)
aic <- AIC(best_model)
bic <- BIC(best_model)

# append model information as additional rows in the data frame
zeroinfl_fit <- data.frame(
    logLik = as.numeric(log_likelihood),
    AIC = aic,
    BIC = bic,
    theta = best_model$theta
  )

# save as csv
write.csv(zeroinfl_fit, 
            file.path(dst, paste0(dv, "_zinb_fit.csv")),
            row.names = FALSE)

# --> save model <--
model_data <- list(
    model = best_model,
    data = df_regression,
    dv = dv,
    formula = best_model$formula,
    fitted_values = fitted(best_model),
    residuals = residuals(best_model, type = "response"),
    count_coeffs = coef(best_model, "count"),
    zero_coeffs = coef(best_model, "zero")
  )

saveRDS(model_data, file.path(dst, paste0(dv, "_zinb_model.rds")))

# --> MODEL DIAGNOSTICS <--
# predicted probabilities
p <- predict(best_model, type = "zero") # probabilities of zero
  
# predicted counts
mus <- predict(best_model, type = "count") # expected counts

cat("Running DHARMa simulations...\n")

# simulate response vectors
sim_response <- replicate(1000, rzinegbin(
    n = nrow(df_regression),
    size = best_model$theta,
    pstr0 = p,
    munb = mus
  ))

# now we can create a DHARMA object
sim_res_zinb <- createDHARMa(
                  simulatedResponse = sim_response, # passing 1000 simulated dfs
                  observedResponse = df_regression[[dv]], # observed data
                  fittedPredictedResponse = predict(best_model, type = "response"), # fitted values
                  integerResponse = TRUE) # integer response necessary for count data

saveRDS(sim_res_zinb, file = file.path(dst, paste0(dv, "_zinb_dharma.rds")))


end_time <- Sys.time()
elapsed_time <- as.numeric(difftime(end_time, start_time, units = "mins"))
cat("Completed ", dv, " in ", round(elapsed_time, 2), " mins\n")
