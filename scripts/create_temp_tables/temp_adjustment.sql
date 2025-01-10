-- Create a temporary table with 2 years of data from the adjustment table

-- Drop the existing temporary table if it exists
DROP TEMPORARY TABLE IF EXISTS temp_adjustment;

CREATE TEMPORARY TABLE temp_adjustment AS
SELECT 
    a.AdjNum,
    a.PatNum,
    a.AdjDate,
    a.AdjAmt,
    a.AdjNote,
    a.AdjType,
    a.ClinicNum,
    a.ProcNum,
    a.StatementNum,
    a.ProvNum
FROM 
    adjustment a
WHERE 
    a.AdjDate >= DATE_SUB(CURDATE(), INTERVAL 4 YEAR);



