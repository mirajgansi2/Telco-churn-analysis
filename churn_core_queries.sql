/* =========================================================
   CUSTOMER CHURN ANALYSIS - CORE QUERY SET
   Table: customers_full  (this now holds your actual data)
   ========================================================= */

-- 1. OVERALL CHURN RATE
SELECT
    COUNT(*) AS total_customers,
    SUM(churnflag) AS churned_customers,
    ROUND(100.0 * SUM(churnflag) / COUNT(*), 2) AS churn_rate_pct
FROM customers_full;


-- 2. CHURN RATE BY CONTRACT TYPE
SELECT
    contract,
    COUNT(*) AS customers,
    SUM(churnflag) AS churned,
    ROUND(100.0 * SUM(churnflag) / COUNT(*), 2) AS churn_rate_pct
FROM customers_full
GROUP BY contract
ORDER BY churn_rate_pct DESC;


-- 3. CHURN RATE BY TENURE BUCKET
SELECT
    tenurebucket,
    COUNT(*) AS customers,
    SUM(churnflag) AS churned,
    ROUND(100.0 * SUM(churnflag) / COUNT(*), 2) AS churn_rate_pct,
    ROUND(AVG(monthlycharges), 2) AS avg_monthly_charges
FROM customers_full
GROUP BY tenurebucket
ORDER BY
    CASE tenurebucket
        WHEN '0-1 yr' THEN 1
        WHEN '1-2 yr' THEN 2
        WHEN '2-4 yr' THEN 3
        WHEN '4-5 yr' THEN 4
        ELSE 5
    END;


-- 4. CHURN RATE BY PAYMENT METHOD
SELECT
    paymentmethod,
    COUNT(*) AS customers,
    SUM(churnflag) AS churned,
    ROUND(100.0 * SUM(churnflag) / COUNT(*), 2) AS churn_rate_pct
FROM customers_full
GROUP BY paymentmethod
ORDER BY churn_rate_pct DESC;


-- 5. CHURN RATE BY INTERNET SERVICE TYPE
SELECT
    internetservice,
    COUNT(*) AS customers,
    SUM(churnflag) AS churned,
    ROUND(100.0 * SUM(churnflag) / COUNT(*), 2) AS churn_rate_pct
FROM customers_full
GROUP BY internetservice
ORDER BY churn_rate_pct DESC;


-- 6. REVENUE AT RISK
SELECT
    ROUND(SUM(CASE WHEN churn = 'Yes' THEN monthlycharges ELSE 0 END), 2) AS monthly_revenue_lost,
    ROUND(SUM(monthlycharges), 2) AS total_monthly_revenue,
    ROUND(100.0 * SUM(CASE WHEN churn = 'Yes' THEN monthlycharges ELSE 0 END)
          / SUM(monthlycharges), 2) AS pct_revenue_at_risk
FROM customers_full;


-- 7. IMPACT OF ADD-ON SERVICES ON CHURN
SELECT
    onlinesecurity,
    techsupport,
    COUNT(*) AS customers,
    SUM(churnflag) AS churned,
    ROUND(100.0 * SUM(churnflag) / COUNT(*), 2) AS churn_rate_pct
FROM customers_full
WHERE internetservice != 'No'
GROUP BY onlinesecurity, techsupport
ORDER BY churn_rate_pct DESC;


-- 8. SENIOR CITIZEN & DEPENDENTS SEGMENTATION
SELECT
    seniorcitizen,
    dependents,
    partner,
    COUNT(*) AS customers,
    ROUND(100.0 * SUM(churnflag) / COUNT(*), 2) AS churn_rate_pct
FROM customers_full
GROUP BY seniorcitizen, dependents, partner
ORDER BY churn_rate_pct DESC;


-- 9. HIGH-VALUE CUSTOMERS AT RISK (retention target list)
SELECT
    customerid,
    tenure,
    monthlycharges,
    contract,
    paymentmethod,
    internetservice,
    cltv,
    churnscore
FROM customers_full
WHERE churn = 'No'
  AND monthlycharges >= 70
  AND tenure <= 12
  AND contract = 'Month-to-month'
ORDER BY monthlycharges DESC;


-- 10. CHURN RATE BY MONTHLY CHARGE BUCKET
SELECT
    chargebucket,
    COUNT(*) AS customers,
    ROUND(100.0 * SUM(churnflag) / COUNT(*), 2) AS churn_rate_pct,
    ROUND(AVG(tenure), 1) AS avg_tenure
FROM customers_full
GROUP BY chargebucket
ORDER BY
    CASE chargebucket
        WHEN 'Low (<$35)' THEN 1
        WHEN 'Medium ($35-70)' THEN 2
        WHEN 'High ($70-100)' THEN 3
        ELSE 4
    END;


-- 11. PAPERLESS BILLING vs CHURN
SELECT
    paperlessbilling,
    COUNT(*) AS customers,
    ROUND(100.0 * SUM(churnflag) / COUNT(*), 2) AS churn_rate_pct
FROM customers_full
GROUP BY paperlessbilling;