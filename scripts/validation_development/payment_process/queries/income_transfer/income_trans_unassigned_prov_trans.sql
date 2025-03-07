/*
 * ===============================================================================
 * QUERY NAME: income_trans_unassigned_prov_trans.sql
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
 * - Shows patient account balance at time of transaction
 * 
 *
 * SECTION 1: PAYMENT SPLITS WITH UNASSIGNED PROVIDERS
 * ===============================================================================
 * Identifies payment split transactions where ProvNum = 0 (unassigned provider).
 * Includes payment details, patient information, and suggests the most likely
 * provider based on appointment history.
 *
 * KEY FEATURES:
 * - transaction_type: Always 'PaySplit' in this section to distinguish from adjustments
 * - pay_type_name: Resolves payment type codes to human-readable names using definition table
 * - suggested_provider: Derived from the most recent appointment before the payment date
 * - priority: Calculated based on amount size and transaction age
 * - days_old: Number of days since the transaction was created
 * - account_balance: Shows the patient's balance at the time of the transaction
 * - transaction_category: Classifies transaction as Income Transfer, Credit Allocation, etc.
 * - original_payment_info: Shows source of funds for transfers/allocations
 *
 * SECTION 2: ADJUSTMENTS WITH UNASSIGNED PROVIDERS
 * ===============================================================================
 * Identifies adjustment transactions where ProvNum = 0 (unassigned provider).
 * Structurally similar to the payment splits section to enable the UNION,
 * but sources data from the adjustment table instead.
 *
 * KEY DIFFERENCES FROM PAYMENT SPLITS:
 * - transaction_type: Always 'Adjustment' to distinguish from payment splits
 * - pay_num: Set to 0 as placeholder since adjustments don't have PayNum
 * - pay_type_name: Maps to adjustment types instead of payment types
 * - Uses AdjAmt instead of SplitAmt (but aliased as amount for the UNION)
 * - Uses ABS() for amount thresholds since adjustments can be negative
 *
 * - Dependent CTEs: None
 * - Date Filter: Use @start_date to @end_date variables
 */
