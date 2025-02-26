-- ProblemClaimDetails: Detailed analysis of known problematic claims.
-- depends on: none
-- Date filter: 2024-10-30 to 2024-11-05
ProblemClaimDetails AS (
    SELECT 
        cp.ClaimNum,
        cp.ClaimProcNum,
        COUNT(DISTINCT p.PayNum) as payment_count,
        COUNT(ps.SplitNum) as split_count,
        MIN(ps.SplitAmt) as min_split_amt,
        MAX(ps.SplitAmt) as max_split_amt,
        COUNT(DISTINCT DATE(p.PayDate)) as active_days
    FROM claimproc cp
    JOIN paysplit ps ON cp.ProcNum = ps.ProcNum
    JOIN payment p ON ps.PayNum = p.PayNum
    WHERE cp.ClaimNum IN (2536, 2542, 6519)
        AND p.PayDate BETWEEN '2024-10-30' AND '2024-11-05'
    GROUP BY cp.ClaimNum, cp.ClaimProcNum
)