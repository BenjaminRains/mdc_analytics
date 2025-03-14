{% include "payment_system_summary.sql" %}
{% include "payment_level_metrics.sql" %}
{% include "payment_filter_diagnostics.sql" %}
SELECT * FROM (
    SELECT 
        'verification_counts' as report_type,
        'Total Base Payments' as metric,
        total_payments as payment_count,
        min_date,
        max_date
    FROM PaymentSystemSummary
    UNION ALL
    SELECT 
        'verification_counts' as report_type,
        CONCAT('Join Status: ', join_status) as metric,
        COUNT(*) as payment_count,
        MIN(PayDate) as min_date,
        MAX(PayDate) as max_date
    FROM PaymentJoinDiagnostics
    GROUP BY join_status
    UNION ALL
    SELECT
        'verification_counts' as report_type,
        CONCAT('Payment Type: ', CAST(PayType AS CHAR), ' (', 
               CASE 
                   WHEN PayType IN (417, 574, 634) THEN 'Insurance' 
                   WHEN PayType IN (69, 70, 71) THEN 'Check/Cash'
                   WHEN PayType IN (391, 412) THEN 'Card/Online'
                   WHEN PayType = 72 THEN 'Refund'
                   WHEN PayType = 0 THEN 'Transfer'
                   ELSE 'Other'
               END, ')') as metric,
        COUNT(*) as payment_count,
        MIN(PayDate) as min_date,
        MAX(PayDate) as max_date
    FROM PaymentLevelMetrics
    GROUP BY PayType
    UNION ALL
    SELECT
        'verification_counts' as report_type,
        CONCAT('Filter: ', filter_reason) as metric,
        COUNT(*) as payment_count,
        MIN(pd.PayDate) as min_date,
        MAX(pd.PayDate) as max_date
    FROM PaymentFilterDiagnostics pfd
    JOIN PaymentJoinDiagnostics pd ON pfd.PayNum = pd.PayNum
    GROUP BY filter_reason
    UNION ALL
    SELECT
        'verification_counts' as report_type,
        'Discrepancy: Join vs Filter Missing Procedures' as metric,
        (SELECT COUNT(*) FROM PaymentJoinDiagnostics WHERE join_status = 'No Procedures') -
        (SELECT COUNT(*) FROM PaymentFilterDiagnostics WHERE filter_reason = 'No Procedures') as payment_count,
        NULL as min_date,
        NULL as max_date
    UNION ALL
    SELECT
        'verification_counts' as report_type,
        'Payments with Split Mismatches' as metric,
        COUNT(*) as payment_count,
        MIN(PayDate) as min_date,
        MAX(PayDate) as max_date
    FROM PaymentLevelMetrics
    WHERE split_difference > 0.01
) verification_metrics
ORDER BY 
    report_type,
    CASE 
        WHEN metric = 'Total Base Payments' THEN 0
        WHEN metric LIKE 'Filter:%' THEN 1
        WHEN metric LIKE 'Payment Type:%' THEN 2
        WHEN metric LIKE 'Join Status:%' THEN 3
        WHEN metric LIKE 'Discrepancy:%' THEN 4
        ELSE 5
    END,
    payment_count DESC;