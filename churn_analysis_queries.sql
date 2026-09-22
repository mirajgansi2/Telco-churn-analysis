/* =========================================================
   CUSTOMER CHURN ANALYSIS - SQL QUERY SET
   Dataset: IBM Telco Customer Churn (cleaned)
   Table: customers
   ========================================================= */

-- 1. OVERALL CHURN RATE
SELECT
    COUNT(*) AS total_customers,
    SUM(ChurnFlag) AS churned_customers,
    ROUND(100.0 * SUM(ChurnFlag) / COUNT(*), 2) AS churn_rate_pct
FROM customers;


-- 2. CHURN RATE BY CONTRACT TYPE
-- Month-to-month customers are classically the biggest churn risk
SELECT
    Contract,
    COUNT(*) AS customers,
    SUM(ChurnFlag) AS churned,
    ROUND(100.0 * SUM(ChurnFlag) / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY Contract
ORDER BY churn_rate_pct DESC;


-- 3. CHURN RATE BY TENURE BUCKET (customer lifecycle stage)
SELECT
    TenureBucket,
    COUNT(*) AS customers,
    SUM(ChurnFlag) AS churned,
    ROUND(100.0 * SUM(ChurnFlag) / COUNT(*), 2) AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2) AS avg_monthly_charges
FROM customers
GROUP BY TenureBucket
ORDER BY
    CASE TenureBucket
        WHEN '0-1 yr' THEN 1
        WHEN '1-2 yr' THEN 2
        WHEN '2-4 yr' THEN 3
        WHEN '4-5 yr' THEN 4
        ELSE 5
    END;


-- 4. CHURN RATE BY PAYMENT METHOD
SELECT
    PaymentMethod,
    COUNT(*) AS customers,
    SUM(ChurnFlag) AS churned,
    ROUND(100.0 * SUM(ChurnFlag) / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY PaymentMethod
ORDER BY churn_rate_pct DESC;


-- 5. CHURN RATE BY INTERNET SERVICE TYPE
SELECT
    InternetService,
    COUNT(*) AS customers,
    SUM(ChurnFlag) AS churned,
    ROUND(100.0 * SUM(ChurnFlag) / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY InternetService
ORDER BY churn_rate_pct DESC;


-- 6. REVENUE AT RISK: MONTHLY REVENUE LOST TO CHURNED CUSTOMERS
SELECT
    ROUND(SUM(CASE WHEN Churn = 'Yes' THEN MonthlyCharges ELSE 0 END), 2) AS monthly_revenue_lost,
    ROUND(SUM(MonthlyCharges), 2) AS total_monthly_revenue,
    ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN MonthlyCharges ELSE 0 END)
          / SUM(MonthlyCharges), 2) AS pct_revenue_at_risk
FROM customers;


-- 7. IMPACT OF ADD-ON SERVICES ON CHURN
-- Customers without security/support add-ons tend to churn more
SELECT
    OnlineSecurity,
    TechSupport,
    COUNT(*) AS customers,
    SUM(ChurnFlag) AS churned,
    ROUND(100.0 * SUM(ChurnFlag) / COUNT(*), 2) AS churn_rate_pct
FROM customers
WHERE InternetService != 'No'
GROUP BY OnlineSecurity, TechSupport
ORDER BY churn_rate_pct DESC;


-- 8. SENIOR CITIZEN & DEPENDENTS SEGMENTATION
SELECT
    SeniorCitizen,
    Dependents,
    Partner,
    COUNT(*) AS customers,
    ROUND(100.0 * SUM(ChurnFlag) / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY SeniorCitizen, Dependents, Partner
ORDER BY churn_rate_pct DESC;


-- 9. HIGH-VALUE CUSTOMERS AT RISK (charge bucket x churn)
-- Prioritization list for retention campaigns: high spend, still active, short tenure
SELECT
    customerID,
    tenure,
    MonthlyCharges,
    Contract,
    PaymentMethod,
    InternetService
FROM customers
WHERE Churn = 'No'
  AND MonthlyCharges >= 70
  AND tenure <= 12
  AND Contract = 'Month-to-month'
ORDER BY MonthlyCharges DESC;


-- 10. CHURN RATE BY MONTHLY CHARGE BUCKET
SELECT
    ChargeBucket,
    COUNT(*) AS customers,
    ROUND(100.0 * SUM(ChurnFlag) / COUNT(*), 2) AS churn_rate_pct,
    ROUND(AVG(tenure), 1) AS avg_tenure
FROM customers
GROUP BY ChargeBucket
ORDER BY
    CASE ChargeBucket
        WHEN 'Low (<$35)' THEN 1
        WHEN 'Medium ($35-70)' THEN 2
        WHEN 'High ($70-100)' THEN 3
        ELSE 4
    END;


-- 11. PAPERLESS BILLING vs CHURN
SELECT
    PaperlessBilling,
    COUNT(*) AS customers,
    ROUND(100.0 * SUM(ChurnFlag) / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY PaperlessBilling;


-- 12. COMBINED RISK SCORE VIEW (for Power BI import)
-- Flags each customer as Low/Medium/High risk using simple rule-based scoring
-- (mirrors what a logistic regression would roughly prioritize)
SELECT
    customerID,
    Contract,
    tenure,
    MonthlyCharges,
    PaymentMethod,
    InternetService,
    Churn,
    (
        CASE WHEN Contract = 'Month-to-month' THEN 2 ELSE 0 END +
        CASE WHEN tenure <= 12 THEN 2 ELSE 0 END +
        CASE WHEN PaymentMethod = 'Electronic check' THEN 1 ELSE 0 END +
        CASE WHEN OnlineSecurity = 'No' THEN 1 ELSE 0 END +
        CASE WHEN TechSupport = 'No' THEN 1 ELSE 0 END
    ) AS risk_score
FROM customers
ORDER BY risk_score DESC;
