# ================================================================
# Advanced Financial Hedging:
# Adaptive GARCH Model Selection + Monte Carlo VaR Simulation
# ================================================================
# Language : R
# Data     : USD/INR daily exchange rate (FRED series: DEXINUS)
# Logic    : Test for asymmetry via GJR-GARCH -> auto-select model
# Output   : Monte Carlo 30-day VaR/ES + Volatility Fan Chart
# ================================================================

# ── 1. PACKAGES ─────────────────────────────────────────────────
# install.packages(c("quantmod", "rugarch", "xts"))
library(quantmod)
library(rugarch)
library(xts)

# ── 2. DATA ─────────────────────────────────────────────────────
cat("\n[1] Loading USD/INR data locally from CSV...\n")

# Path to the CSV file (relative to project root)
raw_data <- read.csv("data/usd_inr_data.csv", row.names = 1)

# Convert into an xts time-series object
DEXINUS <- xts(raw_data$DEXINUS, order.by = as.Date(rownames(raw_data)))

# Clean and subset for the last 10 years
usd_inr <- na.omit(DEXINUS)
usd_inr <- usd_inr[paste0(Sys.Date() - 3650, "/")]

# Calculate log returns
log_ret <- na.omit(diff(log(usd_inr)))

cat("Observations :", nrow(log_ret), "\n")
cat("Date range   :", format(start(log_ret)), "to", format(end(log_ret)), "\n")

# ── 3. STEP 1 — TEST FOR ASYMMETRY USING GJR-GARCH ──────────────
cat("\n[2] Step 1: Fitting GJR-GARCH(1,1) to test for asymmetry...\n")

gjr_spec <- ugarchspec(
  variance.model     = list(model = "gjrGARCH", garchOrder = c(1, 1)),
  mean.model         = list(armaOrder = c(0, 0), include.mean = TRUE),
  distribution.model = "std"
)

gjr_fit <- ugarchfit(spec = gjr_spec,
                      data = coredata(log_ret),
                      solver = "hybrid")

gamma1 <- coef(gjr_fit)["gamma1"]
gamma_p <- gjr_fit@fit$matcoef["gamma1", 4]

cat("\n--- Asymmetry (Leverage Effect) Test ---\n")
cat("Gamma1 coefficient :", round(gamma1, 5), "\n")
cat("P-value             :", round(gamma_p, 4), "\n")

# ── 4. STEP 2 — AUTOMATIC MODEL SELECTION ───────────────────────
cat("\n[3] Step 2: Selecting final model based on test result...\n")

if (gamma_p < 0.05) {

  cat("-> Significant asymmetry detected (p < 0.05).\n")
  cat("-> GJR-GARCH(1,1) selected as final model.\n")
  final_fit  <- gjr_fit
  model_used <- "GJR-GARCH(1,1) with Student-t errors"

} else {

  cat("-> No significant asymmetry (p =", round(gamma_p, 4), ").\n")
  cat("-> Falling back to standard GARCH(1,1) - parsimonious & justified.\n")

  garch_spec <- ugarchspec(
    variance.model     = list(model = "sGARCH", garchOrder = c(1, 1)),
    mean.model         = list(armaOrder = c(0, 0), include.mean = TRUE),
    distribution.model = "std"  # Keep Student-t for fat tails
  )

  final_fit <- ugarchfit(spec = garch_spec,
                          data = coredata(log_ret),
                          solver = "hybrid")
  model_used <- "Standard GARCH(1,1) with Student-t errors"
}

cat("\nFinal model selected:", model_used, "\n")
cat("\n--- Final Model Coefficients ---\n")
print(round(coef(final_fit), 6))

# ── 5. INFORMATION CRITERIA COMPARISON ──────────────────────────
cat("\n--- Information Criteria Comparison ---\n")
cat("GJR-GARCH -> AIC:", round(infocriteria(gjr_fit)[1], 5),
    " BIC:", round(infocriteria(gjr_fit)[2], 5), "\n")

if (gamma_p >= 0.05) {
  cat("Std GARCH -> AIC:", round(infocriteria(final_fit)[1], 5),
      " BIC:", round(infocriteria(final_fit)[2], 5), "\n")
  cat("-> Lower BIC confirms standard GARCH is the superior specification.\n")
}

# ── 6. MONTE CARLO SIMULATION ────────────────────────────────────
cat("\n[4] Running Monte Carlo Simulation (10,000 paths, 30 days)...\n")

