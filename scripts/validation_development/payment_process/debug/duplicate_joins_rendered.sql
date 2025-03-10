

WITH

PaymentLevelMetrics AS (
    SELECT 
        p.PayNum,
        p.PayAmt,
        p.PayDate,
        p.PayType,
        p.PayNote,
        COUNT(ps.SplitNum) AS split_count,
        SUM(ps.SplitAmt) AS total_split_amount,
        ABS(p.PayAmt - COALESCE(SUM(ps.SplitAmt), 0)) AS split_difference,
        CASE WHEN p.PayAmt < 0 THEN 1 ELSE 0 END AS is_reversal,
        CASE WHEN COUNT(ps.SplitNum) > 15 THEN 1 ELSE 0 END AS is_high_split,
        CASE WHEN p.PayAmt = 0 THEN 1 ELSE 0 END AS is_zero_amount,
        CASE WHEN p.PayAmt > 5000 THEN 1 ELSE 0 END AS is_large_payment,
        CASE WHEN COUNT(ps.SplitNum) = 1 THEN 1 ELSE 0 END AS is_single_split,
        CASE 
            WHEN p.PayType IN (417, 574, 634) THEN 'Insurance'
            WHEN p.PayType IN (69, 70, 71) THEN 'Check/Cash'
            WHEN p.PayType IN (391, 412) THEN 'Card/Online'
            WHEN p.PayType = 72 THEN 'Refund'
            WHEN p.PayType = 0 THEN 'Transfer'
            ELSE 'Other'
        END AS payment_category
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= @start_date
      AND p.PayDate < @end_date
    GROUP BY p.PayNum, p.PayAmt, p.PayDate, p.PayType, p.PayNote
)
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
PaymentSplitAnalysis AS (
    -- Base payment split analysis
    SELECT 
        ps.PayNum,
        ps.PayAmt,
        ps.PayDate,
        ps.split_count,
        cm.claimproc_count,
        cm.claim_nums,
        CASE WHEN cm.common_claim_count > 0 THEN 1 ELSE 0 END as has_known_oversplit_claims,
        ps.payment_category,
        ps.total_split_amount,
        ps.split_difference,
        ROUND(ps.split_count / NULLIF(cm.claimproc_count, 0), 1) as splits_per_proc,
        CASE WHEN (
            cm.common_claim_count = cm.total_claim_count 
            AND cm.common_claim_count = 3 
            AND ps.split_count / cm.total_claim_count > 20
        ) OR (
            ps.split_count > 100 
            AND cm.total_claim_count < 5
        ) THEN 1 ELSE 0 END as is_suspicious,
        'Payment' as record_type,
        NULL as ClaimNum,
        NULL as ClaimProcNum,
        NULL as min_split_amt,
        NULL as max_split_amt,
        NULL as active_days
    FROM PaymentLevelMetrics ps
    JOIN ClaimMetrics cm ON ps.PayNum = cm.PayNum
    WHERE ps.split_count > 10
) 
,

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
        AND p.PayDate BETWEEN @start_date AND @end_date
    GROUP BY cp.ClaimNum, cp.ClaimProcNum
)
ProblemClaimAnalysis AS (
    SELECT 
        NULL as PayNum,
        NULL as PayAmt,
        NULL as PayDate,
        pcd.split_count,
        NULL as claimproc_count,
        CAST(pcd.ClaimNum AS CHAR) as claim_nums,
        1 as has_known_oversplit_claims,
        'Problem Claim' as payment_category,
        NULL as total_split_amount,
        NULL as split_difference,
        NULL as splits_per_proc,
        1 as is_suspicious,
        'Claim' as record_type,
        pcd.ClaimNum,
        pcd.ClaimProcNum,
        pcd.min_split_amt,
        pcd.max_split_amt,
        pcd.active_days
    FROM ProblemClaimDetails pcd
) 

SELECT * FROM (
    SELECT * FROM PaymentSplitAnalysis
    UNION ALL
    SELECT * FROM ProblemClaimAnalysis
) combined_results
ORDER BY 
    record_type,
    has_known_oversplit_claims DESC,
    is_suspicious DESC,
    split_count DESC;
