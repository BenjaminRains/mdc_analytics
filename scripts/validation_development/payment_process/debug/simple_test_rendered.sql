

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
,

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

SELECT p.PayNum, p.PayAmt, cm.claimproc_count
FROM PaymentLevelMetrics p
LEFT JOIN ClaimMetrics cm ON p.PayNum = cm.PayNum
LIMIT 100; 