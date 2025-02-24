-- Join stages
-- tracks payment counts through join stages
-- identifies missing or duplicate payments
-- validates join integrity

SELECT 
    pbc.total_payments as base_count,
    COUNT(DISTINCT CASE WHEN pjd.join_status != 'No Splits' THEN pjd.PayNum END) as paysplit_count,
    COUNT(DISTINCT CASE WHEN pjd.join_status = 'Complete' THEN pjd.PayNum END) as claimproc_count,
    pbc.total_payments - COUNT(DISTINCT CASE WHEN pjd.join_status = 'Complete' THEN pjd.PayNum END) as missing_payments,
    -- Additional diagnostic information
    AVG(ps.split_count) as avg_splits_per_payment,
    COUNT(DISTINCT CASE WHEN ps.split_difference > 0.01 THEN ps.PayNum END) as mismatch_count
FROM PaymentBaseCounts pbc
CROSS JOIN PaymentJoinDiagnostics pjd
LEFT JOIN PaymentSummary ps ON pjd.PayNum = ps.PayNum
GROUP BY pbc.total_payments;
