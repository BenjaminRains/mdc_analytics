-- Investigate daily patterns of the payment process. 
-- Uses PaymentDailyDetails CTE

SELECT 
    PayDate,
    PayType,
    COUNT(DISTINCT PayNum) as num_payments,
    COUNT(DISTINCT ClaimNum) as num_claims,
    COUNT(SplitNum) as total_splits,
    SUM(PayAmt) as total_amount,
    AVG(PayAmt) as avg_payment_amount,
    MIN(SplitAmt) as min_split,
    MAX(SplitAmt) as max_split,
    COUNT(DISTINCT CASE WHEN ProcStatus IN (1, 2) THEN ClaimProcNum END) as active_procedures,
    COUNT(DISTINCT CASE WHEN ClaimStatus = 'C' THEN ClaimNum END) as completed_claims,
    AVG(DATEDIFF(PayDate, DateService)) as avg_days_from_service
FROM PaymentDailyDetails
GROUP BY 
    PayDate,
    PayType
ORDER BY PayDate DESC;
