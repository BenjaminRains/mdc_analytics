-- ClaimMetrics: Analyze claim relationships for payment split analysis.
-- depends on: none
-- Date filter: Uses @start_date to @end_date

ClaimMetrics AS (
    SELECT 
        ps.PayNum,
        COUNT(DISTINCT cp.ClaimProcNum) as claimproc_count,
        GROUP_CONCAT(DISTINCT cp.ClaimNum) as claim_nums,
        COUNT(DISTINCT CASE WHEN cp.ClaimNum IN (2536, 2542, 6519) THEN cp.ClaimNum END) as common_claim_count,
        COUNT(DISTINCT cp.ClaimNum) as total_claim_count
    FROM paysplit ps
    JOIN payment p ON ps.PayNum = p.PayNum
    JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
        AND cp.Status IN (1, 4, 5)
        AND cp.InsPayAmt > 0
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY ps.PayNum
)