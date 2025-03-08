/* QUERY_NAME: income_trans_detailed_payment_info.sql===
 * 
 * PURPOSE:
 * Provides detailed information about unassigned provider transactions for
 * specific patients. This is useful for in-depth investigation of individual
 * accounts and problem solving.
 *
 * PARAMETERS:
 * - PatNum list: Update with the patient IDs you want to analyze
 * - Date range: uses @start_date and @end_date variables
 * - Dependent CTEs: None
 * 
 * INTERPRETATION:
 * - Helps identify patterns specific to individual patients
 * - Can be used to trace specific transactions back to their source
 * - Useful for detailed reconciliation of accounts
 */
SELECT
    ps.SplitNum,
    ps.PatNum,
    CONCAT(pat.LName, ', ', pat.FName) AS patient_name,
    ps.DatePay,
    ps.DatePay AS transaction_date,
    ps.SplitAmt,
    ps.PayNum,
    pay.PayType,
    COALESCE(def.ItemName, CONCAT('Type ', pay.PayType)) AS pay_type_name, -- using COALESCE to avoid null values in pay_type_name
    pay.PayNote,
    ps.ProcNum,
    u.UserName AS entered_by,
    pg.Description AS user_group
FROM paysplit ps
INNER JOIN patient pat ON ps.PatNum = pat.PatNum
INNER JOIN payment pay ON ps.PayNum = pay.PayNum
LEFT JOIN userod u ON ps.SecUserNumEntry = u.UserNum
LEFT JOIN usergroupattach uga ON u.UserNum = uga.UserNum
LEFT JOIN usergroup pg ON uga.UserGroupNum = pg.UserGroupNum
LEFT JOIN definition def ON pay.PayType = def.DefNum -- modified join to use a simpler condition
WHERE ps.ProvNum = 0
AND ps.PatNum IN (
    -- List of PatNums to analyze
    -- UPDATE THIS LIST as needed for your specific analysis
    28775, 32743, 30358
)
AND ps.DatePay BETWEEN @start_date AND @end_date
ORDER BY ps.PatNum, ps.DatePay DESC;