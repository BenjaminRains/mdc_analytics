-- Indexes to optimize query performance
CREATE INDEX IF NOT EXISTS idx_ml_proc_status_date_code ON procedurelog (ProcStatus, ProcDate, CodeNum);
CREATE INDEX IF NOT EXISTS idx_ml_fee_code ON fee (CodeNum);
CREATE INDEX IF NOT EXISTS idx_ml_proccode_code ON procedurecode (CodeNum);

-- Query 1: Verify fee population logic in procedurelog and its relationship with fee, procedurecode, and definition
-- business logic: this is the clinic fee before insurance, adjustments, discounts, write-offs.
-- this query is only looking at completed procedures. (treatment acceptance) 
-- NOTE: pl.ProcFee is sometimes 0 and f.Amount is >0. Investigate.
SELECT 
    pl.ProcNum,
    pl.CodeNum,
    pl.ProcFee,
    pl.PatNum,
    pl.ProcDate,
    f.Amount AS clinic_fee,
    f.OldCode AS fee_old_code,
    f.FeeNum AS fee_number,
    pc.Descript AS procedure_description,
    pc.CodeNum AS procedure_code_number
FROM 
    procedurelog pl
LEFT JOIN 
    fee f ON pl.CodeNum = f.CodeNum
LEFT JOIN 
    procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE 
    pl.ProcStatus = 2
    AND CAST(pl.ProcDate AS DATE) >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
LIMIT 1000000; 

-- Query 2: Find when pl.ProcFee and f.Amount differ and list the relevant CodeNum and OldCode
SELECT 
    pl.CodeNum,
    f.OldCode AS fee_old_code,
    pl.ProcFee,
    f.Amount AS clinic_fee
FROM 
    procedurelog pl
LEFT JOIN 
    fee f ON pl.CodeNum = f.CodeNum
WHERE 
    pl.ProcFee != f.Amount
    AND pl.ProcStatus = 2
    AND CAST(pl.ProcDate AS DATE) >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR);

-- Query 3: Calculate the average pl.ProcFee per pl.CodeNum
SELECT 
    pl.CodeNum,
    AVG(pl.ProcFee) AS average_proc_fee
FROM 
    procedurelog pl
WHERE 
    pl.ProcStatus = 2
    AND CAST(pl.ProcDate AS DATE) >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
GROUP BY 
    pl.CodeNum;

-- Query 4: Calculate the average f.Amount per pc.CodeNum
SELECT 
    pc.CodeNum AS procedure_code_number,
    AVG(f.Amount) AS average_clinic_fee
FROM 
    procedurelog pl
LEFT JOIN 
    fee f ON pl.CodeNum = f.CodeNum
LEFT JOIN 
    procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE 
    pl.ProcStatus = 2
    AND CAST(pl.ProcDate AS DATE) >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
GROUP BY 
    pc.CodeNum;




-- Query 5: Calculate the average pl.ProcFee per pl.CodeNum
-- Step 1: Calculate the average pl.ProcFee per pl.CodeNum
CREATE TEMPORARY TABLE IF NOT EXISTS ProcFeeAvg AS
SELECT 
    pl.CodeNum,
    AVG(pl.ProcFee) AS average_proc_fee
FROM 
    procedurelog pl
WHERE 
    pl.ProcStatus = 2
    AND pl.ProcDate >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
GROUP BY 
    pl.CodeNum;

-- Step 2: Calculate the average f.Amount per pc.CodeNum
CREATE TEMPORARY TABLE IF NOT EXISTS ClinicFeeAvg AS
SELECT 
    pc.CodeNum,
    AVG(f.Amount) AS average_clinic_fee
FROM 
    procedurelog pl
INNER JOIN 
    fee f ON pl.CodeNum = f.CodeNum
INNER JOIN 
    procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE 
    pl.ProcStatus = 2
    AND pl.ProcDate >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
GROUP BY 
    pc.CodeNum;

-- Step 3: Combine the results
SELECT 
    CodeNum AS code_number,
    average_proc_fee AS average_fee,
    'ProcFee' AS fee_type
FROM 
    ProcFeeAvg

UNION ALL

SELECT 
    CodeNum AS code_number,
    average_clinic_fee AS average_fee,
    'ClinicFee' AS fee_type
FROM 
    ClinicFeeAvg;