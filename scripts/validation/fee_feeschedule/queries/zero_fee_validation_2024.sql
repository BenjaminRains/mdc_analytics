/*
 * Zero Fee Procedure Analysis Query for 2024
 * 
 * Purpose: Analyzes procedures with zero fees to validate payment patterns
 * Output: Writes to /validation/data/zero_fee_proc_analysis_2024.csv
 * 
 * Key metrics:
 * - Payment patterns on zero-fee procedures
 * - Insurance and direct payment tracking
 * - Adjustment analysis
 * - Success criteria validation
 */

-- First, let's add a summary section
WITH ProcedureSummary AS (
    SELECT 
        pc.ProcCode,
        pc.Descript as procedure_description,
        COUNT(*) as procedure_count,
        COUNT(DISTINCT pl.PatNum) as unique_patients,
        SUM(CASE WHEN pl.ProcStatus = 2 THEN 1 ELSE 0 END) as completed_count
    FROM procedurelog pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    WHERE pl.ProcDate >= '2024-01-01'
        AND pl.ProcDate < '2025-01-01'
        AND pl.ProcFee = 0
    GROUP BY pc.ProcCode, pc.Descript
    HAVING COUNT(*) > 5
    ORDER BY COUNT(*) DESC
)

-- Then the detailed records
SELECT 
    pl.ProcNum,
    pl.ProcStatus,
    pl.CodeNum,
    pl.ProcFee,
    COALESCE(cp.InsPayAmt, 0) as insurance_paid,
    COALESCE(psm.total_paid, 0) as direct_paid,
    COALESCE(adj.total_adjustments, 0) as adjustments,
    pc.ProcCode,
    pc.Descript as procedure_description,
    pl.PatNum,  -- Added to track unique patients
    pl.ProvNum, -- Added to track providers
    pl.ProcDate, -- Added to track temporal patterns
    CASE 
        WHEN pl.ProcStatus = 2 
            AND pl.CodeNum NOT IN (626, 627)  
            AND (
                pl.ProcFee = 0  
                OR (
                    (COALESCE(cp.InsPayAmt, 0) > 0 OR COALESCE(psm.total_paid, 0) > 0)
                    AND COALESCE(adj.total_adjustments, 0) > -pl.ProcFee
                )
            ) THEN 1
        ELSE 0
    END as target_success
FROM procedurelog pl
LEFT JOIN (
    SELECT ProcNum, MAX(InsPayAmt) as InsPayAmt
    FROM claimproc 
    GROUP BY ProcNum
) cp ON pl.ProcNum = cp.ProcNum
LEFT JOIN (
    SELECT 
        ps.ProcNum,
        SUM(ps.SplitAmt) as total_paid
    FROM paysplit ps
    GROUP BY ps.ProcNum
) psm ON pl.ProcNum = psm.ProcNum
LEFT JOIN (
    SELECT 
        ProcNum,
        SUM(AdjAmt) as total_adjustments
    FROM adjustment
    WHERE AdjAmt != 0
    GROUP BY ProcNum
) adj ON pl.ProcNum = adj.ProcNum
LEFT JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE pl.ProcDate >= '2024-01-01'
    AND pl.ProcDate < '2025-01-01'
    AND pl.ProcFee = 0
ORDER BY pl.ProcStatus, target_success DESC;