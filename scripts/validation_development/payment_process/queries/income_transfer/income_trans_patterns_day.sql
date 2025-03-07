/* QUERY_NAME: income_trans_patterns_day.sql
 * ===============================================================================
 * 
 * PURPOSE:
 * Analyzes when unassigned provider transactions are occurring by day of week
 * to identify staffing or workflow issues on specific days.
 *
 * PARAMETERS:
 * - Date range: uses @start_date and @end_date variables
 * - Dependent CTEs: None
 * 
 * INTERPRETATION:
 * - Patterns by weekday may indicate staffing gaps or training issues on specific days
 */
SELECT
    DAYNAME(DatePay) AS day_of_week,
    COUNT(*) AS transaction_count,
    FORMAT(AVG(SplitAmt), 2) AS average_amount
FROM paysplit
WHERE ProvNum = 0
AND DatePay BETWEEN @start_date AND @end_date
GROUP BY DAYNAME(DatePay)
ORDER BY FIELD(DAYNAME(DatePay), 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');