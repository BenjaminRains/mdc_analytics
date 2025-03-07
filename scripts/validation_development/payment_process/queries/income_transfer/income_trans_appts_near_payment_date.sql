/* QUERY_NAME: income_trans_appts_near_payment_date.sql
 * ===============================================================================
 * 
 * PURPOSE:
 * Identifies appointments that occurred near the payment date for patients
 * with unassigned provider transactions. This helps determine the most likely
 * provider to assign to these transactions.
 *
 * PARAMETERS:
 * - PatNum list: Update with the patient IDs you want to analyze
 * - Date range: Uses date parameters from command line ('2025-01-01' to '2025-03-15')
 * - Dependent CTEs: None
 * 
 * INTERPRETATION:
 * The provider who saw the patient closest to the payment date is often
 * the correct provider to assign to the unassigned transaction.
 */
SELECT
    pat.PatNum,
    CONCAT(pat.LName, ', ', pat.FName) AS patient_name,
    apt.AptDateTime,
    apt.ProvNum,
    CONCAT(prov.LName, ', ', prov.FName) AS provider_name,
    -- Find the most recent payment date for this patient
    (SELECT MAX(ps.DatePay) 
     FROM paysplit ps 
     WHERE ps.PatNum = pat.PatNum 
     AND ps.ProvNum = 0
     AND ps.DatePay BETWEEN @start_date AND @end_date) AS last_unassigned_payment,
    -- Calculate days between appointment and payment
    ABS(DATEDIFF(
        apt.AptDateTime, 
        (SELECT MAX(ps.DatePay) 
         FROM paysplit ps 
         WHERE ps.PatNum = pat.PatNum 
         AND ps.ProvNum = 0
         AND ps.DatePay BETWEEN @start_date AND @end_date)
    )) AS days_between_apt_and_payment
FROM patient pat
INNER JOIN appointment apt ON pat.PatNum = apt.PatNum
LEFT JOIN provider prov ON apt.ProvNum = prov.ProvNum
WHERE pat.PatNum IN (
    -- List of PatNums with unassigned payments
    -- UPDATE THIS LIST as needed for your specific analysis
    28775, 32743, 30358, 31310, 237, 32908, 32984, 15143
)
AND apt.AptDateTime BETWEEN @start_date AND @end_date
AND apt.AptStatus = 2  -- Completed appointments only
ORDER BY pat.PatNum, days_between_apt_and_payment;