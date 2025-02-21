/*
 * Fee Data Validation and Quality Analysis
 * 
 * Purpose:
 * - Validate fee data integrity and relationships
 * - Analyze fee discrepancies and patterns
 * - Monitor fee population logic
 * - Track historical fee trends
 * 
 * Time period: 2024 calendar year (with 4-year lookback)
 * Output file: /validation/data/fee_validation_2024.csv
 * 
 * Output Dataset Fields:
 * Base Validation:
 *    - ProcNum: Procedure identifier
 *    - CodeNum: Procedure code
 *    - ProcFee: Actual fee charged
 *    - PatNum: Patient identifier
 *    - ProcDate: Procedure date
 *    - clinic_fee: Standard fee from fee table
 *    - fee_old_code: Historical code reference
 *    - procedure_description: Description from procedurecode
 * 
 * Discrepancy Analysis:
 *    - fee_difference: ProcFee - clinic_fee
 *    - discrepancy_type: Over/Under/Match
 * 
 * Fee Statistics:
 *    - average_proc_fee: Average actual fee charged
 *    - average_clinic_fee: Average standard fee
 *    - fee_variance: Standard deviation of fees
 *    - usage_count: Number of times used
 */

-- Indexes to optimize query performance
CREATE INDEX IF NOT EXISTS idx_ml_proc_status_date_code ON procedurelog (ProcStatus, ProcDate, CodeNum);
CREATE INDEX IF NOT EXISTS idx_ml_fee_code ON fee (CodeNum);
CREATE INDEX IF NOT EXISTS idx_ml_proccode_code ON procedurecode (CodeNum);

WITH 
-- Base fee validation data
BaseData AS (
    SELECT 
        pl.ProcNum,
        pl.CodeNum,
        pl.ProcFee,
        pl.PatNum,
        pl.ProcDate,
        f.Amount AS clinic_fee,
        f.OldCode AS fee_old_code,
        pc.Descript AS procedure_description
    FROM procedurelog pl
    LEFT JOIN fee f ON pl.CodeNum = f.CodeNum
    LEFT JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    WHERE pl.ProcStatus = 2
      AND CAST(pl.ProcDate AS DATE) >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
),
-- Fee discrepancies where the actual fee and the standard fee differ
DiscrepancyData AS (
    SELECT 
        pl.ProcNum,
        (pl.ProcFee - f.Amount) AS fee_difference,
        CASE 
            WHEN pl.ProcFee > f.Amount THEN 'Over'
            WHEN pl.ProcFee < f.Amount THEN 'Under'
            ELSE 'Match'
        END AS discrepancy_type
    FROM procedurelog pl
    LEFT JOIN fee f ON pl.CodeNum = f.CodeNum
    WHERE pl.ProcStatus = 2
      AND CAST(pl.ProcDate AS DATE) >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
      AND pl.ProcFee != f.Amount
),
-- Aggregated fee averages and usage counts per procedure code
FeeAverages AS (
    SELECT 
        pl.CodeNum,
        AVG(pl.ProcFee) AS average_proc_fee,
        AVG(f.Amount) AS average_clinic_fee,
        STDDEV(pl.ProcFee) AS fee_variance,
        COUNT(*) AS usage_count
    FROM procedurelog pl
    LEFT JOIN fee f ON pl.CodeNum = f.CodeNum
    WHERE pl.ProcStatus = 2
      AND CAST(pl.ProcDate AS DATE) >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
    GROUP BY pl.CodeNum
)

-- Combine the data from the three CTEs into a single output
SELECT 
    b.ProcNum,
    b.CodeNum,
    b.ProcFee,
    b.PatNum,
    b.ProcDate,
    b.clinic_fee,
    b.fee_old_code,
    b.procedure_description,
    d.fee_difference,
    d.discrepancy_type,
    a.average_proc_fee,
    a.average_clinic_fee,
    a.fee_variance,
    a.usage_count
FROM BaseData b
LEFT JOIN DiscrepancyData d ON b.ProcNum = d.ProcNum
LEFT JOIN FeeAverages a ON b.CodeNum = a.CodeNum
ORDER BY 
    CASE 
        WHEN d.fee_difference IS NOT NULL THEN 1
        WHEN a.usage_count > 100 THEN 2
        ELSE 3
    END,
    ABS(COALESCE(d.fee_difference, 0)) DESC,
    a.usage_count DESC;