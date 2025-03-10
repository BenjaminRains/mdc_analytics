{% include "payment_daily_details.sql" %}
-- Daily payment statistics - aggregates payment activity into daily summary metrics for trend analysis
DailyStats AS (
    SELECT 
        DATE(pdd.PayDate) as payment_date,
        COUNT(DISTINCT pdd.PayNum) as payment_count,
        COUNT(pdd.SplitNum) as split_count,
        COUNT(DISTINCT pdd.ClaimNum) as claim_count,
        COUNT(DISTINCT pdd.ProcNum) as procedure_count,
        SUM(pdd.PayAmt) as total_payment_amount,
        SUM(pdd.SplitAmt) as total_split_amount,
        ABS(SUM(pdd.PayAmt) - SUM(pdd.SplitAmt)) as payment_split_difference,
        COUNT(DISTINCT CASE WHEN pdd.PayType = 0 THEN pdd.PayNum END) as transfer_count,
        COUNT(DISTINCT CASE WHEN pdd.PayType IN (417, 574, 634) THEN pdd.PayNum END) as insurance_count
    FROM PaymentDailyDetails pdd
    GROUP BY DATE(pdd.PayDate)
) 