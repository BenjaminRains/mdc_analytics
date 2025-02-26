-- SuspiciousSplitAnalysis: Identify suspicious or abnormal split patterns.
-- depends on: none
-- Date filter: 2024-01-01 to 2025-01-01
SuspiciousSplitAnalysis AS (
    SELECT 
        ps.SplitNum as PaySplitNum,
        ps.PayNum,
        ps.ProcNum,
        cp.ClaimNum,
        ps.SplitAmt,
        p.PayDate,
        p.PayNote,
        COUNT(*) OVER (PARTITION BY cp.ClaimNum) as splits_per_claim,
        COUNT(*) OVER (PARTITION BY ps.PayNum) as splits_per_payment,
        MIN(ps.SplitAmt) OVER (PARTITION BY ps.PayNum) as min_split_amt,
        MAX(ps.SplitAmt) OVER (PARTITION BY ps.PayNum) as max_split_amt,
        CASE 
            WHEN COUNT(*) OVER (PARTITION BY cp.ClaimNum) > 1000 THEN 'High volume splits'
            WHEN ABS(MIN(ps.SplitAmt) OVER (PARTITION BY ps.PayNum)) = 
                 ABS(MAX(ps.SplitAmt) OVER (PARTITION BY ps.PayNum)) 
                THEN 'Symmetric splits'
            ELSE 'Normal pattern'
        END as split_pattern
    FROM paysplit ps
    JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
    JOIN payment p ON ps.PayNum = p.PayNum
    WHERE cp.ClaimNum IN (2536, 2542, 6519)
        AND p.PayDate BETWEEN '2024-10-30' AND '2024-11-05'
)