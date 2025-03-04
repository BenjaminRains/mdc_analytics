/*
 * ===============================================================================
 * UNASSIGNED PROVIDER TRANSACTIONS REPORT
 * ===============================================================================
 * 
 * PURPOSE:
 * This SQL query generates a comprehensive report of all unassigned provider 
 * transactions in OpenDental, combining both payment splits and adjustments.
 * The report is designed for weekly monitoring and resolution of unassigned
 * provider transactions as part of the income transfer workflow.
 *
 * FEATURES:
 * - Identifies ALL unassigned provider transactions within a specified date range
 * - Combines both payment splits and adjustments in a single report
 * - Provides suggested provider assignments based on appointment history
 * - Includes priority classification (Critical/High/Medium/Low)
 * - Displays transaction age in days
 * - Shows who entered each transaction
 *
 * USAGE:
 * 1. Modify the date range parameters as needed (default: current 2-month period)
 * 2. Execute as part of the weekly unassigned provider monitoring process
 * 3. Export results to a pipe-delimited (|) file for distribution
 * 4. Use results to assign correct providers to each transaction
 *
 * DEPENDENCIES:
 * - OpenDental database schema (tested with versions 21.x and 22.x)
 * - Requires access to the following tables:
 *   - paysplit
 *   - payment
 *   - patient
 *   - userod
 *   - provider
 *   - appointment
 *   - adjustment
 *   - definition
 *
 * RELATED DOCUMENTATION:
 * - income_transfer_workflow.md: Detailed workflow procedures
 * - income_transfer_data_obs.md: Analysis of unassigned provider transactions
 * - income_transfer_indicators.sql: Additional analysis queries
 *
 * REVISION HISTORY:
 * 2025-03-05: Enhanced documentation and parameter explanations
 * 2025-03-02: Added adjustment transactions and priority classification
 * 2025-02-15: Added suggested provider logic based on appointment history
 * 2025-01-20: Initial query creation
 * 
 * ===============================================================================
 */

/*
 * MAIN REPORT QUERY
 * ===============================================================================
 * This query combines two parts:
 * 1. Payment splits with unassigned providers
 * 2. Adjustments with unassigned providers
 * 
 * The results are unified through a UNION ALL and sorted by priority and amount.
 */

/*
 * SECTION 1: PAYMENT SPLITS WITH UNASSIGNED PROVIDERS
 * ===============================================================================
 * Identifies payment split transactions where ProvNum = 0 (unassigned provider).
 * Includes payment details, patient information, and suggests the most likely
 * provider based on appointment history.
 *
 * KEY FEATURES:
 * - TransactionType: Always 'PaySplit' in this section to distinguish from adjustments
 * - PayTypeName: Resolves payment type codes to human-readable names using definition table
 * - SuggestedProvider: Derived from the most recent appointment before the payment date
 * - Priority: Calculated based on amount size and transaction age
 * - DaysOld: Number of days since the transaction was created
 *
 * CUSTOMIZATION:
 * - Update the date range in the WHERE clause to focus on a specific period
 * - Modify the CASE statement thresholds to adjust priority classification
 */
