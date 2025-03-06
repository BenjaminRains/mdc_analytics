/*
Negative Prepayments Query
========================

Purpose:
- Identify negative prepayment transactions (potential refunds or adjustments)
- Shows patient information, payment type, and notes for investigation
- Helps identify potential issues with unearned income accounting

NOTE FOR PANDAS ANALYSIS:
- This query explains the large negative unearned income values seen in the monthly trend report
- Negative values represent application of previously collected prepayments to actual procedures
- Key transformation steps:
  1. Parse dates: df['Payment Date'] = pd.to_datetime(df['Payment Date'])
  2. Convert amounts: df['Split Amount'] = df['Split Amount'].str.replace(',', '').str.replace('$', '').astype(float)
  3. Extract reason categories: df['Reason'] = df['Payment Note'].str.extract(r'^([\w\s]+)\.', expand=False)
  4. Group by patient: patient_summary = df.groupby(['Patient Number', 'Patient Name']).agg({'Split Amount': ['sum', 'count']})
- Analytical considerations:
  1. October 2024 has the highest concentration of prepayment applications
  2. Look for standardized prepayment amounts (-$1,950.00, -$1,288.00, -$1,211.00)
  3. Pattern of sequential applications on the same day for the same patient
  4. Correlation between Payment Notes and amount patterns

- Dependencies: None (performs definition lookup directly)
- Date Filter: @start_date to @end_date
*/

-- Negative prepayments (potential refunds or adjustments)
SELECT
    DATE_FORMAT(ps.DatePay, '%m/%d/%Y') AS 'Payment Date',
    ps.PatNum AS 'Patient Number',
    CONCAT(pt.LName, ', ', pt.FName) AS 'Patient Name',
    IFNULL(
        (SELECT def.ItemName 
         FROM definition def 
         WHERE def.DefNum = ps.UnearnedType), 
        'Unknown'
    ) AS 'Unearned Type',
    FORMAT(ps.SplitAmt, 2) AS 'Split Amount',
    IFNULL(pm.PayNote, '') AS 'Payment Note'
FROM paysplit ps
INNER JOIN payment pm ON pm.PayNum = ps.PayNum
INNER JOIN patient pt ON pt.PatNum = ps.PatNum
WHERE ps.DatePay BETWEEN @start_date AND @end_date
    AND ps.UnearnedType != 0
    AND ps.SplitAmt < 0
ORDER BY ps.SplitAmt; 