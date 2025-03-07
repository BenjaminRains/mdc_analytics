/*
 * ===============================================================================
 * INCOME TRANSFER INDICATORS
 * ===============================================================================
 * 
 * PURPOSE:
 * This SQL file contains a collection of analytical queries designed to identify,
 * investigate, and resolve unassigned provider transactions in OpenDental. These
 * queries support the systematic identification of potential income transfers needed
 * and provide data for root cause analysis.
 *
 * USAGE:
 * - Run these queries separately as needed to investigate different aspects of
 *   unassigned provider transactions
 * - Dates are parameterized using @start_date and @end_date, which will be dynamically replaced by the export script
 * - For weekly monitoring, refer to the comprehensive unassigned provider report
 *   documented in income_transfer_workflow.md
 *
 * DEPENDENCIES:
 * - OpenDental database schema (tested with versions 21.x and 22.x)
 * - Requires access to the following tables:
 *   - paysplit
 *   - payment
 *   - patient
 *   - userod
 *   - provider
 *   - procedurelog
 *   - appointment
 *   - definition
 *   - usergroup
 *   - usergroupattach
 *
 * RELATED DOCUMENTATION:
 * - income_transfer_workflow.md: Detailed workflow procedures
 * - income_transfer_data_obs.md: Analysis of unassigned provider transactions
 *
 * REVISION HISTORY:
 * 2025-03-05: Enhanced documentation and query explanations
 * 2025-02-15: Added user group and payment source analysis
 * 2025-01-20: Initial query creation
 * 
 * ===============================================================================
 */

-- QUERY_NAME: recent_procedures_for_patients_with_unassigned_payments
/*
 * QUERY 1: RECENT PROCEDURE ANALYSIS
 * ===============================================================================
 * 
 * PURPOSE:
 * Identifies recent procedures for patients who have unassigned payments. This helps
 * determine the appropriate provider to assign to unassigned transactions by showing
 * which providers have actually performed work for these patients.
 *
 * PARAMETERS:
 * - PatNum list: Update with the patient IDs you want to analyze
 * - Date range: Uses date parameters from command line ('2025-01-01' to current date)
 * - ProcStatus = 2: Shows only completed procedures (adjust if needed)
 * 
 * INTERPRETATION:
 * The provider listed for completed procedures is often the correct provider
 * for unassigned payment transactions from the same patient.
 */
-- Dependent CTEs: None
-- Date filter: Use @start_date to @end_date variables
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

-- QUERY_NAME: user_groups_creating_unassigned_payments
/*
 * QUERY 2: USER GROUP ANALYSIS
 * ===============================================================================
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

-- QUERY_NAME: payment_sources_for_unassigned_transactions
/*
 * QUERY 3: PAYMENT SOURCE ANALYSIS
 * ===============================================================================
 * 
 * PURPOSE:
 * Analyzes the payment types (cash, credit card, etc.) that are most commonly
 * associated with unassigned provider transactions. This helps identify if
 * specific payment processing workflows are contributing to the issue.
 *
 * PARAMETERS:
 * - Date range: Uses date parameters from command line ('2025-01-01' to '2025-02-28')
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

-- QUERY_NAME: appointments_near_payment_date
/*
 * QUERY 4: APPOINTMENT ANALYSIS
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

-- QUERY_NAME: time_patterns_by_hour
/*
 * QUERY 5A: HOURLY PATTERN ANALYSIS
 * ===============================================================================
 * 
 * PURPOSE:
 * Analyzes when unassigned provider transactions are occurring by hour of day
 * to identify shift-related patterns or time periods with higher error rates.
 *
 * PARAMETERS:
 * - Date range: Reference year should match date from command line parameters
 * 
 * INTERPRETATION:
 * - Patterns by hour may indicate shift change issues or specific staffing concerns
 */
SELECT
    HOUR(DatePay) AS hour_of_day,
    COUNT(*) AS transaction_count,
    FORMAT(AVG(SplitAmt), 2) AS average_amount
FROM paysplit
WHERE ProvNum = 0
AND DatePay BETWEEN @start_date AND @end_date
GROUP BY HOUR(DatePay)
ORDER BY HOUR(DatePay);

-- QUERY_NAME: time_patterns_by_day
/*
 * QUERY 5B: WEEKDAY PATTERN ANALYSIS
 * ===============================================================================
 * 
 * PURPOSE:
 * Analyzes when unassigned provider transactions are occurring by day of week
 * to identify staffing or workflow issues on specific days.
 *
 * PARAMETERS:
 * - Date range: Reference year should match date from command line parameters
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

-- QUERY_NAME: time_patterns_by_month
/*
 * QUERY 5C: MONTHLY PATTERN ANALYSIS
 * ===============================================================================
 * 
 * PURPOSE:
 * Analyzes when unassigned provider transactions are occurring by month
 * to identify seasonal trends or system update related issues.
 *
 * PARAMETERS:
 * - Date range: Reference year should match date from command line parameters
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

-- QUERY_NAME: detailed_payment_information
/*
 * QUERY 6: COMPREHENSIVE ANALYSIS
 * ===============================================================================
 * 
 * PURPOSE:
 * Provides detailed information about unassigned provider transactions for
 * specific patients. This is useful for in-depth investigation of individual
 * accounts and problem solving.
 *
 * PARAMETERS:
 * - PatNum list: Update with the patient IDs you want to analyze
 * - Date range: Uses date parameters from command line ('2025-01-01' to '2025-02-28')
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
    -- Using COALESCE to avoid NULL values in PayTypeName
    COALESCE(def.ItemName, CONCAT('Type ', pay.PayType)) AS pay_type_name, 
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
-- Modified join to use a simpler condition
LEFT JOIN definition def ON pay.PayType = def.DefNum 
WHERE ps.ProvNum = 0
AND ps.PatNum IN (
    -- List of PatNums to analyze
    -- UPDATE THIS LIST as needed for your specific analysis
    28775, 32743, 30358
)
AND ps.DatePay BETWEEN @start_date AND @end_date
ORDER BY ps.PatNum, ps.DatePay DESC;

/*
 * ===============================================================================
 * USAGE RECOMMENDATIONS
 * ===============================================================================
 * 
 * Follow these guidelines to effectively utilize the queries in this file:
 * 
 * 1. INVESTIGATION WORKFLOW:
 *    a. Begin with Query 3 (Payment Source Analysis) to identify which payment types
 *       are most commonly associated with unassigned provider transactions
 *    b. Use Query 2 (User Group Analysis) to identify which users/groups need training
 *    c. For specific patients with unassigned transactions, use 
 *       Query 1 (Recent Procedure Analysis) to determine the correct provider
 *    d. Use Query 6 (Comprehensive Analysis) for detailed investigation of
 *       specific patient accounts
 * 
 * 2. ONGOING MONITORING:
 *    a. For systematic monitoring, use the weekly unassigned provider report
 *       process documented in income_transfer_workflow.md
 *    b. Use Query 5 (Temporal Pattern Analysis) monthly to identify trends
 *       in unassigned transaction creation
 * 
 * 3. TRAINING FOCUS:
 *    Use the results from Query 2 to target training for specific users
 *    and user groups with the highest rates of unassigned transactions
 * 
 * 4. PROCESS IMPROVEMENT:
 *    Use Query 3 results to identify specific payment workflows that may
 *    need redesign or additional validation
 * 
 * ===============================================================================
 */