SELECT 
    'PaySplit' AS TransactionType,
    ps.SplitNum AS TransactionNum,
    ps.PayNum,
    ps.PatNum,
    CONCAT(p.LName, ', ', p.FName) AS PatientName,
    ps.SplitAmt,
    pay.PayDate AS TransactionDate,
    -- Map payment type using definition table
    (SELECT d.ItemName 
     FROM definition d 
     WHERE d.Category = 24  -- Payment Type category
     AND d.DefNum = pay.PayType) AS PayTypeName,
    ps.ProcNum,
    pay.PayNote AS Note,
    u.UserName AS EnteredBy,
    CASE 
        WHEN prov.FName IS NULL THEN 'Unassigned'
        ELSE CONCAT(prov.LName, ', ', prov.FName)
    END AS CurrentProvider,
    -- Suggested provider based on most recent appointment
    (SELECT 
        CONCAT(prov2.LName, ', ', prov2.FName)
     FROM appointment a
     JOIN provider prov2 ON a.ProvNum = prov2.ProvNum
     WHERE a.PatNum = ps.PatNum
       AND a.AptDateTime <= pay.PayDate
     ORDER BY a.AptDateTime DESC
     LIMIT 1) AS SuggestedProvider,
    DATEDIFF(CURRENT_DATE, pay.PayDate) AS DaysOld,
    CASE
        -- Priority calculation logic:
        -- 1. Critical: Large amounts (>$5000) or old transactions (>30 days)
        -- 2. High: Medium amounts ($1000-$5000) or moderately old (15-30 days)
        -- 3. Medium: Small amounts ($200-$999) or recent (7-14 days)
        -- 4. Low: Tiny amounts (<$200) and very recent (<7 days)
        WHEN ps.SplitAmt > 5000 OR DATEDIFF(CURRENT_DATE, pay.PayDate) > 30 THEN 'Critical'
        WHEN ps.SplitAmt BETWEEN 1000 AND 5000 OR DATEDIFF(CURRENT_DATE, pay.PayDate) BETWEEN 15 AND 30 THEN 'High'
        WHEN ps.SplitAmt BETWEEN 200 AND 999 OR DATEDIFF(CURRENT_DATE, pay.PayDate) BETWEEN 7 AND 14 THEN 'Medium'
        ELSE 'Low'
    END AS Priority
FROM paysplit ps
LEFT JOIN patient p ON ps.PatNum = p.PatNum
LEFT JOIN payment pay ON ps.PayNum = pay.PayNum
LEFT JOIN provider prov ON ps.ProvNum = prov.ProvNum
LEFT JOIN userod u ON ps.SecUserNumEntry = u.UserNum
WHERE ps.ProvNum = 0  -- Unassigned provider
-- DATE RANGE PARAMETER: Modify these dates to focus on a specific period
-- Default: Current year-to-date or most recent 2-month period
AND pay.PayDate BETWEEN '2025-01-01' AND '2025-02-29'
AND ps.PayPlanNum = 0  -- Not attached to payment plan

UNION ALL

/*
 * SECTION 2: ADJUSTMENTS WITH UNASSIGNED PROVIDERS
 * ===============================================================================
 * Identifies adjustment transactions where ProvNum = 0 (unassigned provider).
 * Structurally similar to the payment splits section to enable the UNION,
 * but sources data from the adjustment table instead.
 *
 * KEY DIFFERENCES FROM PAYMENT SPLITS:
 * - TransactionType: Always 'Adjustment' to distinguish from payment splits
 * - PayNum: Set to 0 as placeholder since adjustments don't have PayNum
 * - PayTypeName: Maps to adjustment types instead of payment types
 * - Uses AdjAmt instead of SplitAmt (but aliased as SplitAmt for the UNION)
 * - Uses ABS() for amount thresholds since adjustments can be negative
 *
 * CUSTOMIZATION:
 * - Update the date range in the WHERE clause (keep in sync with Section 1)
 * - Adjust priority thresholds if needed for adjustment transactions
 */
