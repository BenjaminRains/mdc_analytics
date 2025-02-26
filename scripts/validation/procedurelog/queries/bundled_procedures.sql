-- Bundled Procedures Query
-- Analyzes procedures that are commonly performed together (bundled)
-- CTEs used: ExcludedCodes, BaseProcedures, PaymentActivity

WITH 
-- Import required CTEs from common_ctes.sql
ExcludedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
      '~GRP~', 'D9987', 'D9986', 'Watch', 'Ztoth', 'D0350',
      '00040', 'D2919', '00051',
      'D9992', 'D9995', 'D9996',
      'D0190', 'D0171', 'D0140', 'D9430', 'D0120'
    )
),

BaseProcedures AS (
    SELECT 
        pl.ProcNum,
        pl.PatNum,
        pl.ProvNum,
        pl.ProcDate,
        pl.ProcStatus,
        pl.ProcFee,
        pl.CodeNum,
        pl.AptNum,
        pl.DateComplete,
        pc.ProcCode,
        pc.Descript,
        CASE WHEN ec.CodeNum IS NOT NULL THEN 'Excluded' ELSE 'Standard' END AS CodeCategory
    FROM procedurelog pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    LEFT JOIN ExcludedCodes ec ON pl.CodeNum = ec.CodeNum
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
),

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

PaymentActivity AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(SUM(cp.InsPayAmt), 0) AS insurance_paid,
        COALESCE(SUM(ps.SplitAmt), 0) AS direct_paid,
        COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) AS total_paid,
        CASE 
            WHEN pl.ProcFee > 0 THEN 
                (COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0)) / pl.ProcFee 
            ELSE NULL 
        END AS payment_ratio
    FROM BaseProcedures pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    GROUP BY pl.ProcNum, pl.ProcFee
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
),

PaymentAnalysis AS (
    SELECT 
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
)

-- Combine the two result sets into one output using UNION ALL
SELECT 
    1 as sort_order,
    'Common Procedure Pairs' AS analysis_type,
    proc1_code,
    proc1_desc,
    proc2_code,
    proc2_desc,
    pair_count,
    avg_pair_fee,
    total_pair_fee,
    NULL AS bundle_size,
    NULL AS visit_count,
    NULL AS total_procedures,
    NULL AS avg_procedures_per_visit,
    NULL AS avg_visit_fee,
    NULL AS total_fees,
    NULL AS total_paid,
    NULL AS payment_percentage,
    NULL AS fully_paid_visits,
    NULL AS fully_paid_pct
FROM CommonPairs

UNION ALL

SELECT 
    2 as sort_order,
    'Bundle Size Payment Analysis' AS analysis_type,
    NULL AS proc1_code,
    NULL AS proc1_desc,
    NULL AS proc2_code,
    NULL AS proc2_desc,
    NULL AS pair_count,
    NULL AS avg_pair_fee,
    NULL AS total_pair_fee,
    bundle_size,
    visit_count,
    total_procedures,
    avg_procedures_per_visit,
    avg_visit_fee,
    total_fees,
    total_paid,
    payment_percentage,
    fully_paid_visits,
    fully_paid_pct
FROM PaymentAnalysis
ORDER BY 
    sort_order,
    CASE 
        WHEN sort_order = 1 THEN pair_count
        WHEN sort_order = 2 THEN
            CASE bundle_size
                WHEN 'Single Procedure' THEN 1
                WHEN '2-3 Procedures' THEN 2
                WHEN '4-5 Procedures' THEN 3
                WHEN '6+ Procedures' THEN 4
            END
    END DESC;
