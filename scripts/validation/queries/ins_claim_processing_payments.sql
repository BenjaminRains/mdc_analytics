/*
 * Insurance Claim Processing and Payments Validation – Unified Output
 *
 * Output File Naming Convention:
 * Format: ins_claim_validation_2024_{datasource}.csv
 * Example: ins_claim_validation_2024_prod.csv
 *          ins_claim_validation_2024_test.csv
 * 
 * Location: scripts/validation/data/
 * Base Path: {project_root}/scripts/validation/data/
 * Full Path Example: C:/Users/rains/mdc_analytics/scripts/validation/data/
 *
 * File Structure:
 * - Encoding: UTF-8
 * - Delimiter: comma (,)
 * - Headers: Yes (first row)
 * - Date Format: YYYY-MM-DD
 * 
 * Purpose:
 *  - Validate if claims are linked to active insurance plans.
 *  - Identify claims with unverified insurance information.
 *  - Match procedures to claims and analyze claim-to-payment relationships.
 *  - Analyze insurance plans and carriers.
 *
 * Time Period: 2024 calendar year.
 *
 * Output Format:
 * CSV file with 10 columns, each row represents one validation record:
 
 * 
 * 1. OutputSection (VARCHAR): Analysis category
 *    Values: 
 *    - "Active Insurance Plan"
 *    - "Unverified Insurance Info"
 *    - "Claim Payment Matching"
 *    - "Plan and Carrier Analysis"
 *
 * 2. GroupLabel (VARCHAR): Context identifier
 *    Format varies by section:
 *    - Active Insurance: "Claim {ClaimNum} ({plan_status})"
 *    - Unverified: "Claim {ClaimNum}"
 *    - Payment Matching: "Proc {ProcNum}"
 *    - Carrier Analysis: "Carrier {CarrierNum} - {CarrierName}"
 *
 * 3-10. Metric1-8 (VARCHAR): Section-specific metrics
 *    Active Insurance Plan section:
 *    - Metric1: PatNum
 *    - Metric2: PlanNum
 *    - Metric3: CarrierNum
 *    - Metric4: DateEffective (when insurance coverage begins)
 *    - Metric5: DateTerm (when ins coverage ends '0001-01-01' means open-ended)
 *    - Metric6: plan_status - Indicates if claim date falls within valid insurance coverage:
 *        'Valid': When ALL of these are true:
 *          - DateService >= DateEffective
 *          - DateService <= DateTerm (or plan is open-ended)
 *          - For open-ended plans (DateTerm = '0001-01-01'), treated as valid through '9999-12-31'
 *        'Invalid': When ANY of these are true:
 *          - DateService < DateEffective
 *          - DateService > DateTerm (for plans with specific end dates)
 *          - DateService outside the plan's effective coverage period
 *    - Metric7: NULL
 *    - Metric8: NULL
 *
 *    Unverified Insurance section:
 *    - Metric1: PatNum
 *    - Metric2: DateLastVerified
 *    - Metric3: days_since_verification
 *    - Metric4: verification_status
 *    - Metric5-8: NULL
 *
 *    Claim Payment Matching section:
 *    - Metric1: ClaimNum
 *    - Metric2: InsPayAmt (amount paid by insurance)
 *    - Metric3: ProcFee (Original proc fee from procedurelog)
 *    - Metric4: DedApplied (deductible applied to the claim)
 *    - Metric5: WriteOff (write-off amount)
 *    - Metric6: total_accounted (sum of InsPayAmt, DedApplied, WriteOff)
 *    - Metric7: unaccounted_amount (difference between ProcFee and total_accounted)
 *    - Metric8: payment_status (Underpaid, Balanced, Overpaid)
 *
 *    Plan and Carrier Analysis section:
 *    - Metric1: active_plans (number of active plans)
 *    - Metric2: total_claims (total claims processed by the carrier)
 *    - Metric3: unique_patients 
 *    - Metric4: avg_days_to_payment
 *    - Metric5: total_payments
 *    - Metric6: total_writeoffs
 *    - Metric7: total_deductibles
 *    - Metric8: unverified_claims (number of claims that have not been verified)
 *
 * Expected Validation Ranges:
 * - days_since_verification: 0-365 (normal), >365 (flag)
 * - unaccounted_amount: Should be 0 (balanced)
 * - avg_days_to_payment: 0-90 (normal), >90 (flag)
 *
 * Sort Order:
 * - Primary: OutputSection
 * - Secondary: GroupLabel
 *
 * Example Output Row:
 * "Active Insurance Plan","Claim 12345 (Valid)","1001","2001","3001","2024-01-01","2024-12-31","Valid","",""
 */

