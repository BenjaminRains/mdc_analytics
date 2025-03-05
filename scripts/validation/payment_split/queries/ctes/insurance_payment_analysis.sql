-- InsurancePaymentAnalysis: Compute metrics specific to insurance payments.
-- depends on: PaymentSourceCategories, PaymentSourceSummary
-- Date filter: Uses @start_date to @end_date
InsurancePaymentAnalysis AS (
    SELECT 
        pss.payment_source,
        pss.payment_count,
        pss.total_paid,
        pss.avg_payment,
        COUNT(DISTINCT cp.PlanNum) AS plan_count,
        COUNT(DISTINCT cp.ClaimNum) AS claim_count,
        COUNT(DISTINCT CASE WHEN p.PayType IN (417, 574, 634) THEN p.PayNum END) AS direct_ins_count,
        COUNT(DISTINCT CASE WHEN p.PayType IN (69, 70, 71) THEN p.PayNum END) AS check_cash_count,
        COUNT(DISTINCT CASE WHEN p.PayType IN (391, 412) THEN p.PayNum END) AS card_count,
        AVG(CASE 
            WHEN pl.ProcDate IS NOT NULL THEN DATEDIFF(p.PayDate, pl.ProcDate)
            ELSE NULL 
        END) AS avg_days_to_payment
    FROM PaymentSourceCategories psc
    JOIN payment p ON psc.PayNum = p.PayNum
    JOIN PaymentSourceSummary pss ON psc.payment_source = pss.payment_source
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    LEFT JOIN procedurelog pl ON ps.ProcNum = pl.ProcNum
    LEFT JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
         AND cp.Status IN (1, 2, 4, 6)
    GROUP BY 
        pss.payment_source,
        pss.payment_count,
        pss.total_paid,
        pss.avg_payment
)