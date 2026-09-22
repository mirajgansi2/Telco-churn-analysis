COPY customers
FROM 'D:\Telco\telco_churn_clean.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    DELIMITER ','
);