/*
 * Insurance Claim Processing and Payments Validation
 * 
 * Date Handling:
 * - 0001-01-01: Valid placeholder date, indicates:
 *   * No termination date set (DateTerm)
 *   * Open-ended coverage
 *   * Default date when not specified
 * 
 * Date Validation Rules:
 * - DateEffective: 
 *   * Can be any valid date
 *   * Should be <= DateService for valid claims
 *   * 0001-01-01 might indicate data entry issue
 * 
 * - DateTerm:
 *   * Can be 0001-01-01 (open-ended/no termination)
 *   * Should be >= DateEffective if set
 *   * Future dates are valid
 * 
 * - DateService:
 *   * Must be real date (not 0001-01-01)
 *   * Must be within 2024 for this analysis
 *   * Used as reference point for validation
 */

WITH 
  ActiveClaims AS (
    SELECT 
      c.ClaimNum,
      p.PatNum,
      i.PlanNum,
      i.CarrierNum,
      s.DateEffective,
      s.DateTerm,
      c.DateService,
      CASE 
        WHEN c.DateService BETWEEN s.DateEffective 
          AND CASE 
            WHEN s.DateTerm = '0001-01-01' THEN '9999-12-31'  -- Handle open-ended
            ELSE s.DateTerm 
          END THEN 'Valid'
        ELSE 'Invalid'
      END AS plan_status
    FROM claim c
    JOIN patient p ON c.PatNum = p.PatNum
    JOIN inssub s ON c.PlanNum = s.PlanNum
    JOIN insplan i ON s.PlanNum = i.PlanNum
    WHERE c.DateService >= '2024-01-01'
      AND c.DateService < '2025-01-01'
    GROUP BY 
      c.ClaimNum,
      p.PatNum,
      i.PlanNum,
      i.CarrierNum,
      s.DateEffective,
      s.DateTerm,
      c.DateService,
      plan_status
  ),
  UnverifiedClaims AS (
    SELECT 
      c.ClaimNum,
      p.PatNum,
      iv.DateLastVerified,
      DATEDIFF(c.DateService, iv.DateLastVerified) AS days_since_verification,
      CASE 
        WHEN iv.DateLastVerified IS NULL THEN 'Never Verified'
        WHEN DATEDIFF(c.DateService, iv.DateLastVerified) > 365 THEN 'Outdated'
        ELSE 'Current'
      END AS verification_status
    FROM claim c
    JOIN patient p ON c.PatNum = p.PatNum
    LEFT JOIN insverify iv ON iv.FKey = p.PatNum
    WHERE c.DateService >= '2024-01-01'
      AND c.DateService < '2025-01-01'
  ),
  ClaimPaymentMatching AS (
    SELECT 
      pl.ProcNum,
      c.ClaimNum,
      cp.InsPayAmt,
      pl.ProcFee,
      cp.DedApplied,
      cp.WriteOff,
      (cp.InsPayAmt + cp.DedApplied + cp.WriteOff) AS total_accounted,
      (pl.ProcFee - (cp.InsPayAmt + cp.DedApplied + cp.WriteOff)) AS unaccounted_amount,
      CASE 
        WHEN cp.InsPayAmt + cp.DedApplied + cp.WriteOff = pl.ProcFee THEN 'Balanced'
        WHEN cp.InsPayAmt + cp.DedApplied + cp.WriteOff > pl.ProcFee THEN 'Overpaid'
        ELSE 'Underpaid'
      END AS payment_status
    FROM procedurelog pl
    JOIN claimproc cp ON pl.ProcNum = cp.ProcNum
    JOIN claim c ON cp.ClaimNum = c.ClaimNum
    WHERE c.DateService >= '2024-01-01'
      AND c.DateService < '2025-01-01'
  ),
  PlanCarrierAnalysis AS (
    SELECT 
      c.CarrierNum,
      c.CarrierName,
      COUNT(DISTINCT i.PlanNum) AS active_plans,
      COUNT(DISTINCT cl.ClaimNum) AS total_claims,
      COUNT(DISTINCT p.PatNum) AS unique_patients,
      AVG(DATEDIFF(cp.DateCP, cl.DateService)) AS avg_days_to_payment,
      SUM(cp.InsPayAmt) AS total_payments,
      SUM(cp.WriteOff) AS total_writeoffs,
      SUM(cp.DedApplied) AS total_deductibles,
      COUNT(CASE WHEN iv.DateLastVerified IS NULL THEN 1 END) AS unverified_claims
    FROM carrier c
    LEFT JOIN insplan i ON c.CarrierNum = i.CarrierNum
    LEFT JOIN inssub s ON i.PlanNum = s.PlanNum
    LEFT JOIN claim cl ON s.PlanNum = cl.PlanNum
    LEFT JOIN claimproc cp ON cl.ClaimNum = cp.ClaimNum
    LEFT JOIN patient p ON cl.PatNum = p.PatNum
    LEFT JOIN insverify iv ON iv.FKey = p.PatNum
    WHERE cl.DateService >= '2024-01-01'
      AND cl.DateService < '2025-01-01'
    GROUP BY c.CarrierNum, c.CarrierName
  )