SELECT 
    'PaySplit' AS transaction_type,
    ps.SplitNum AS transaction_num,
    ps.PayNum,
    ps.PatNum,
    CONCAT(p.LName, ', ', p.FName) AS patient_name,
    ps.SplitAmt AS amount,
    pay.PayDate AS transaction_date,
    -- Enhanced payment type display with fallback for special cases
    CASE
        -- Check if payment type exists in definition
        WHEN (SELECT d.ItemName 
              FROM definition d 
              WHERE d.Category = 24  -- Payment Type category
              AND d.DefNum = pay.PayType) IS NOT NULL 
        THEN (SELECT d.ItemName 
              FROM definition d 
              WHERE d.Category = 24
              AND d.DefNum = pay.PayType)
        -- Classify based on note text patterns
        WHEN pay.PayNote LIKE '%income transfer%' THEN 'Income Transfer'
        WHEN pay.PayNote LIKE '%reallocation%' THEN 'Credit Reallocation'
        WHEN pay.PayNote LIKE '%refund%' THEN 'Refund'
        WHEN pay.PayNote LIKE '%deposit%' THEN 'Deposit'
        WHEN pay.PayNote LIKE '%overpayment%' THEN 'Overpayment'
        WHEN ps.ProcNum = 0 AND ps.SplitAmt > 0 THEN 'Unallocated Payment'
        WHEN ps.ProcNum = 0 AND ps.SplitAmt < 0 THEN 'Credit Adjustment'
        ELSE 'Unspecified'
    END AS pay_type_name,
    ps.ProcNum,
    pay.PayNote AS note,
    u.UserName AS entered_by,
    CASE 
        WHEN prov.FName IS NULL THEN 'Unassigned'
        ELSE CONCAT(prov.LName, ', ', prov.FName)
    END AS current_provider,
    -- Suggested provider based on most recent appointment
    (SELECT 
        CONCAT(prov2.LName, ', ', prov2.FName)
     FROM appointment a
     JOIN provider prov2 ON a.ProvNum = prov2.ProvNum
     WHERE a.PatNum = ps.PatNum
       AND a.AptDateTime <= pay.PayDate
     ORDER BY a.AptDateTime DESC
     LIMIT 1) AS suggested_provider,
    DATEDIFF(CURRENT_DATE, pay.PayDate) AS days_old,
    ROUND(
        (
            -- Current EstBalance
            p.EstBalance 
            -- Add back any payments made after this transaction
            + IFNULL((
                SELECT SUM(ps2.SplitAmt)
                FROM paysplit ps2
                JOIN payment pay2 ON ps2.PayNum = pay2.PayNum
                WHERE ps2.PatNum = ps.PatNum
                AND pay2.PayDate > pay.PayDate
            ), 0)
            -- Subtract any adjustments made after this transaction
            - IFNULL((
                SELECT SUM(adj.AdjAmt)
                FROM adjustment adj
                WHERE adj.PatNum = ps.PatNum
                AND adj.AdjDate > pay.PayDate
            ), 0)
        ),
        2
    ) AS account_balance,
    CASE
        WHEN pay.PayNote LIKE '%income transfer%' THEN 'Income Transfer'
        WHEN pay.PayNote LIKE '%reallocation%' THEN 'Credit Reallocation'
        WHEN ps.SplitAmt > 0 AND ps.ProcNum = 0 AND (
            SELECT ROUND(SUM(ps2.SplitAmt), 2) 
            FROM paysplit ps2 
            WHERE ps2.PayNum = ps.PayNum
        ) = 0 THEN 'Internal Transfer'
        WHEN ps.SplitAmt > 0 AND ps.ProcNum = 0 THEN 'Prepayment/Deposit'
        WHEN ps.SplitAmt < 0 AND ps.ProcNum = 0 THEN 'Credit/Refund'
        ELSE 'Standard Payment'
    END AS transaction_category,
    CASE
        WHEN pay.PayNote LIKE '%transfer%' OR pay.PayNote LIKE '%reallocation%' OR pay.PayNote LIKE '%credit%' THEN
            (SELECT CONCAT('Original payment: ', 
                    DATE_FORMAT(origpay.PayDate, '%Y-%m-%d'), 
                    ' - $', ROUND(origpay.PayAmt, 2),
                    CASE 
                        WHEN origdef.ItemName IS NOT NULL THEN CONCAT(' (', origdef.ItemName, ')')
                        ELSE ''
                    END,
                    ' - Provider: ',
                    CASE 
                        WHEN origprov.FName IS NOT NULL THEN CONCAT(origprov.LName, ', ', origprov.FName)
                        ELSE 'Unassigned'
                    END)
            FROM payment origpay
            LEFT JOIN paysplit origps ON origps.PayNum = origpay.PayNum
            LEFT JOIN definition origdef ON origpay.PayType = origdef.DefNum AND origdef.Category = 24
            LEFT JOIN provider origprov ON origps.ProvNum = origprov.ProvNum
            WHERE origps.PatNum = ps.PatNum
            AND origpay.PayDate < pay.PayDate
            AND origps.SplitAmt > 0
            ORDER BY origpay.PayDate DESC
            LIMIT 1)
        ELSE NULL
    END AS original_payment_info,
    CASE
        WHEN ps.SplitAmt > 5000 OR DATEDIFF(CURRENT_DATE, pay.PayDate) > 30 THEN 'Critical'
        WHEN ps.SplitAmt BETWEEN 1000 AND 5000 OR DATEDIFF(CURRENT_DATE, pay.PayDate) BETWEEN 15 AND 30 THEN 'High'
        WHEN ps.SplitAmt BETWEEN 200 AND 999 OR DATEDIFF(CURRENT_DATE, pay.PayDate) BETWEEN 7 AND 14 THEN 'Medium'
        ELSE 'Low'
    END AS priority
FROM paysplit ps
LEFT JOIN patient p ON ps.PatNum = p.PatNum
LEFT JOIN payment pay ON ps.PayNum = pay.PayNum
LEFT JOIN provider prov ON ps.ProvNum = prov.ProvNum
LEFT JOIN userod u ON ps.SecUserNumEntry = u.UserNum
WHERE ps.ProvNum = 0  -- Unassigned provider
AND pay.PayDate BETWEEN @start_date AND @end_date
AND ps.PayPlanNum = 0  -- Not attached to payment plan

UNION ALL