n_days  <- 30
n_paths <- 10000

mc_sim <- ugarchsim(final_fit,        # Uses whichever model was selected
                     n.sim       = n_days,
                     m.sim       = n_paths,
                     startMethod = "sample")

sim_returns <- fitted(mc_sim)
cum_returns <- colSums(sim_returns)

# ── 7. VaR CALCULATION ───────────────────────────────────────────
notional <- 1000000  # $1M USD exposure

VaR_30_95 <- quantile(cum_returns, 0.05)
VaR_30_99 <- quantile(cum_returns, 0.01)

# Expected Shortfall (CVaR) - average loss beyond VaR threshold
ES_95 <- -mean(cum_returns[cum_returns < VaR_30_95])
ES_99 <- -mean(cum_returns[cum_returns < VaR_30_99])

dollar_VaR_95 <- notional * abs(VaR_30_95)
dollar_VaR_99 <- notional * abs(VaR_30_99)
dollar_ES_95  <- notional * ES_95
dollar_ES_99  <- notional * ES_99

# ── 8. VISUALISATION ─────────────────────────────────────────────
cat("\n[5] Generating plots...\n")

last_price  <- as.numeric(tail(usd_inr, 1))
sim_prices  <- last_price * exp(apply(sim_returns, 2, cumsum))
price_mean  <- apply(sim_prices, 1, mean)
price_upper <- apply(sim_prices, 1, quantile, probs = 0.95)
price_lower <- apply(sim_prices, 1, quantile, probs = 0.05)

par(mfrow = c(1, 2))
on.exit(par(mfrow = c(1, 1)))  # Safely reset even if plot errors

# Plot 1: Return Distribution
hist(cum_returns * 100, breaks = 50, col = "#185FA5", border = "white",
     main = paste("30-Day Return Distribution\n(", model_used, ")"),
     xlab = "Cumulative Return (%)", ylab = "Frequency", prob = TRUE)
abline(v = VaR_30_95 * 100, col = "#A32D2D", lwd = 2, lty = 2)
legend("topleft",
       legend = paste("95% VaR:", round(VaR_30_95 * 100, 2), "%"),
       col = "#A32D2D", lty = 2, lwd = 2, bty = "n")

# Plot 2: Volatility Cone
plot(1:n_days, price_mean, type = "l", col = "black", lwd = 2,
     ylim = range(c(price_lower, price_upper)),
     main = "30-Day USD/INR Forecast & Volatility Band",
     xlab = "Days Ahead", ylab = "Exchange Rate (INR per $)")
polygon(c(1:n_days, rev(1:n_days)),
        c(price_upper, rev(price_lower)),
        col = rgb(0.09, 0.37, 0.65, alpha = 0.2), border = NA)
lines(1:n_days, price_upper, col = "#185FA5", lty = 2)
lines(1:n_days, price_lower, col = "#185FA5", lty = 2)
legend("topleft",
       legend = c("Expected Path", "90% Confidence Band"),
       col = c("black", "#185FA5"), lty = c(1, 2), lwd = c(2, 1), bty = "n")

# ── 9. BUSINESS RISK REPORT ──────────────────────────────────────
cat("\n==========================================\n")
cat("   MONTE CARLO RISK REPORT (30-DAY)\n")
cat("==========================================\n")
cat("Model Used         :", model_used, "\n")
cat("Current Rate (Rs/$):", round(last_price, 2), "\n")
cat("Notional Exposure  : $", format(notional, big.mark = ","), "\n")
cat("Simulation Paths   :", format(n_paths, big.mark = ","), "\n\n")

cat("--- 30-Day Value at Risk (VaR) ---\n")
cat("95% VaR : $", format(round(dollar_VaR_95), big.mark = ","),
    paste0(" (", round(abs(VaR_30_95) * 100, 2), "% drop)\n"))
cat("99% VaR : $", format(round(dollar_VaR_99), big.mark = ","),
    paste0(" (", round(abs(VaR_30_99) * 100, 2), "% drop)\n\n"))

cat("--- Expected Shortfall (CVaR) ---\n")
cat("95% ES  : $", format(round(dollar_ES_95), big.mark = ","),
    paste0(" (avg loss beyond 95% VaR)\n"))
cat("99% ES  : $", format(round(dollar_ES_99), big.mark = ","),
    paste0(" (avg loss beyond 99% VaR)\n"))
cat("==========================================\n")
