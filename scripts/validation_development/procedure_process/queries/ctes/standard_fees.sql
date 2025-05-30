-- STANDARD FEES
-- Compares procedure fees to standard fee schedules
-- Used for fee consistency analysis and pricing optimization
-- Dependent CTEs: base_procedures.sql
StandardFees AS (
    SELECT
        ProcCode,
        CodeNum,
        COUNT(*) AS procedure_count,
        MIN(ProcFee) AS min_fee,
        MAX(ProcFee) AS max_fee,
        AVG(ProcFee) AS avg_fee,
        STDDEV(ProcFee) AS fee_stddev,
        COUNT(DISTINCT ProcFee) AS unique_fee_count,
        CASE
            WHEN STDDEV(ProcFee) = 0 THEN 'Fixed Fee'
            WHEN STDDEV(ProcFee) / NULLIF(AVG(ProcFee), 0) <= 0.05 THEN 'Minimal Variation'
            WHEN STDDEV(ProcFee) / NULLIF(AVG(ProcFee), 0) <= 0.15 THEN 'Moderate Variation'
            ELSE 'High Variation'
        END AS fee_relationship
    FROM BaseProcedures
    WHERE ProcFee > 0
    GROUP BY ProcCode, CodeNum
    HAVING COUNT(*) > 5 -- Only include procedures with significant sample size
)