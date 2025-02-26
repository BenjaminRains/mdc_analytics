-- FEE RANGES
-- Categorizes procedures by fee amounts for analysis
-- Used for financial segmentation and pricing tier analysis
-- dependent CTEs: BaseProcedures
FeeRanges AS (
    SELECT
        ProcNum,
        ProcCode,
        ProcStatus,
        ProcFee,
        CASE
            WHEN ProcFee = 0 THEN 'Zero Fee'
            WHEN ProcFee < 100 THEN 'Under $100'
            WHEN ProcFee >= 100 AND ProcFee < 250 THEN '$100-$249'
            WHEN ProcFee >= 250 AND ProcFee < 500 THEN '$250-$499'
            WHEN ProcFee >= 500 AND ProcFee < 1000 THEN '$500-$999'
            WHEN ProcFee >= 1000 AND ProcFee < 2500 THEN '$1000-$2499'
            WHEN ProcFee >= 2500 THEN '$2500+'
        END AS fee_range
    FROM BaseProcedures
)