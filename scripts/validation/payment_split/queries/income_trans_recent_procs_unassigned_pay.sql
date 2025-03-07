/* QUERY NAME: income_trans_recent_procs_unassigned_pay.sql
 * ===============================================================================
 * 
 * PURPOSE:
 * Identifies recent procedures for patients who have unassigned payments. This helps
 * determine the appropriate provider to assign to unassigned transactions by showing
 * which providers have actually performed work for these patients.
 *
 * PARAMETERS:
 * - PatNum list: Update with the patient IDs you want to analyze
 * - ProcStatus = 2: Shows only completed procedures (adjust if needed)
 * 
 * INTERPRETATION:
 * The provider listed for completed procedures is often the correct provider
 * for unassigned payment transactions from the same patient.
 *
 * - Dependent CTEs: None
 * - Date filter: Use @start_date to @end_date variables
 */
SELECT
    proc.ProcNum,
    proc.ProcDate,
    proc.ProvNum,
    CONCAT(prov.FName, ' ', prov.LName) AS provider_name,
    proc.PatNum,
    CONCAT(pat.LName, ', ', pat.FName) AS patient_name,
    proc.ProcStatus,
    proc.ProcFee
FROM procedurelog proc
INNER JOIN patient pat ON proc.PatNum = pat.PatNum
LEFT JOIN provider prov ON proc.ProvNum = prov.ProvNum
WHERE proc.PatNum IN (
    -- List of PatNums from your results
    -- UPDATE THIS LIST as needed for your specific analysis
    28775, 32743, 30358, 31310, 237, 32908, 32984, 15143, 
    32615, 12210, 317, 31668, 32965, 25949, 31570, 32920, 
    21829, 29049, 27501, 29623, 30864, 28778, 32332, 32823, 12042
)
AND proc.ProcDate BETWEEN DATE_SUB(CURDATE(), INTERVAL 90 DAY) AND CURDATE()
AND proc.ProcStatus = 2 -- Completed procedures
ORDER BY proc.PatNum, proc.ProcDate DESC;