-- Bundled Procedures Query
-- Analyzes procedures that are commonly performed together (bundled)

WITH 
-- Get all procedure pairs within the same day for the same patient
ProcedurePairs AS (
    SELECT 
        p1.PatNum,
        p1.ProcDate,
        p1.ProcNum AS proc1_num,
        p2.ProcNum AS proc2_num,
        p1.CodeNum AS code1_num,
        p2.CodeNum AS code2_num,
        pc1.ProcCode AS proc1_code,
        pc2.ProcCode AS proc2_code,
        pc1.Descript AS proc1_desc,
        pc2.Descript AS proc2_desc,
        p1.ProcFee AS proc1_fee,
        p2.ProcFee AS proc2_fee,
        p1.ProcStatus AS proc1_status,
        p2.ProcStatus AS proc2_status
    FROM BaseProcedures p1
    JOIN BaseProcedures p2 ON 
        p1.PatNum = p2.PatNum AND 
        p1.ProcDate = p2.ProcDate AND
        p1.ProcNum < p2.ProcNum  -- Avoid duplicates
    JOIN procedurecode pc1 ON p1.CodeNum = pc1.CodeNum
    JOIN procedurecode pc2 ON p2.CodeNum = pc2.CodeNum
    WHERE 
        p1.CodeCategory = 'Standard' AND  -- Exclude special codes
        p2.CodeCategory = 'Standard' AND
        p1.ProcStatus = 2 AND  -- Only completed procedures
        p2.ProcStatus = 2
),

-- Count the most frequent pairs
CommonPairs AS (
    SELECT 
        proc1_code,
        proc2_code,
        proc1_desc,
        proc2_desc,
        COUNT(*) AS pair_count,
        SUM(proc1_fee + proc2_fee) AS total_pair_fee,
        ROUND(AVG(proc1_fee + proc2_fee), 2) AS avg_pair_fee
    FROM ProcedurePairs
    GROUP BY proc1_code, proc2_code, proc1_desc, proc2_desc
    HAVING COUNT(*) >= 5  -- Only pairs that occur at least 5 times
),

-- Identify patient visits with multiple procedures
VisitCounts AS (
    SELECT
        PatNum,
        ProcDate,
        COUNT(*) AS procedures_in_visit
    FROM BaseProcedures
    WHERE 
        ProcStatus = 2 AND  -- Completed procedures
        CodeCategory = 'Standard'  -- Standard codes
    GROUP BY PatNum, ProcDate
),

-- Calculate payment data for visits with multiple procedures
BundledPayments AS (
    SELECT
        v.PatNum,
        v.ProcDate,
        v.procedures_in_visit,
        COUNT(DISTINCT pl.ProcNum) AS procedure_count,
        SUM(pl.ProcFee) AS total_fee,
        SUM(pa.total_paid) AS total_paid,
        CASE WHEN SUM(pl.ProcFee) > 0 
            THEN SUM(pa.total_paid) / SUM(pl.ProcFee) 
            ELSE NULL 
        END AS payment_ratio,
        CASE 
            WHEN v.procedures_in_visit = 1 THEN 'Single Procedure'
            WHEN v.procedures_in_visit BETWEEN 2 AND 3 THEN '2-3 Procedures'
            WHEN v.procedures_in_visit BETWEEN 4 AND 5 THEN '4-5 Procedures'
            ELSE '6+ Procedures'
        END AS bundle_size
    FROM VisitCounts v
    JOIN BaseProcedures pl ON 
        v.PatNum = pl.PatNum AND 
        v.ProcDate = pl.ProcDate AND
        pl.ProcStatus = 2 AND
        pl.CodeCategory = 'Standard'
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    GROUP BY v.PatNum, v.ProcDate, v.procedures_in_visit, bundle_size
)

-- Output two result sets:
-- 1. Most common procedure pairs
SELECT 'Common Procedure Pairs' AS analysis_type, 
    proc1_code, 
    proc1_desc,
    proc2_code, 
    proc2_desc,
    pair_count,
    avg_pair_fee,
    total_pair_fee
FROM CommonPairs
ORDER BY pair_count DESC
LIMIT 100;

-- 2. Payment patterns by bundle size
SELECT 'Bundle Size Payment Analysis' AS analysis_type,
    bundle_size,
    COUNT(*) AS visit_count,
    SUM(procedure_count) AS total_procedures,
    ROUND(AVG(procedure_count), 2) AS avg_procedures_per_visit,
    ROUND(AVG(total_fee), 2) AS avg_visit_fee,
    SUM(total_fee) AS total_fees,
    SUM(total_paid) AS total_paid,
    ROUND(SUM(total_paid) / NULLIF(SUM(total_fee), 0) * 100, 2) AS payment_percentage,
    COUNT(CASE WHEN payment_ratio >= 0.95 THEN 1 END) AS fully_paid_visits,
    ROUND(COUNT(CASE WHEN payment_ratio >= 0.95 THEN 1 END) * 100.0 / COUNT(*), 2) AS fully_paid_pct
FROM BundledPayments
GROUP BY bundle_size
ORDER BY 
    CASE bundle_size
        WHEN 'Single Procedure' THEN 1
        WHEN '2-3 Procedures' THEN 2
        WHEN '4-5 Procedures' THEN 3
        WHEN '6+ Procedures' THEN 4
    END;
