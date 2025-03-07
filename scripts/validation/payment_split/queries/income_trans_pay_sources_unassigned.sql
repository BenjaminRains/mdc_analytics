/* QUERY_NAME: income_trans_pay_sources_unassigned.sql
 * 
 * PURPOSE:
 * Analyzes the payment types (cash, credit card, etc.) that are most commonly
 * associated with unassigned provider transactions. This helps identify if
 * specific payment processing workflows are contributing to the issue.
 *
 * PARAMETERS:
 * - Date range: uses @start_date and @end_date variables
 * - Dependent CTEs: None
 * 
 * INTERPRETATION:
 * - Payment types with high occurrence rates may indicate workflow issues
 * - Can be used to target specific payment processing training
 */
SELECT
    pay.PayType,
    COALESCE(def.ItemName, CONCAT('Type ', pay.PayType)) AS pay_type_name,
    COUNT(*) AS transaction_count,
    SUM(ps.SplitAmt) AS total_amount
FROM paysplit ps
INNER JOIN payment pay ON ps.PayNum = pay.PayNum
LEFT JOIN definition def ON pay.PayType = def.DefNum
WHERE ps.ProvNum = 0
AND ps.DatePay BETWEEN @start_date AND @end_date
GROUP BY pay.PayType, def.ItemName
ORDER BY COUNT(*) DESC;