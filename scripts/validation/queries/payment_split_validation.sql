/*
 * Payment and Split Validation Query
 * 
 * Purpose: Analyze payment records and their splits for validation and anomaly detection
 * Time period: 2024 calendar year
 * 
 * Output Structure:
 * Two result branches combined via UNION ALL:
 * 1. Summary Branch (report_type = 'summary')
 *    - Overall payment statistics and patterns
 *    - Payment method distributions
 *    - Insurance vs Patient payments
 *    - Split patterns and timing
 * 
 * 2. Problem Detail Branch (report_type = 'problem_detail')
 *    - Individual problematic payments
 *    - Split mismatches
 *    - Complex split patterns
 *    - Overpayment cases
 * 
 * Common Metrics (23 columns):
 * - total_payments: Count/PayNum
 * - avg_splits_per_payment: Average splits/PayAmt
 * - payments_with_split_mismatch: Mismatch count/split_count
 * - payment_method_count: Distinct methods
 * - total_reversals: Negative payment count
 * - insurance_payments: Insurance payment count
 * - patient_payments: Patient payment count
 * - normal_split_count: 1-3 splits
 * - complex_split_count: 4-15 splits
 * - review_needed_count: >15 splits
 * - avg_days_to_payment: Payment timing
 * - payment patterns: Split sequences
 * - split_difference: Amount discrepancies
 * - split_count: Total splits
 * 
 * Key CTEs:
 * - PaymentSummary: Basic payment metrics
 * - PaymentMethodAnalysis: Payment type patterns
 * - InsurancePaymentAnalysis: Source analysis
 * - ProcedurePayments: Procedure-payment links
 * - SplitPatternAnalysis: Split complexity
 */

WITH PaymentSummary AS (
    SELECT 
        p.PayNum,
        p.PayAmt,
        p.PayDate,
        p.PayType,
        p.PayNote,
        COUNT(ps.SplitNum) AS split_count,
        SUM(ps.SplitAmt) AS total_split_amount,
        ABS(p.PayAmt - SUM(ps.SplitAmt)) AS split_difference,
        CASE WHEN p.PayAmt < 0 THEN 1 ELSE 0 END AS is_reversal
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY p.PayNum, p.PayAmt, p.PayDate, p.PayType, p.PayNote
),
PaymentMethodAnalysis AS (
    SELECT 
        p.PayType,
        COUNT(*) AS payment_count,
        SUM(p.PayAmt) AS total_amount,
        COUNT(CASE WHEN p.PayAmt < 0 THEN 1 END) AS reversal_count,
        AVG(CASE WHEN ps.split_difference > 0.01 THEN 1 ELSE 0 END) AS error_rate
    FROM payment p
    JOIN PaymentSummary ps ON p.PayNum = ps.PayNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY p.PayType
),
InsurancePaymentAnalysis AS (
    SELECT 
        CASE 
            WHEN cp.InsPayAmt IS NOT NULL THEN 'Insurance'
            ELSE 'Patient'
        END AS payment_source,
        COUNT(DISTINCT ps.PayNum) AS payment_count,
        SUM(ps.SplitAmt) AS total_paid,
        AVG(DATEDIFF(p.PayDate, pl.ProcDate)) AS avg_days_to_payment
    FROM paysplit ps
    JOIN payment p ON ps.PayNum = p.PayNum
    JOIN procedurelog pl ON ps.ProcNum = pl.ProcNum
    LEFT JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
    GROUP BY 
        CASE 
            WHEN cp.InsPayAmt IS NOT NULL THEN 'Insurance'
            ELSE 'Patient'
        END
),
ProcedurePayments AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        pl.ProcStatus,
        pl.CodeNum,
        ps.PayNum,
        ps.SplitAmt,
        p.PayAmt,
        p.PayDate,
        ps.UnearnedType,
        DATEDIFF(p.PayDate, pl.ProcDate) AS days_to_payment,
        ROW_NUMBER() OVER (PARTITION BY pl.ProcNum ORDER BY p.PayDate) AS payment_sequence
    FROM procedurelog pl
    JOIN paysplit ps ON pl.ProcNum = ps.ProcNum
    JOIN payment p ON ps.PayNum = p.PayNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
),
SplitPatternAnalysis AS (
    SELECT 
        ProcNum,
        COUNT(DISTINCT PayNum) AS payment_count,
        COUNT(*) AS split_count,
        SUM(SplitAmt) AS total_paid,
        AVG(days_to_payment) AS avg_days_to_payment,
        GROUP_CONCAT(payment_sequence ORDER BY payment_sequence) AS payment_sequence_pattern,
        CASE 
            WHEN COUNT(*) BETWEEN 1 AND 3 THEN 'normal_split'
            WHEN COUNT(*) BETWEEN 4 AND 15 THEN 'complex_split'
            WHEN COUNT(*) > 15 THEN 'review_needed'
            ELSE 'no_splits'
        END AS split_pattern
    FROM ProcedurePayments
    GROUP BY ProcNum
)

