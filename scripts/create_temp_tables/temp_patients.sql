-- create a temp table of all active and inactive patients

-- drop table if needed
DROP TEMPORARY TABLE IF EXISTS temp_patients;

CREATE TEMPORARY TABLE temp_patients AS
SELECT 
    p.PatNum,
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

