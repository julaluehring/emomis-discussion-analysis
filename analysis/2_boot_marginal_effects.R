library(marginaleffects)
library(dplyr)
library(pscl)
library(future.apply)
args <- commandArgs(trailingOnly = TRUE)

plan("multicore", workers = 20) # this works with marginaleffects
options(marginaleffects_parallel_inferences = TRUE)
options(marginaleffects_parallel_packages = c("pscl", "MASS"))

dv <- args[1]
src <- args[2]
n_boot <- as.numeric(args[3])

dst <- "./engagement"
if (!dir.exists(dst)) {
  dir.create(dst, recursive = TRUE)
}

full_model <- readRDS(file.path(
                        paste0(src), 
                        paste0(dv, "_zinb_model.rds"))
                        )
model <- full_model$model
formula <- full_model$formula
model$call$formula <- formula

# bootstrapping marginal effects
cat("Calculating marginal effects...\n")
# define function to bootstrap marginal effects
mfx <- avg_predictions(model, variables = "Rating")

cat("Bootstrapping with", n_boot, "replications...\n")
start_time <- Sys.time()

# bootstrap confidence intervals for predicted counts
boot <- inferences(mfx, 
                    method = "boot", # draws from the covariance matrix
                    R = n_boot, 
                    #verbose=TRUE # show progress
                    ) 

#save results
means_df <- as.data.frame(boot)
means_df$DV <- dv
means_df <- means_df %>%
      rename(
        Predicted = estimate,
        pLL = conf.low,
        pUL = conf.high)%>%
      dplyr::select(
        DV, Predicted, pLL, pUL)

write.csv(means_df, 
            file.path(dst, paste0(dv, "_mfx.csv")),
            row.names = FALSE)

end_time <- Sys.time()
elapsed_time <- as.numeric(difftime(end_time, start_time, units = "mins"))
cat("Completed ", dv, " in ", round(elapsed_time, 2), " mins\n")