-- Create a temporary table with 2 years of data from the adjustment table
CREATE TEMPORARY TABLE temp_adjustment AS
SELECT 
    AdjNum,
    PatNum,
    AdjDate,
    AdjAmt,
    AdjNote,
    AdjType,
    ClinicNum,
    ProcNum,
    StatementNum,
    ProvNum
FROM 
    adjustment
WHERE 
    AdjDate >= DATE_SUB(CURDATE(), INTERVAL 4 YEAR);

-- Verify the contents of the temporary table
SELECT * FROM temp_adjustment;

-- Drop the existing temporary table if it exists
-- DROP TEMPORARY TABLE IF EXISTS temp_adjustment;

