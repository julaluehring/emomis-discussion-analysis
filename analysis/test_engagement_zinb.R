# R version 4.4.1
require(tidyverse)
require(purrr)
require(broom)
require(lmtest)
require(MASS)
require(DHARMa)
require(pscl) # zeroinfl()
require(gridExtra)
require(patchwork)
require(sandwich)
require(VGAM)
require(car)
require(boot)
require(parallel)
set.seed(636)

DATA_DIR <- "/raid5pool/tank/luehring/german_newsguard_tweets/discussions"
DF <- read_csv(file.path(DATA_DIR, 
                "matched_starters_mahalanobis_log_bias.csv"),
                col_types = cols())

iv <- c("Rating")
dvs <- c( "like_count", 
          "quote_count", 
          "retweet_count", 
          "reply_count")

covariates <- c(
  "Bias", 
  "anger_log", "fear_log", "disgust_log", "sadness_log", 
  "joy_log", "pride_log", "hope_log", 
  "word_count_log", 
  "author.followers_count_log", 
  "author.following_count_log",
  "author.tweet_count_log"
)


# rename Orientation column in DF to Bias
names(DF)[names(DF) == "Orientation"] <- "Bias"


# select data and drop missing values
df_regression <- na.omit(DF[, c(iv, dvs, covariates)])

# sample smaller dataset for testing
# df_regression <- df_regression[sample(nrow(df_regression), 100000), ]

# scale the following variables to range from 0 to 1
continuous_covariates <- c("anger_log", "fear_log", "disgust_log", "sadness_log", 
                           "joy_log", "pride_log", "hope_log", 
                           "word_count_log", 
                           "author.followers_count_log", 
                           "author.following_count_log",
                           "author.tweet_count_log")

df_regression[, continuous_covariates] <- lapply(df_regression[, continuous_covariates], scale)

# check for remaining data issues
check_data_issues <- function(data) {
  issues <- lapply(data, function(column) {
    list(
      NA_count = sum(is.na(column)),
      NaN_count = sum(is.nan(column)),
      Inf_count = sum(is.infinite(column)),
      Neg_count = sum(column < 0),
      Zero_count = sum(column == 0),
      Max= max(column, na.rm = TRUE),
      Min = min(column, na.rm = TRUE)
    )
  })
  
  issues_df <- do.call(rbind, lapply(issues, as.data.frame))
  issues_df <- cbind(column = names(data), issues_df)
  rownames(issues_df) <- NULL
  
  #save
  write.csv(issues_df, file.path("./negative_binomial/data_checks.csv"),
           row.names = FALSE)
  cat("Data issues:\n")
  print(issues_df)
  
}

check_data_issues(df_regression)