-- Add adjustments with unassigned providers
SELECT 
    'Adjustment' AS TransactionType,
    adj.AdjNum AS TransactionNum,
    0 AS PayNum,  -- Placeholder since adjustments don't have PayNum
    adj.PatNum,
    CONCAT(p.LName, ', ', p.FName) AS PatientName,
    adj.AdjAmt AS SplitAmt,
    adj.AdjDate AS TransactionDate,
    -- Get adjustment type name
    (SELECT d.ItemName 
     FROM definition d 
     WHERE d.Category = 16  -- Adjustment Type category
     AND d.DefNum = adj.AdjType) AS PayTypeName,
    adj.ProcNum,
    adj.AdjNote AS Note,
    u.UserName AS EnteredBy,
    CASE 
        WHEN prov.FName IS NULL THEN 'Unassigned'
        ELSE CONCAT(prov.LName, ', ', prov.FName)
    END AS CurrentProvider,
    -- Suggested provider based on most recent appointment
    (SELECT 
        CONCAT(prov2.LName, ', ', prov2.FName)
     FROM appointment a
     JOIN provider prov2 ON a.ProvNum = prov2.ProvNum
     WHERE a.PatNum = adj.PatNum
       AND a.AptDateTime <= adj.AdjDate
     ORDER BY a.AptDateTime DESC
     LIMIT 1) AS SuggestedProvider,
    DATEDIFF(CURRENT_DATE, adj.AdjDate) AS DaysOld,
    CASE
        -- Using ABS() for adjustment amounts since they can be negative
        WHEN ABS(adj.AdjAmt) > 5000 OR DATEDIFF(CURRENT_DATE, adj.AdjDate) > 30 THEN 'Critical'
        WHEN ABS(adj.AdjAmt) BETWEEN 1000 AND 5000 OR DATEDIFF(CURRENT_DATE, adj.AdjDate) BETWEEN 15 AND 30 THEN 'High'
        WHEN ABS(adj.AdjAmt) BETWEEN 200 AND 999 OR DATEDIFF(CURRENT_DATE, adj.AdjDate) BETWEEN 7 AND 14 THEN 'Medium'
        ELSE 'Low'
    END AS Priority
FROM adjustment adj
LEFT JOIN patient p ON adj.PatNum = p.PatNum
LEFT JOIN provider prov ON adj.ProvNum = prov.ProvNum
LEFT JOIN userod u ON adj.SecUserNumEntry = u.UserNum
WHERE adj.ProvNum = 0  -- Unassigned provider
-- DATE RANGE PARAMETER: Keep in sync with the date range in Section 1
AND adj.AdjDate BETWEEN '2025-01-01' AND '2025-02-29'

/*
 * RESULT ORDERING
 * ===============================================================================
 * Results are ordered by:
 * 1. Priority (Critical → High → Medium → Low)
 * 2. Absolute transaction amount (largest first)
 * 
 * This ensures that the most important transactions appear at the top of the report.
 */
ORDER BY Priority, ABS(SplitAmt) DESC;

/*
 * ===============================================================================
 * USAGE GUIDE FOR WEEKLY MONITORING PROCESS
 * ===============================================================================
 * 
 * This query is designed to be used as part of the weekly unassigned provider
 * transaction monitoring process. Follow these steps each week:
 * 
 * 1. UPDATE DATE RANGE
 *    - Change the date parameters to cover the desired period
 *    - For weekly monitoring: previous 30-90 days
 *    - For initial cleanup: may need to go back further
 * 
 * 2. RUN THE QUERY
 *    - Execute every Monday morning
 *    - Save results with the filename format: YYYY-MM-DD_unassigned_provider_report.txt
 * 
 * 3. REVIEW RESULTS
 *    - Focus first on Critical priority items
 *    - Verify suggested providers are appropriate
 *    - Distribute to staff for resolution according to priority
 * 
 * 4. TRACK RESOLUTION
 *    - Document which transactions have been resolved
 *    - Follow up on any transactions that miss their resolution deadline
 * 
 * 5. ADJUST PARAMETERS AS NEEDED
 *    - If too many/few transactions are marked as Critical, adjust thresholds
 *    - If date range is capturing too many old transactions, narrow the range
 * 
 * EXPECTED PERFORMANCE METRICS:
 * - Zero "Critical" priority transactions at end of each week
 * - <5 new unassigned transactions per week
 * - >95% resolution of all identified transactions each week
 * 
 * For the complete weekly process, refer to Section 12 in income_transfer_workflow.md
 * ===============================================================================
 */