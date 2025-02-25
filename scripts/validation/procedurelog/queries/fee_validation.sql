-- Fee Validation Query
-- Analyzes procedure fees across different ranges and categories

WITH
FeeRanges AS (
    SELECT
        pl.ProcNum,
        pl.ProcFee,
        pc.ProcCode,
        pl.ProcStatus,
        pl.CodeCategory,
        CASE
            WHEN pl.ProcFee = 0 THEN 'Zero Fee'
            WHEN pl.ProcFee < 100 THEN 'Under $100'
            WHEN pl.ProcFee < 250 THEN '$100-$249'
            WHEN pl.ProcFee < 500 THEN '$250-$499'
            WHEN pl.ProcFee < 1000 THEN '$500-$999'
            WHEN pl.ProcFee < 2000 THEN '$1000-$1999'
            ELSE '$2000+'
        END AS fee_range
    FROM BaseProcedures pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
)

SELECT
    fee_range,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    MIN(ProcFee) AS min_fee,
    MAX(ProcFee) AS max_fee,
    ROUND(AVG(ProcFee), 2) AS avg_fee,
    COUNT(DISTINCT ProcCode) AS unique_codes,
    SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_count,
    SUM(CASE WHEN ProcStatus = 1 THEN 1 ELSE 0 END) AS planned_count,
    SUM(CASE WHEN CodeCategory = 'Excluded' THEN 1 ELSE 0 END) AS excluded_count,
    ROUND(100.0 * SUM(CASE WHEN CodeCategory = 'Excluded' THEN 1 ELSE 0 END) / COUNT(*), 2) AS excluded_pct
FROM FeeRanges
GROUP BY fee_range
ORDER BY 
    CASE fee_range
        WHEN 'Zero Fee' THEN 1
        WHEN 'Under $100' THEN 2
        WHEN '$100-$249' THEN 3
        WHEN '$250-$499' THEN 4
        WHEN '$500-$999' THEN 5
        WHEN '$1000-$1999' THEN 6
        WHEN '$2000+' THEN 7
    END;