# loop through dvs and fit models
for (dv in dvs) {
  message("Fitting models for dv = ", dv)
  start_time <- Sys.time()
  
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
          warning("High multicollinearity detected for ", cov, ": ", vif_values[cov], 
                  " in model = ", dv, ". Skipping this covariate.")
          next
        }
      }

      # Zero-Inflated Negative Binomial Model
      zeroinfl_model <- zeroinfl(last_formula, data = df_regression, 
                                dist = "negbin",
                                na.action = na.omit, 
                                maxit=1000000
                                )

      current_predictors <- proposed_predictors
      last_model <- zeroinfl_model

      TRUE

    }, error = function(e) {
      message("Error fitting model for dv = ", dv, " and covariate = ", cov)
      message(e$message)

      FALSE
    })
    if (!successful_model) next
    
  }

  # save results of model with most predictors
  if (!is.null(last_model)) {

    # save raw model
    save(zeroinfl_model, 
         file = file.path(paste0("./negative_binomial/", dv, "_nb_zero_model.RData")))

    # save model summary
    zero_model_summary <- summary(zeroinfl_model)

    # extracting confidence intervals
    zeroinfl_ci <- confint(zeroinfl_model)

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


    # save as csv
    write.csv(summary_df, 
              file.path(paste0("./negative_binomial/", dv, "_nb_zero_coeffs.csv")),
              row.names = FALSE)

    # extract additional model information
    log_likelihood <- logLik(zeroinfl_model)
    aic <- AIC(zeroinfl_model)
    bic <- BIC(zeroinfl_model)

    # append model information as additional rows in the data frame
    zeroinfl_fit <- data.frame(
      logLik = log_likelihood,
      AIC = aic,
      BIC = bic,
      theta = zeroinfl_model$theta
    )

    # save as csv
    write.csv(zeroinfl_fit, 
              file.path(paste0("./negative_binomial/", dv, "_nb_zero_fit.csv")),
              row.names = FALSE)

    # create a grid of values for the main predictor (iv) for predictions
    binary_values <- c(0,1)

    # create a data frame with fixed values for covariates
    prediction_data <- expand.grid(
      Rating = binary_values,
      Bias = binary_values,
      anger_log = mean(df_regression$anger_log, na.rm = TRUE),
      fear_log = mean(df_regression$fear_log, na.rm = TRUE),
      disgust_log = mean(df_regression$disgust_log, na.rm = TRUE),
      sadness_log = mean(df_regression$sadness_log, na.rm = TRUE),
      joy_log = mean(df_regression$joy_log, na.rm = TRUE),
      pride_log = mean(df_regression$pride_log, na.rm = TRUE),
      hope_log = mean(df_regression$hope_log, na.rm = TRUE),
      word_count_log = mean(df_regression$word_count_log, na.rm = TRUE),
      author.followers_count_log = mean(df_regression$author.followers_count_log, na.rm = TRUE),
      author.following_count_log = mean(df_regression$author.following_count_log, na.rm = TRUE),
      author.tweet_count_log = mean(df_regression$author.tweet_count_log, na.rm = TRUE)
    )

    # generate predictions
    prediction_data$predicted_counts <- predict(zeroinfl_model, 
                                                  newdata = prediction_data, 
                                                  type = "response")

    # bootstrap confidence intervals of predicted values
    count_coefs <- unname(round(coef(zeroinfl_model, "count"), 4))
    zero_coefs <- unname(round(coef(zeroinfl_model, "zero"), 4))
    f <- function(data, i, newdata, count_coefs, zero_coefs, last_formula) {
      require(pscl)
      start_time <- Sys.time() 
      m <- zeroinfl(last_formula,
                    data = data[i, ],
                    dist = "negbin",
                    start = list(count = count_coefs, 
                                  zero = zero_coefs))
      mparams <- as.vector(coef(m))
      yhat <- predict(m, newdata, type = "response")
      cat("Completed in:", Sys.time() - start_time, "\n")
      return(c(mparams, yhat))
    }
    cl <- makeCluster(20)
    clusterExport(cl, 
      varlist = c("df_regression", 
                  "last_formula", 
                  "count_coefs", 
                  "zero_coefs", 
                  "prediction_data"))

    clusterEvalQ(cl, library(pscl))

    res <- boot(
      data = df_regression, 
      statistic = f, 
      R = 1000, 
      newdata = prediction_data,
      count_coefs = count_coefs,
      zero_coefs = zero_coefs,
      last_formula = last_formula,
      parallel = "snow", 
      ncpus = 25
      )

    stopCluster(cl)

    # save bootstrapped predicted values as csv
    write.csv(res$t, 
              file.path(
                paste0("./negative_binomial/", dv, "_zinb_predicted_boot.csv")),
              row.names = FALSE)

    num_params <- (length(count_coefs) + length(zero_coefs))
    yhat <- t(sapply(num_params + (1:nrow(prediction_data)), function(i) {
      out <- boot.ci(res, index = i, type = "perc") 
      with(out, c(Est = t0, pLL = percent[4], pUL = percent[5]))  
    }))

    prediction_data <- cbind(prediction_data, yhat)

    write.csv(prediction_data, 
                file.path(
                  paste0("./negative_binomial/", dv, "_zinb_predicted.csv")),
                row.names = FALSE)

    # simulate residuals 
    # (https://aosmith.rbind.io/2017/12/21/using-dharma-for-residual-checks-of-unsupported-models/#simulations-for-models-without-a-simulate-function)

    # predicted probabilities
    p <- predict(zeroinfl_model, type = "zero") # probabilities of zero
  
    # predicted counts
    mus <- predict(zeroinfl_model, type = "count") # expected counts

    sim1 <- rzinegbin( # simulate negative binomial data 
                    n = nrow(df_regression), # nob
                    size = zeroinfl_model$theta, # dispersion parameter
                    pstr0 = p,
                    munb = mus) 

    # simulate response vectors
    sim_response <- replicate(250, rzinegbin(n = nrow(df_regression),
                                   size = zeroinfl_model$theta,
                                   pstr0 = p,
                                   munb = mus) 
                                   )

    # now we can create a DHARMA object
    sim_res_zinb <- createDHARMa(
                    simulatedResponse = sim_response, # passing 250 simmulated dfs
                    observedResponse = df_regression[[dv]], # observed data
                    fittedPredictedResponse = predict(zeroinfl_model, type = "response"), # fitted values
                    integerResponse = TRUE) # integer response necessary for count data

    # plot residuals and save as pdf
    pdf(file.path(paste0("./negative_binomial/", dv, "_nb_zero_qq.pdf")), width=4.5, height=4.5)
    plotQQunif(simulationOutput = sim_res_zinb,
           testDispersion = FALSE,
           testUniformity = FALSE,
           testOutliers = FALSE)
    dev.off()

  }

  end_time <- Sys.time()
  message("Finished fitting models for dv = ", dv, " in ", round(as.numeric(end_time - start_time), 2))
}