SELECT 
    'Adjustment' AS transaction_type,
    adj.AdjNum AS transaction_num,
    0 AS pay_num,  -- Placeholder since adjustments don't have PayNum
    adj.PatNum,
    CONCAT(p.LName, ', ', p.FName) AS patient_name,
    adj.AdjAmt AS amount,
    adj.AdjDate AS transaction_date,
    -- Get adjustment type name with improved fallback
    CASE
        WHEN (SELECT d.ItemName 
              FROM definition d 
              WHERE d.Category = 16  -- Adjustment Type category
              AND d.DefNum = adj.AdjType) IS NOT NULL 
        THEN (SELECT d.ItemName 
              FROM definition d 
              WHERE d.Category = 16
              AND d.DefNum = adj.AdjType)
        -- Classify based on note text and amount patterns
        WHEN adj.AdjNote LIKE '%write%off%' THEN 'Write-Off'
        WHEN adj.AdjNote LIKE '%courtesy%' THEN 'Courtesy Adjustment'
        WHEN adj.AdjNote LIKE '%transfer%' THEN 'Transfer Adjustment'
        WHEN adj.AdjAmt > 0 THEN 'Positive Adjustment'
        WHEN adj.AdjAmt < 0 THEN 'Negative Adjustment'
        ELSE 'Unspecified Adjustment'
    END AS pay_type_name,
    adj.ProcNum,
    adj.AdjNote AS note,
    u.UserName AS entered_by,
    CASE 
        WHEN prov.FName IS NULL THEN 'Unassigned'
        ELSE CONCAT(prov.LName, ', ', prov.FName)
    END AS current_provider,
    -- Suggested provider based on most recent appointment
    (SELECT 
        CONCAT(prov2.LName, ', ', prov2.FName)
     FROM appointment a
     JOIN provider prov2 ON a.ProvNum = prov2.ProvNum
     WHERE a.PatNum = adj.PatNum
       AND a.AptDateTime <= adj.AdjDate
     ORDER BY a.AptDateTime DESC
     LIMIT 1) AS suggested_provider,
    DATEDIFF(CURRENT_DATE, adj.AdjDate) AS days_old,
    ROUND(
        (
            -- Current EstBalance
            p.EstBalance 
            -- Add back any payments made after this transaction
            + IFNULL((
                SELECT SUM(ps2.SplitAmt)
                FROM paysplit ps2
                JOIN payment pay2 ON ps2.PayNum = pay2.PayNum
                WHERE ps2.PatNum = adj.PatNum
                AND pay2.PayDate > adj.AdjDate
            ), 0)
            -- Subtract any adjustments made after this transaction
            - IFNULL((
                SELECT SUM(adj2.AdjAmt)
                FROM adjustment adj2
                WHERE adj2.PatNum = adj.PatNum
                AND adj2.AdjDate > adj.AdjDate
            ), 0)
        ),
        2
    ) AS account_balance,
    CASE
        WHEN adj.AdjNote LIKE '%write%off%' THEN 'Write-Off'
        WHEN adj.AdjNote LIKE '%courtesy%' THEN 'Courtesy Adjustment'  
        WHEN adj.AdjNote LIKE '%transfer%' THEN 'Transfer Adjustment'
        WHEN adj.AdjAmt > 0 THEN 'Credit Adjustment'
        WHEN adj.AdjAmt < 0 THEN 'Debit Adjustment'
        ELSE 'Standard Adjustment'
    END AS transaction_category,
    (SELECT CONCAT('Recent payment: ', 
             DATE_FORMAT(relatedpay.PayDate, '%Y-%m-%d'), 
             ' - $', ROUND(relatedpay.PayAmt, 2))
     FROM payment relatedpay
     JOIN paysplit relatedps ON relatedps.PayNum = relatedpay.PayNum
     WHERE relatedps.PatNum = adj.PatNum
     AND ABS(DATEDIFF(relatedpay.PayDate, adj.AdjDate)) < 7  -- Related payments within 7 days
     ORDER BY ABS(DATEDIFF(relatedpay.PayDate, adj.AdjDate))
     LIMIT 1) AS original_payment_info,
    CASE
        WHEN ABS(adj.AdjAmt) > 5000 OR DATEDIFF(CURRENT_DATE, adj.AdjDate) > 30 THEN 'Critical'
        WHEN ABS(adj.AdjAmt) BETWEEN 1000 AND 5000 OR DATEDIFF(CURRENT_DATE, adj.AdjDate) BETWEEN 15 AND 30 THEN 'High'
        WHEN ABS(adj.AdjAmt) BETWEEN 200 AND 999 OR DATEDIFF(CURRENT_DATE, adj.AdjDate) BETWEEN 7 AND 14 THEN 'Medium'
        ELSE 'Low'
    END AS priority
FROM adjustment adj
LEFT JOIN patient p ON adj.PatNum = p.PatNum
LEFT JOIN provider prov ON adj.ProvNum = prov.ProvNum
LEFT JOIN userod u ON adj.SecUserNumEntry = u.UserNum
WHERE adj.ProvNum = 0  -- Unassigned provider
AND adj.AdjDate BETWEEN @start_date AND @end_date
ORDER BY priority, ABS(amount) DESC;