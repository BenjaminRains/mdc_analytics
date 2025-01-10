-- Create a new temporary table with claim data from the past 4 years

-- Drop the temporary table if it already exists
DROP TEMPORARY TABLE IF EXISTS temp_claim;

CREATE TEMPORARY TABLE temp_claim AS
SELECT 
    c.ClaimNum,
    c.PatNum,
    c.DateService,
    c.DateSent,
    c.ClaimStatus,
    c.DateReceived,
    c.PlanNum,
    c.ProvTreat,
    c.ClaimFee,
    c.InsPayEst,
    c.InsPayAmt,
    c.DedApplied,
    c.ReasonUnderPaid,
    c.ClaimType,
    c.PatRelat,
    c.PlanNum2,
    c.InsSubNum,
    c.InsSubNum2,
    c.ClaimIdentifier
FROM 
    claim cl
WHERE 
    c.DateService >= DATE_SUB(CURDATE(), INTERVAL 4 YEAR);
