-- Duplicate joins
-- Identifies payments with excessive splits or claim linkages
-- Helps detect data quality issues and oversplit claims

-- 1. Initial payment analysis with categorization
WITH PaymentSummary AS (
    SELECT 
        p.PayNum,
        p.PayAmt,
        p.PayDate,
        p.PayType,
        COUNT(ps.SplitNum) AS split_count,
        SUM(ps.SplitAmt) AS total_split_amount,
        ABS(p.PayAmt - COALESCE(SUM(ps.SplitAmt), 0)) AS split_difference,
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
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY p.PayNum, p.PayAmt, p.PayDate, p.PayType
),

-- 2. Analyze claim relationships
ClaimMetrics AS (
    SELECT 
        ps.PayNum,
        COUNT(DISTINCT cp.ClaimProcNum) as claimproc_count,
        GROUP_CONCAT(DISTINCT cp.ClaimNum) as claim_nums,
        COUNT(DISTINCT CASE WHEN cp.ClaimNum IN (2536, 2542, 6519) THEN cp.ClaimNum END) as common_claim_count,
        COUNT(DISTINCT cp.ClaimNum) as total_claim_count
    FROM paysplit ps
    JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
        AND cp.Status IN (1, 4, 5)
        AND cp.InsPayAmt > 0
    GROUP BY ps.PayNum
),

-- 3. Detailed analysis of problem claims
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

-- Main analysis query
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
    ) THEN 1 ELSE 0 END as is_suspicious
FROM PaymentSummary ps
JOIN ClaimMetrics cm ON ps.PayNum = cm.PayNum
WHERE ps.split_count > 10
ORDER BY 
    has_known_oversplit_claims DESC,
    is_suspicious DESC,
    split_count DESC;

-- Problem claim details
SELECT * FROM ProblemClaimDetails
ORDER BY split_count DESC;
