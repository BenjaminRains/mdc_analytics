/* QUERY_NAME: income_trans_patterns_by_month.sql
 * 
 * PURPOSE:
 * Analyzes when unassigned provider transactions are occurring by month
 * to identify seasonal trends or system update related issues.
 *
 * PARAMETERS:
 * - Date range: uses @start_date and @end_date variables
 * - Dependent CTEs: None
 * 
 * INTERPRETATION:
 * - Patterns by month may indicate seasonal trends or correlate with system updates
 */
SELECT
    MONTH(DatePay) AS month_number,
    MONTHNAME(DatePay) AS month_name,
    COUNT(*) AS transaction_count,
    FORMAT(AVG(SplitAmt), 2) AS average_amount
FROM paysplit
WHERE ProvNum = 0
AND DatePay BETWEEN @start_date AND @end_date
GROUP BY MONTH(DatePay), MONTHNAME(DatePay)
ORDER BY MONTH(DatePay);