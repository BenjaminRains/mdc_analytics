-- PatientBalances: Gets patient balances from the patient table aging columns
-- Uses the built-in aging columns in the patient table for more accurate balance information
-- Dependencies: None
-- Date filter: None (uses current balance data from patient table)

PatientBalances AS (
    -- Use the patient table's built-in aging columns instead of calculating manually
    SELECT
        PatNum,
        Bal_0_30 AS Balance0to30,
        Bal_31_60 AS Balance31to60,
        Bal_61_90 AS Balance61to90,
        BalOver90 AS BalanceOver90,
        InsEst AS InsuranceEstimate,
        BalTotal AS TotalBalance,
        -- Calculate aging percentages for analysis
        CASE 
            WHEN BalTotal = 0 THEN 0 
            ELSE (Bal_0_30 / BalTotal) * 100 
        END AS PercentCurrent,
        CASE 
            WHEN BalTotal = 0 THEN 0 
            ELSE (Bal_31_60 / BalTotal) * 100 
        END AS Percent31to60,
        CASE 
            WHEN BalTotal = 0 THEN 0 
            ELSE (Bal_61_90 / BalTotal) * 100 
        END AS Percent61to90,
        CASE 
            WHEN BalTotal = 0 THEN 0 
            ELSE (BalOver90 / BalTotal) * 100 
        END AS PercentOver90
    FROM patient
) 