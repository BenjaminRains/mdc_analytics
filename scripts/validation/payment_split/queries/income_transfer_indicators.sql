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
 * - Modify date ranges and patient lists as needed for your specific analysis
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
 * - Date range: Currently set to last 90 days, adjust as needed
 * - ProcStatus = 2: Shows only completed procedures (adjust if needed)
 * 
 * INTERPRETATION:
 * The provider listed for completed procedures is often the correct provider
 * for unassigned payment transactions from the same patient.
 */
-- Find recent procedures for patients with unassigned payments
SELECT
    proc.ProcNum,
    proc.ProcDate,
    proc.ProvNum,
    CONCAT(prov.FName, ' ', prov.LName) AS ProviderName,
    proc.PatNum,
    CONCAT(pat.LName, ', ', pat.FName) AS PatientName,
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
 * - Date range: Currently set to 2025-01-01 onward, adjust as needed
 * 
 * INTERPRETATION:
 * - Users with high transaction counts need targeted training
 * - User groups with systematic issues may need process redesign
 * - First/last transaction dates help identify when issues began
 */
-- Find which user groups are creating unassigned payments
SELECT
    u.UserName,
    ug.Description AS UserGroupName,
    COUNT(*) AS TransactionCount,
    SUM(ps.SplitAmt) AS TotalAmount,
    MIN(ps.DatePay) AS FirstTransaction,
    MAX(ps.DatePay) AS LastTransaction
FROM paysplit ps
LEFT JOIN userod u ON ps.SecUserNumEntry = u.UserNum
LEFT JOIN usergroupattach uga ON u.UserNum = uga.UserNum
LEFT JOIN usergroup ug ON uga.UserGroupNum = ug.UserGroupNum
WHERE ps.ProvNum = 0
AND ps.DatePay > '2025-01-01'
GROUP BY u.UserName, ug.Description
ORDER BY COUNT(*) DESC;


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
 * - Date range: Currently set to February 2025, adjust as needed
 * 
 * INTERPRETATION:
 * - Payment types with high occurrence rates may indicate workflow issues
 * - Can be used to target specific payment processing training
 */
-- Check payment sources for unassigned transactions
SELECT
    pay.PayType,
    def.ItemName AS PayTypeName,
    COUNT(*) AS TransactionCount,
    SUM(ps.SplitAmt) AS TotalAmount
FROM paysplit ps
INNER JOIN payment pay ON ps.PayNum = pay.PayNum
LEFT JOIN definition def ON pay.PayType = def.DefNum AND def.Category = 'PaymentTypes'
WHERE ps.ProvNum = 0
AND ps.DatePay BETWEEN '2025-02-01' AND '2025-02-28'
GROUP BY pay.PayType, def.ItemName
ORDER BY COUNT(*) DESC;


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
 * - Date range: Currently set to 2025-01-01 to 2025-03-15, adjust as needed
 * 
 * INTERPRETATION:
 * The provider who saw the patient closest to the payment date is often
 * the correct provider to assign to the unassigned transaction.
 */
-- Find appointments near payment date to identify correct provider
SELECT
    pat.PatNum,
    CONCAT(pat.LName, ', ', pat.FName) AS PatientName,
    apt.AptDateTime,
    apt.ProvNum,
    CONCAT(prov.FName, ' ', prov.LName) AS ProviderName
FROM patient pat
INNER JOIN appointment apt ON pat.PatNum = apt.PatNum
LEFT JOIN provider prov ON apt.ProvNum = prov.ProvNum
WHERE pat.PatNum IN (
    -- List of PatNums from your results
    -- UPDATE THIS LIST as needed for your specific analysis
    28775, 32743, 30358, 31310, 237, 32908, 32984, 15143, 
    32615, 12210, 317, 31668, 32965, 25949, 31570, 32920, 
    21829, 29049, 27501, 29623, 30864, 28778, 32332, 32823, 12042
)
AND apt.AptDateTime BETWEEN '2025-01-01' AND '2025-03-15'
ORDER BY pat.PatNum, apt.AptDateTime;


/*
 * QUERY 5: TEMPORAL PATTERN ANALYSIS
 * ===============================================================================
 * 
 * PURPOSE:
 * Analyzes the timing patterns of unassigned provider transactions by user,
 * helping identify if specific days or time periods are associated with higher
 * rates of unassigned transactions.
 *
 * PARAMETERS:
 * - Date range: Currently set to 2025-01-01 onward, adjust as needed
 * 
 * INTERPRETATION:
 * - Patterns by day of week may indicate staffing or workload issues
 * - Spikes on specific dates may correlate with training changes or system updates
 */
-- Analyze time patterns of unassigned payments by user
SELECT
    u.UserName,
    DATE(ps.DatePay) AS EntryDate,
    COUNT(*) AS TransactionCount,
    SUM(ps.SplitAmt) AS TotalAmount
FROM paysplit ps
LEFT JOIN userod u ON ps.SecUserNumEntry = u.UserNum
WHERE ps.ProvNum = 0
AND ps.DatePay > '2025-01-01'
GROUP BY u.UserName, DATE(ps.DatePay)
ORDER BY u.UserName, DATE(ps.DatePay);


