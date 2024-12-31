CREATE TEMPORARY TABLE temp_patients AS
SELECT 
    p.PatNum,
    p.LName,
    p.FName,
    p.Birthdate,
    p.Gender,
    p.Zip,
    p.DateFirstVisit,
    p.PatStatus,
    p.EstBalance,
    p.Bal_0_30,
    p.Bal_31_60,
    p.Bal_61_90,
    p.BalOver90,
    p.InsEst,
    p.BalTotal
FROM patient p
WHERE p.PatStatus IN (0, 2);

-- All active and inactive patients


SELECT * 
INTO OUTFILE 'mdc_analytics/raw_data/temp_patients.csv'
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
FROM temp_patients;

-- export data for use in modeling workflow