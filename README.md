# Adaptive GARCH-Based Volatility Modeling and Monte Carlo Risk Estimation for USD/INR

**Course:** Time Series Analysis & Forecasting (MPBA G512) — BITS Pilani, Pilani Campus
**Submitted To:** Dr. Udayan Chanda
**Group 7:** Prashant Singh, Lakshay Malik, Irshad Khan, Ayush Khandelwal, Shikhar Panthari

---

## 1. Introduction

Financial time series — especially exchange rate returns — exhibit volatility clustering, conditional heteroskedasticity, and excess kurtosis, which violate the constant-variance and normality assumptions of classical time series models. The USD/INR exchange rate is critical to India's trade competitiveness, inflation, and corporate risk management, making accurate volatility modeling essential for hedging and financial planning.

This project models the conditional volatility of USD/INR returns using GARCH-class models, tests for asymmetric ("leverage") effects, and uses Monte Carlo simulation to estimate forward-looking risk (Value at Risk and Expected Shortfall) over a 30-day horizon.

## 2. Problem Statement

Traditional risk models assume i.i.d. returns with constant, symmetric volatility. Real financial markets show time-varying, clustered, and often asymmetric volatility — ignoring this leads to underestimated tail risk. This project examines time-varying and asymmetric USD/INR volatility and its effect on multi-period risk metrics.

## 3. Objectives

- Estimate volatility dynamics using the GARCH(1,1) framework
- Test for asymmetric volatility effects using the GJR-GARCH model
- Implement a data-driven model selection approach based on statistical significance
- Account for fat-tailed return distributions using the Student-t specification
- Validate model assumptions through a structured pre-diagnostic testing framework
- Generate forward-looking risk estimates using Monte Carlo simulation
- Compute and analyze Value at Risk (VaR) and Expected Shortfall (ES) over a 30-day horizon

## 4. Methodology / Project Flow

The analysis follows a **pre-diagnostic → model selection → simulation** pipeline:

```
Raw USD/INR price series
        │
        ▼
Log-return transformation  rₜ = ln(Pₜ) − ln(Pₜ₋₁)
        │
        ▼
Pre-diagnostic tests
   ├─ Stationarity   → Augmented Dickey-Fuller (ADF)
   ├─ Normality      → Jarque-Bera
   ├─ Serial corr.   → Ljung-Box on returns
   └─ Vol. clustering→ Ljung-Box on squared returns + ARCH-LM
        │
        ▼
Estimate GJR-GARCH(1,1) with Student-t errors
        │
        ▼
Test asymmetry coefficient γ₁ (H₀: γ₁ = 0)
   ├─ Significant   → retain GJR-GARCH(1,1)
   └─ Not significant → revert to standard GARCH(1,1)
        │
        ▼
Monte Carlo simulation (10,000 paths × 30-day horizon)
        │
        ▼
Value at Risk (VaR) & Expected Shortfall (ES) at 95% / 99%
```

### Model specifications

- **Mean equation:** `rₜ = μ + ϵₜ` (ARMA(0,0) — justified since autocorrelation is negligible)
- **GARCH(1,1):** `σₜ² = ω + αϵₜ₋₁² + βσₜ₋₁²`
- **GJR-GARCH(1,1):** `σₜ² = ω + αϵₜ₋₁² + γϵₜ₋₁²Iₜ₋₁ + βσₜ₋₁²`, where `Iₜ₋₁ = 1` if `ϵₜ₋₁ < 0`
- **Innovations:** Student-t distributed, `ϵₜ = σₜzₜ`, `zₜ ~ tᵥ(0,1)` — to capture fat tails
- **Risk measures:** `VaRₐ = Quantileₐ(Rₜ,ₕ)`, `ESₐ = E[Rₜ,ₕ | Rₜ,ₕ < VaRₐ]`

## 5. Data Description

| Parameter | Value |
|---|---|
| Source | Federal Reserve Economic Data (FRED) — series `DEXINUS` |
| Quotation | INR per USD |
| Sample Period | 15 April 2016 – 3 April 2026 |
| Observations | 2,489 daily log-return observations |
| Transformation | Log-differenced: `rₜ = ln(Pₜ/Pₜ₋₁)` |

## 6. Key Results

**Pre-diagnostic tests:**