/*
 * QUERY 6: COMPREHENSIVE UNASSIGNED TRANSACTION ANALYSIS
 * ===============================================================================
 * 
 * PURPOSE:
 * Provides detailed information about unassigned provider transactions for specific
 * patients, including payment details, user information, suggested provider based on
 * appointment history, and related transactions.
 *
 * This is the most comprehensive query for investigating specific patient accounts
 * and determining the appropriate provider assignments.
 *
 * PARAMETERS:
 * - Patient list: Currently filtered by specific patient last names, modify as needed
 * - Amount filter: Currently shows only negative amounts, adjust based on your analysis needs
 * 
 * INTERPRETATION:
 * - The SuggestedProvider field indicates the likely correct provider based on appointment history
 * - RelatedSplits shows other payment splits from the same payment, which may help understand the context
 * - RecentProcedure provides information about recent treatment that may be related to the payment
 */
-- Find detailed payment information for patients with unassigned provider transactions
SELECT 
    -- Patient Information
    pat.PatNum,
    CONCAT(pat.LName, ', ', pat.FName) AS PatientName,
    
    -- Payment Split Information
    ps.SplitNum,
    ps.PayNum,
    ps.ProcNum,
    ps.DatePay,
    ps.ProvNum,
    ps.SplitAmt,
    ps.PatNum AS SplitPatNum,
    ps.UnearnedType,
    ps.SecUserNumEntry AS SplitEnteredBy,
    
    -- Payment Information
    pay.PayType,
    pay.PayDate,
    pay.PayAmt,
    pay.CheckNum,
    pay.BankBranch AS PaymentNote,
    
    -- User Information who entered the split
    u.UserName AS EnteredByUser,
    
    -- Payment Type Information
    def.ItemName AS PaymentTypeName,
    
    -- Add a join to get UnearnedType description
    unearnedDef.ItemName AS UnearnedTypeDesc,
    
    -- Recent Appointment Information
    (SELECT MAX(apt.AptDateTime) 
     FROM appointment apt 
     WHERE apt.PatNum = pat.PatNum 
     AND apt.AptDateTime <= ps.DatePay) AS LastAppointmentDate,
    
    -- Associated Provider (from last appointment)
    (SELECT apt.ProvNum 
     FROM appointment apt 
     WHERE apt.PatNum = pat.PatNum 
     AND apt.AptDateTime = (SELECT MAX(apt2.AptDateTime) 
                           FROM appointment apt2 
                           WHERE apt2.PatNum = pat.PatNum 
                           AND apt2.AptDateTime <= ps.DatePay)) AS LastAppointmentProvNum,
    
    -- Associated Provider Name
    (SELECT CONCAT(prov.FName, ' ', prov.LName) 
     FROM provider prov
     WHERE prov.ProvNum = (SELECT apt.ProvNum 
                          FROM appointment apt 
                          WHERE apt.PatNum = pat.PatNum 
                          AND apt.AptDateTime = (SELECT MAX(apt2.AptDateTime) 
                                                FROM appointment apt2 
                                                WHERE apt2.PatNum = pat.PatNum 
                                                AND apt2.AptDateTime <= ps.DatePay))) AS SuggestedProvider,
    
    -- Add related transactions
    (SELECT GROUP_CONCAT(CONCAT(ps2.SplitNum, ':', ps2.ProvNum, ':', ps2.SplitAmt) SEPARATOR ', ')
     FROM paysplit ps2
     WHERE ps2.PayNum = ps.PayNum AND ps2.SplitNum != ps.SplitNum) AS RelatedSplits,
    
    -- Add most recent procedure info
    (SELECT CONCAT(proc.ProcDate, ': ', proc.ProcFee, ' - ', prov.LName)
     FROM procedurelog proc
     LEFT JOIN provider prov ON proc.ProvNum = prov.ProvNum
     WHERE proc.PatNum = pat.PatNum
     ORDER BY proc.ProcDate DESC
     LIMIT 1) AS RecentProcedure
    
FROM paysplit ps
JOIN patient pat ON ps.PatNum = pat.PatNum
JOIN payment pay ON ps.PayNum = pay.PayNum
LEFT JOIN userod u ON ps.SecUserNumEntry = u.UserNum
LEFT JOIN definition def ON pay.PayType = def.DefNum AND def.Category = 'PaymentTypes'
LEFT JOIN definition unearnedDef ON ps.UnearnedType = unearnedDef.DefNum

WHERE 
    -- Filter for only unassigned payments
    ps.ProvNum = 0
    
    -- Filter for only these specific patients
    -- UPDATE THIS LIST as needed for your specific analysis
    AND pat.LName IN ('Hein', 'Herrod', 'Mauger', 'Patterson', 'Blonski', 
                     'Ciesielski', 'Lee', 'Kramer', 'Bornstein', 'Souther', 
                     'Mendez', 'McDonald', 'Garbison', 'Sedlak', 'Remmers')
    
    -- For negative amounts (modify this filter as needed)
    AND ps.SplitAmt < 0
    
ORDER BY ps.DatePay DESC, ABS(ps.SplitAmt) DESC;


/*
 * ===============================================================================
 * USAGE RECOMMENDATIONS
 * ===============================================================================
 * 
 * 1. INVESTIGATIVE WORKFLOW:
 *    a. Start with Query 2 (User Group Analysis) to identify which users are
 *       creating the most unassigned transactions
 *    b. Use Query 3 (Payment Source Analysis) to understand which payment types
 *       are most problematic
 *    c. For specific patients, use Query 4 (Appointment Analysis) and 
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
