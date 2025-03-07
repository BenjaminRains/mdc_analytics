/* QUERY_NAME: income_trans_users_unassigned_pay.sql
 * 
 * PURPOSE:
 * Identifies which users and user groups are creating unassigned provider 
 * transactions. This helps target training efforts and process improvements
 * to the most relevant staff members and departments.
 *
 * PARAMETERS:
 * - Date range: Uses date parameters from command line ('2025-01-01' to '2025-02-28')
 * 
 * INTERPRETATION:
 * - Users with high transaction counts need targeted training
 * - User groups with systematic issues may need process redesign
 * - First/last transaction dates help identify when issues began
 */
SELECT
    u.UserName,
    ug.Description AS user_group_name,
    COUNT(*) AS transaction_count,
    SUM(ps.SplitAmt) AS total_amount,
    MIN(ps.DatePay) AS first_transaction,
    MAX(ps.DatePay) AS last_transaction
FROM paysplit ps
LEFT JOIN userod u ON ps.SecUserNumEntry = u.UserNum
LEFT JOIN usergroupattach uga ON u.UserNum = uga.UserNum
LEFT JOIN usergroup ug ON uga.UserGroupNum = ug.UserGroupNum
WHERE ps.ProvNum = 0
AND ps.DatePay BETWEEN @start_date AND @end_date
GROUP BY u.UserName, ug.Description
ORDER BY COUNT(*) DESC;