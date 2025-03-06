-- TransactionCounts: Counts payment transactions by type (regular vs unearned)
-- Provides transaction count metrics for patients within the date range
-- Dependencies: None
-- Date filter: Uses @start_date and @end_date parameters to filter transactions

TransactionCounts AS (
    SELECT
        PatNum,
        COUNT(*) AS total_transaction_count,
        SUM(CASE WHEN UnearnedType = 0 THEN 1 ELSE 0 END) AS regular_transaction_count,
        SUM(CASE WHEN UnearnedType != 0 THEN 1 ELSE 0 END) AS unearned_transaction_count
    FROM paysplit
    WHERE DatePay BETWEEN @start_date AND @end_date
    GROUP BY PatNum
) 