-- Analyze suspicious split patterns using SuspiciousSplitAnalysis CTE
-- Date filter: Uses @start_date to @end_date
SELECT 
    PayDate,
    ClaimNum,
    ProcNum,
    COUNT(PaySplitNum) as split_count,
    COUNT(DISTINCT PayNum) as payment_count,
    MIN(min_split_amt) as min_split,
    MAX(max_split_amt) as max_split,
    split_pattern
FROM SuspiciousSplitAnalysis
GROUP BY PayDate, ClaimNum, ProcNum, split_pattern
HAVING COUNT(PaySplitNum) > 1000  -- Alert threshold
ORDER BY split_count DESC;