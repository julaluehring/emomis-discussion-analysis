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
set.seed(636)

args <- commandArgs(trailingOnly = TRUE)
src <- args[1]
dst <- args[2]

df <- read_csv(file.path(src, 
                "matched_starters.csv"),
                col_types = cols())

iv <- c("Rating")
dvs <- c("like_count", 
          "retweet_count", 
          "reply_count", 
          "quote_count")

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
    formula <- as.formula(formula_str)

    successful_model <- tryCatch({
      
      model <- glm(formula, data = df_regression, family = "poisson")

      current_predictors <- proposed_predictors
      last_model <- model

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

    # save as csv
    write.csv(tidy(last_model), 
              file.path(paste0(dst, dv, "_pois_coeffs.csv")),
              row.names = FALSE)

    write.csv(glance(last_model), 
              file.path(paste0(dst, dv, "_pois_fit.csv")),
              row.names = FALSE)

    # simulate residuals
    resid_fit <- simulateResiduals(fittedModel = last_model, 
                                    #n = 10, # increase later
                                    plot=FALSE,
                                    seed=636)

    pdf(file.path(paste0(dst, dv, "_pois_hist.pdf")), width=4.5, height=4.5)
    hist(resid_fit)
    dev.off()

    # plot residuals and save as pdf
    pdf(file.path(paste0(dst, dv, "_pois_qq.pdf")), width=4.5, height=4.5)
    plotQQunif(simulationOutput = resid_fit, 
           testDispersion = FALSE,
           testUniformity = FALSE,
           testOutliers = FALSE)
    dev.off()

    test_zero <- testZeroInflation(resid_fit)
    write.csv(glance(test_zero), 
              file.path(paste0(dst, dv, "_pois_zero_test.csv")),
              row.names = FALSE)

    # extract formula of last_model
    formula <- formula(last_model)

    # run zero-inflated modelå
    zeroinfl_model <- zeroinfl(formula, data = df_regression, dist = "poisson")

    # save raw model
    save(zeroinfl_model, 
         file = file.path(paste0(dst, dv, "_pois_zero_model.RData")))

    # save model summary
    zero_model_summary <- summary(zeroinfl_model)

    # # compute 95% confidence intervals
    # confint_count <- confint(zero_model_summary$count)
    # confint_zero <- confint(zero_model_summary$zero)

    # extract count model
    count_summary <- zero_model_summary$coefficients$count
    count_df <- as.data.frame(count_summary)
    count_df$component <- "count"  
    count_df$term <- rownames(count_df)
    # count_df$LCI <- confint_count[, 1]
    # count_df$UCI <- confint_count[, 2]

    # extract zero-inflated model
    zero_summary <- zero_model_summary$coefficients$zero
    zero_df <- as.data.frame(zero_summary)
    zero_df$component <- "zero"  
    zero_df$term <- rownames(zero_df)
    # zero_df$LCI <- confint_zero[, 1]
    # zero_df$UCI <- confint_zero[, 2]

    # combine count and zero-inflation components
    summary_df <- rbind(count_df, zero_df)

    # re-order columns for readability
    summary_df <- summary_df %>%
      dplyr::select(component, term, Estimate, `Std. Error`, `z value`, `Pr(>|z|)`)

    # save as csv
    write.csv(summary_df, 
              file.path(paste0(dst, dv, "_pois_zero_coeffs.csv")),
              row.names = FALSE)

    # extract additional model information
    log_likelihood <- logLik(zeroinfl_model)
    aic <- AIC(zeroinfl_model)
    bic <- BIC(zeroinfl_model)

    # append model information as additional rows in the data frame
    zeroinfl_fit <- data.frame(
      logLik = log_likelihood,
      AIC = aic,
      BIC = bic
    )

    # save as csv
    write.csv(zeroinfl_fit, 
              file.path(paste0(dst, dv, "_pois_zero_fit.csv")),
              row.names = FALSE)

    # # bootstrap / simulate residuals (https://aosmith.rbind.io/2017/12/21/using-dharma-for-residual-checks-of-unsupported-models/#simulations-for-models-without-a-simulate-function)

    # # extract counts and mus
    # p <- predict(zeroinfl_model, type = "zero") # probabilities of zero
    # mus <- predict(zeroinfl_model, type = "count") # expected counts

    # simulate_zip <- function(n, pstr0, lambda) {
    #   structural_zeros <- rbinom(n, size = 1, prob = pstr0)
    #   poisson_counts <- rpois(n, lambda = lambda)
    #   simulated_data <- ifelse(structural_zeros == 1, 0, poisson_counts)
    #   return(simulated_data)
    # }

    # # simulate datasets
    # sim_response <- replicate(250, simulate_zip(n = nrow(df_regression), 
    #                                             pstr0 = p, 
    #                                             lambda = mus))

    # print(sim_response)

    # # create DHARMa object
    # sim_res_zip <- createDHARMa(
    #     simulatedResponse = sim_response,
    #     observedResponse = df_regression[[dv]],
    #     fittedPredictedResponse = predict(zeroinfl_model, type = "response"),
    #     integerResponse = TRUE)


    # # save qqplot as pdf
    # pdf(file.path(paste0(dst, dv, "_pois_zero_qq.pdf")), width=4.5, height=4.5)
    # plotQQunif(sim_res_zip, testDispersion = FALSE, testUniformity = FALSE, testOutliers = FALSE)
    # plot(sim_res_zinb)
    # dev.off()

    # pdf(file.path(paste0(dst, dv, "_pois_zero_fit_hist.pdf")), width=4.5, height=4.5)
    # hist(sim_res_zip)
    # dev.off()
  }

  end_time <- Sys.time()
  message("Finished fitting models for dv = ", dv, " in ", round(as.numeric(end_time - start_time), 2))
}