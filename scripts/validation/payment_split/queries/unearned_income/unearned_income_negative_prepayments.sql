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
  1. Parse dates: df['payment_date'] = pd.to_datetime(df['payment_date'])
  2. Convert amounts: df['split_amount'] = df['split_amount'].str.replace(',', '').str.replace('$', '').astype(float)
  3. Extract reason categories: df['reason'] = df['payment_note'].str.extract(r'^([\w\s]+)\.', expand=False)
  4. Group by patient: patient_summary = df.groupby(['patient_number', 'patient_name']).agg({'split_amount': ['sum', 'count']})
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
    DATE_FORMAT(ps.DatePay, '%m/%d/%Y') AS payment_date,
    ps.PatNum AS patient_number,
    CONCAT(pt.LName, ', ', pt.FName) AS patient_name,
    IFNULL(
        (SELECT def.ItemName 
         FROM definition def 
         WHERE def.DefNum = ps.UnearnedType), 
        'Unknown'
    ) AS unearned_type,
    FORMAT(ps.SplitAmt, 2) AS split_amount,
    IFNULL(pm.PayNote, '') AS payment_note
FROM paysplit ps
INNER JOIN payment pm ON pm.PayNum = ps.PayNum
INNER JOIN patient pt ON pt.PatNum = ps.PatNum
WHERE ps.DatePay BETWEEN @start_date AND @end_date
    AND ps.UnearnedType != 0
    AND ps.SplitAmt < 0
ORDER BY ps.SplitAmt; 