| Test | Statistic | p-value | Result |
|---|---|---|---|
| ADF (log returns) | −13.02 | < 0.01 | Stationary |
| Jarque-Bera | 1,954.76 | < 2.2e−16 | Non-normal (fat tails) |
| Ljung-Box (returns, lag 12) | 24.95 | 0.015 | ARMA(0,0) retained (correlation negligible) |
| Ljung-Box (squared returns) | 231.67 | < 2.2e−16 | ARCH effects present |
| ARCH-LM | 139.24 | < 2.2e−16 | ARCH effects confirmed |

**Final model: GJR-GARCH(1,1) with Student-t errors**

| Coefficient | Estimate | Interpretation |
|---|---|---|
| μ | 0.000045 | Near-zero mean return (random walk) |
| α₁ | 0.0521 | 5.2% shock impact on variance |
| β₁ | 0.9622 | 96.2% variance persistence |
| γ₁ | −0.0336 (p = 0.0004) | Significant reverse-leverage effect |
| ν | 4.50 | Heavy tails (fat-tailed Student-t) |

Volatility persistence (α + β + γ/2) ≈ **0.9975**, indicating highly persistent but covariance-stationary volatility.

**30-day Monte Carlo risk estimates (10,000 paths, $1M notional exposure):**

| Metric | 95% | 99% |
|---|---|---|
| VaR | ~3.3% (~$33,000) | ~4.9%–5.1% (~$49,000–51,000) |
| Expected Shortfall (ES) | ~4.4%–4.5% (~$43,000–45,000) | ~6.2%–6.3% (~$61,700) |

USD/INR shows a **significant reverse-leverage effect** (negative γ₁): depreciation shocks amplify volatility more than appreciation shocks of the same size — consistent with asymmetric RBI intervention. A benchmark comparison against USD/EUR (symmetric GARCH, no significant asymmetry) validates that the GJR-GARCH selection is data-driven, not arbitrary.

## 7. Conclusion

The USD/INR return series is stationary, non-normal (fat-tailed), and exhibits strong volatility clustering with a statistically significant asymmetric (leverage) effect. This justifies a GJR-GARCH(1,1) model with Student-t innovations over a standard symmetric GARCH model. The resulting Monte Carlo-based VaR/ES estimates provide practical inputs for currency hedging and regulatory risk reporting. Suggested extensions include incorporating macroeconomic covariates (interest rate differentials, oil price shocks), HAR-GARCH modeling, and formal VaR backtesting (Kupiec, Christoffersen tests).

## 8. Repository Structure

```
garch-usdinr-volatility/
├── README.md
├── .gitignore
├── data/
│   └── usd_inr_data.csv        # Daily USD/INR exchange rate (FRED: DEXINUS)
├── scripts/
│   └── garch_var_analysis.R    # Full R analysis: diagnostics, GARCH/GJR-GARCH, Monte Carlo VaR/ES
└── report/
    └── Time_Series_Project.pdf # Full project report (methodology, results, findings)
```

## 9. How to Run

**Requirements:** R (≥ 4.0) with the following packages:

```r
install.packages(c("quantmod", "rugarch", "xts"))
```

**Run the analysis:**

```bash
git clone https://github.com/<your-username>/garch-usdinr-volatility.git
cd garch-usdinr-volatility
Rscript scripts/garch_var_analysis.R
```

The script will:
1. Load and clean the USD/INR data from `data/usd_inr_data.csv`
2. Run pre-diagnostic tests and fit a GJR-GARCH(1,1) model
3. Auto-select between GJR-GARCH and standard GARCH based on the significance of the asymmetry coefficient
4. Run a 10,000-path, 30-day Monte Carlo simulation
5. Print a VaR/ES risk report and generate return-distribution and volatility-cone plots

## 10. References

- Bollerslev, T. (1986). Generalized autoregressive conditional heteroskedasticity. *Journal of Econometrics*, 31(3), 307–327.
- Glosten, L. R., Jagannathan, R., & Runkle, D. E. (1993). On the relation between the expected value and the volatility of the nominal excess return on stocks. *The Journal of Finance*, 48(5), 1779–1801.
- McNeil, A. J., Frey, R., & Embrechts, P. (2015). *Quantitative Risk Management: Concepts, Techniques and Tools*. Princeton University Press.
- Basel Committee on Banking Supervision. (2016). *Minimum Capital Requirements for Market Risk (FRTB)*. Bank for International Settlements.
- Federal Reserve Bank of St. Louis. (2026). FRED Economic Data: DEXINUS. https://fred.stlouisfed.org