SELECT 
  'Active Insurance Plan' AS OutputSection,
  CONCAT('Claim ', ClaimNum, ' (', plan_status, ')') AS GroupLabel,
  CAST(PatNum AS CHAR) AS Metric1,
  CAST(PlanNum AS CHAR) AS Metric2,
  CAST(CarrierNum AS CHAR) AS Metric3,
  CAST(DateEffective AS CHAR) AS Metric4,
  CAST(DateTerm AS CHAR) AS Metric5,
  plan_status AS Metric6,
  NULL AS Metric7,
  NULL AS Metric8
FROM ActiveClaims

UNION ALL

SELECT 
  'Unverified Insurance Info' AS OutputSection,
  CONCAT('Claim ', ClaimNum) AS GroupLabel,
  CAST(PatNum AS CHAR) AS Metric1,
  CAST(DateLastVerified AS CHAR) AS Metric2,
  CAST(days_since_verification AS CHAR) AS Metric3,
  verification_status AS Metric4,
  NULL AS Metric5,
  NULL AS Metric6,
  NULL AS Metric7,
  NULL AS Metric8
FROM UnverifiedClaims

UNION ALL

SELECT 
  'Claim Payment Matching' AS OutputSection,
  CONCAT('Proc ', CAST(ProcNum AS CHAR)) AS GroupLabel,
  CAST(ClaimNum AS CHAR) AS Metric1,
  CAST(InsPayAmt AS CHAR) AS Metric2,
  CAST(ProcFee AS CHAR) AS Metric3,
  CAST(DedApplied AS CHAR) AS Metric4,
  CAST(WriteOff AS CHAR) AS Metric5,
  CAST(total_accounted AS CHAR) AS Metric6,
  CAST(unaccounted_amount AS CHAR) AS Metric7,
  payment_status AS Metric8
FROM ClaimPaymentMatching

UNION ALL

SELECT 
  'Plan and Carrier Analysis' AS OutputSection,
  CONCAT('Carrier ', CAST(CarrierNum AS CHAR), ' - ', CarrierName) AS GroupLabel,
  CAST(active_plans AS CHAR) AS Metric1,
  CAST(total_claims AS CHAR) AS Metric2,
  CAST(unique_patients AS CHAR) AS Metric3,
  CAST(avg_days_to_payment AS CHAR) AS Metric4,
  CAST(total_payments AS CHAR) AS Metric5,
  CAST(total_writeoffs AS CHAR) AS Metric6,
  CAST(total_deductibles AS CHAR) AS Metric7,
  CAST(unverified_claims AS CHAR) AS Metric8
FROM PlanCarrierAnalysis
ORDER BY OutputSection, GroupLabel;