-- Main Analysis Output: UNION ALL of summary and detailed branches
SELECT * FROM (
  -- Summary Branch: 23 columns
  SELECT 
      'summary' AS report_type,
      COUNT(DISTINCT ps.PayNum) AS total_payments,
      AVG(ps.split_count) AS avg_splits_per_payment,
      SUM(CASE WHEN ps.split_difference > 0.01 THEN 1 ELSE 0 END) AS payments_with_split_mismatch,
      COUNT(DISTINCT pma.PayType) AS payment_method_count,
      MAX(pma.reversal_count) AS total_reversals,
      SUM(CASE WHEN ipa.payment_source = 'Insurance' THEN ipa.payment_count ELSE 0 END) AS insurance_payments,
      SUM(CASE WHEN ipa.payment_source = 'Patient' THEN ipa.payment_count ELSE 0 END) AS patient_payments,
      COUNT(CASE WHEN spa.split_pattern = 'normal_split' THEN 1 END) AS normal_split_count,
      COUNT(CASE WHEN spa.split_pattern = 'complex_split' THEN 1 END) AS complex_split_count,
      COUNT(CASE WHEN spa.split_pattern = 'review_needed' THEN 1 END) AS review_needed_count,
      AVG(spa.avg_days_to_payment) AS avg_days_to_payment,
      MAX(spa.payment_count) AS max_payments_per_procedure,
      AVG(spa.payment_count) AS avg_payments_per_procedure,
      GROUP_CONCAT(DISTINCT CASE WHEN spa.split_count > 3 THEN spa.payment_sequence_pattern END) AS complex_payment_patterns,
      AVG(pp.ProcFee) AS avg_procedure_fee,
      AVG(spa.total_paid) AS avg_total_paid,
      COUNT(CASE WHEN spa.total_paid > pp.ProcFee THEN 1 ELSE 0 END) AS overpayment_count,
      COUNT(CASE WHEN pp.UnearnedType = 0 THEN 1 ELSE 0 END) AS regular_payment_count,
      COUNT(CASE WHEN pp.UnearnedType = 288 THEN 1 ELSE 0 END) AS prepayment_count,
      COUNT(CASE WHEN pp.UnearnedType = 439 THEN 1 ELSE 0 END) AS tp_prepayment_count,
      0 AS split_difference,
      0 AS split_count
  FROM PaymentSummary ps
  LEFT JOIN ProcedurePayments pp ON ps.PayNum = pp.PayNum
  LEFT JOIN SplitPatternAnalysis spa ON pp.ProcNum = spa.ProcNum
  LEFT JOIN PaymentMethodAnalysis pma ON ps.PayType = pma.PayType
  LEFT JOIN InsurancePaymentAnalysis ipa ON 1=1
  WHERE pp.ProcNum IS NOT NULL

  UNION ALL

  -- Detailed Problem Cases Branch: 23 columns
  SELECT 
      'problem_detail' AS report_type,
      CAST(ps.PayNum AS CHAR) AS total_payments,
      p.PayAmt AS avg_splits_per_payment,
      ps.split_count AS payments_with_split_mismatch,
      NULL AS payment_method_count,
      NULL AS total_reversals,
      NULL AS insurance_payments,
      NULL AS patient_payments,
      ps.total_split_amount AS normal_split_count,
      ps.split_difference AS complex_split_count,
      CAST(pp.ProcNum AS CHAR) AS review_needed_count,
      pp.days_to_payment AS avg_days_to_payment,
      spa.payment_count AS max_payments_per_procedure,
      spa.payment_count AS avg_payments_per_procedure,
      spa.payment_sequence_pattern AS complex_payment_patterns,
      pp.ProcFee AS avg_procedure_fee,
      spa.total_paid AS avg_total_paid,
      CASE WHEN spa.total_paid > pp.ProcFee THEN 1 ELSE 0 END AS overpayment_count,
      CASE WHEN pp.UnearnedType = 0 THEN 1 ELSE 0 END AS regular_payment_count,
      0 AS prepayment_count,
      0 AS tp_prepayment_count,
      ps.split_difference AS split_difference,
      spa.split_count AS split_count
  FROM PaymentSummary ps
  JOIN ProcedurePayments pp ON ps.PayNum = pp.PayNum
  JOIN SplitPatternAnalysis spa ON pp.ProcNum = spa.ProcNum
  JOIN payment p ON p.PayNum = ps.PayNum
  WHERE ps.split_difference > 0.01
     OR spa.split_pattern = 'review_needed'
     OR spa.total_paid > pp.ProcFee
) combined_results
ORDER BY 
    report_type DESC,
    split_difference DESC,
    split_count DESC;
