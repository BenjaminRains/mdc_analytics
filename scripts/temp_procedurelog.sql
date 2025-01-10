-- Drop the existing temporary table if it exists
DROP TEMPORARY TABLE IF EXISTS temp_procedurelog;

-- Create a new temporary table with data from the procedurelog table
CREATE TEMPORARY TABLE temp_procedurelog AS
SELECT
    pl.ProcNum,
    pl.PatNum,
    pl.AptNum,
    pl.OldCode,
    pl.ProcDate,
    pl.ProcFee,
    pl.Surf,
    pl.ToothNum,
    pl.ToothRange,
    pl.Priority,
    pl.ProcStatus, -- (1= , 2=complete, 3= , 4= , 5= , 6= )
    pl.ProvNum,
    pl.CodeNum
FROM 
    procedurelog pl
WHERE 
    pl.ProcDate >= '2021-01-01'; -- within the past 4 years

-- Verify the contents of the temporary table
SELECT * FROM temp_procedurelog;

