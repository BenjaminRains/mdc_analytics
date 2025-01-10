-- Claim data from the past 4 years

-- Drop the temporary table if it already exists
DROP TEMPORARY TABLE IF EXISTS temp_claim;

-- Create a new temporary table with claim data from the past 4 years
CREATE TEMPORARY TABLE temp_claim AS
SELECT 
    `ClaimNum`,
    `PatNum`,
    `DateService`,
    `DateSent`,
    `ClaimStatus`,
    `DateReceived`,
    `PlanNum`,
    `ProvTreat`,
    `ClaimFee`,
    `InsPayEst`,
    `InsPayAmt`,
    `DedApplied`,
    `ReasonUnderPaid`,
    `ClaimType`,
    `PatRelat`,
    `PlanNum2`,
    `InsSubNum`,
    `InsSubNum2`,
    `ClaimIdentifier`
FROM 
    `opendental_analytics`.`claim`
WHERE 
    `DateService` >= DATE_SUB(CURDATE(), INTERVAL 4 YEAR);
