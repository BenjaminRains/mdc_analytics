-- ============================================================================
-- PROCEDURE LOG VALIDATION - COMMON CTEs
-- ============================================================================
-- This file contains reusable Common Table Expressions (CTEs) for all 
-- Procedure Log validation queries. These CTEs provide consistent filtering,
-- data preparation, and business rule application across all validation scripts.
--
-- CTE INDEX:
-- ----------
-- 1. ExcludedCodes - Defines procedure codes exempt from payment validation
-- 2. BaseProcedures - Filtered procedure set within date range with key attributes
-- 3. PaymentActivity - Aggregates insurance and direct payments by procedure
-- 4. SuccessCriteria - Evaluates business success criteria for each procedure
-- 5. AppointmentDetails - Provides appointment information within date range
-- 6. ProcedureAppointmentSummary - Combines procedures with appointments and payments
-- 7. AppointmentStatusCategories - Standardizes appointment status code translations
-- 8. ProcedureMetrics - Calculates key metrics about procedures (counts, status, fees, payments)
-- 9. ProcedurePairs - Identifies pairs of procedures performed on the same patient on the same day
-- 10. CommonPairs - Counts the most frequent procedure pairs and their fees
-- 11. VisitCounts - Identifies patient visits with multiple procedures
-- 12. BundledPayments - Calculates payment data for visits with multiple procedures
-- 13. EdgeCases - Identifies payment anomalies and edge cases in procedure billing
-- 14. StandardFees - Compares procedure fees to standard fee schedules
-- 15. ProcedureAdjustments - Aggregates adjustment information for procedures
-- 16. PatientResponsibility - Calculates patient responsibility after payments and adjustments
-- 17. FeeRanges - Categorizes procedures by fee amounts for analysis
-- 18. UnpaidCompleted - Identifies completed procedures with no payments
-- 19. PaymentRatios - Categorizes procedures by payment percentage rates
-- 
-- USAGE:
-- ------
-- Import this file using your SQL client's include mechanism, or copy the CTEs
-- directly into validation queries. Replace {{START_DATE}} and {{END_DATE}}
-- with your target date range.
-- ============================================================================

WITH 
-- 1. EXCLUDED CODES
-- Defines procedure codes that are exempt from standard payment validation rules
-- These are typically administrative, diagnostic, or courtesy service codes
ExcludedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
      '~GRP~', 'D9987', 'D9986', 'Watch', 'Ztoth', 'D0350',
      '00040', 'D2919', '00051',
      'D9992', 'D9995', 'D9996',
      'D0190', 'D0171', 'D0140', 'D9430', 'D0120'
    )
),

-- 2. BASE PROCEDURES
-- Core procedure dataset filtered by date range with key attributes
-- Joins to procedure codes and flags excluded codes for special handling
BaseProcedures AS (
    SELECT 
        pl.ProcNum,
        pl.PatNum,
        pl.ProvNum,
        pl.ProcDate,
        pl.ProcStatus,
        pl.ProcFee,
        pl.CodeNum,
        pl.AptNum,
        pl.DateComplete,
        pc.ProcCode,
        pc.Descript,
        CASE WHEN ec.CodeNum IS NOT NULL THEN 'Excluded' ELSE 'Standard' END AS CodeCategory
    FROM procedurelog pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    LEFT JOIN ExcludedCodes ec ON pl.CodeNum = ec.CodeNum
    WHERE pl.ProcDate >= '{{START_DATE}}' AND pl.ProcDate < '{{END_DATE}}'
),

-- 3. PAYMENT ACTIVITY
-- Aggregates payment information from insurance and direct patient payments
-- Calculates total payments and payment ratio (percentage of fee paid)
PaymentActivity AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(SUM(cp.InsPayAmt), 0) AS insurance_paid,
        COALESCE(SUM(ps.SplitAmt), 0) AS direct_paid,
        COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) AS total_paid,
        CASE 
            WHEN pl.ProcFee > 0 THEN 
                (COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0)) / pl.ProcFee 
            ELSE NULL 
        END AS payment_ratio
    FROM BaseProcedures pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    GROUP BY pl.ProcNum, pl.ProcFee
),

-- 4. SUCCESS CRITERIA
-- Evaluates business success criteria based on procedure status, fee, and payment
-- A procedure is considered successful if:
-- 1. It's completed with zero fee (for standard procedures), OR
-- 2. It's completed with fee and has received at least 95% payment
SuccessCriteria AS (
    SELECT
        bp.ProcNum,
        bp.ProcStatus,
        bp.ProcFee,
        bp.CodeCategory,
        pa.total_paid,
        pa.payment_ratio,
        CASE
            -- Case 1: Completed procedure with zero fee (not excluded)
            WHEN bp.ProcStatus = 2 AND bp.ProcFee = 0 AND bp.CodeCategory = 'Standard' THEN TRUE
            -- Case 2: Completed procedure with fee >= 95% paid
            WHEN bp.ProcStatus = 2 AND bp.ProcFee > 0 AND pa.payment_ratio >= 0.95 THEN TRUE
            -- All other cases are not successful
            ELSE FALSE
        END AS is_successful
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
),

-- 5. APPOINTMENT DETAILS
-- Provides appointment information within the date range
-- Used to analyze relationships between procedures and appointments
AppointmentDetails AS (
    SELECT
        a.AptNum,
        a.AptDateTime,
        a.AptStatus
    FROM appointment a
    WHERE a.AptDateTime >= '{{START_DATE}}' AND a.AptDateTime < '{{END_DATE}}'
),

-- 6. PROCEDURE APPOINTMENT SUMMARY
-- Combines procedures with appointment and payment information
-- This CTE is used in appointment overlap analysis and other relationship queries
ProcedureAppointmentSummary AS (
    SELECT
        bp.*,
        pa.total_paid,
        pa.payment_ratio,
        pa.insurance_paid,
        pa.direct_paid,
        ad.AptDateTime,
        ad.AptStatus,
        CASE
            WHEN bp.AptNum IS NULL THEN 'No Appointment'
            WHEN ad.AptStatus = 1 THEN 'Scheduled'
            WHEN ad.AptStatus = 2 THEN 'Complete'
            WHEN ad.AptStatus = 3 THEN 'UnschedList'
            WHEN ad.AptStatus = 4 THEN 'ASAP'
            WHEN ad.AptStatus = 5 THEN 'Broken'
            WHEN ad.AptStatus = 6 THEN 'Planned'
            WHEN ad.AptStatus = 7 THEN 'PtNote'
            WHEN ad.AptStatus = 8 THEN 'PtNoteCompleted'
            ELSE 'Unknown'
        END AS appointment_status
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    LEFT JOIN AppointmentDetails ad ON bp.AptNum = ad.AptNum
),

-- 7. APPOINTMENT STATUS CATEGORIES
-- Standardizes the mapping of appointment status codes to text descriptions
-- Used by multiple queries that need to categorize appointments
AppointmentStatusCategories AS (
    SELECT 
        0 AS AptStatus, 'Unknown' AS StatusDescription
    UNION SELECT 
        1, 'Scheduled'
    UNION SELECT 
        2, 'Complete'
    UNION SELECT 
        3, 'UnschedList'
    UNION SELECT 
        4, 'ASAP'
    UNION SELECT 
        5, 'Broken'
    UNION SELECT 
        6, 'Planned'
    UNION SELECT 
        7, 'PtNote'
    UNION SELECT 
        8, 'PtNoteCompleted'
),

-- 8. PROCEDURE METRICS
-- Calculates key metrics about procedures, including counts, status distribution, 
-- fee statistics, and payment patterns
-- This CTE is useful for dashboards and summary reports
ProcedureMetrics AS (
    SELECT
        -- Basic counts
        COUNT(*) AS total_procedures,
        COUNT(DISTINCT PatNum) AS unique_patients,
        COUNT(DISTINCT ProcCode) AS unique_procedure_codes,
        COUNT(DISTINCT AptNum) AS unique_appointments,
        ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT PatNum), 2) AS procedures_per_patient,
        
        -- Status counts and percentages
        SUM(CASE WHEN ProcStatus = 1 THEN 1 ELSE 0 END) AS treatment_planned,
        SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed,
        SUM(CASE WHEN ProcStatus = 3 THEN 1 ELSE 0 END) AS existing_current,
        SUM(CASE WHEN ProcStatus = 4 THEN 1 ELSE 0 END) AS existing_other,
        SUM(CASE WHEN ProcStatus = 5 THEN 1 ELSE 0 END) AS referred,
        SUM(CASE WHEN ProcStatus = 6 THEN 1 ELSE 0 END) AS deleted,
        SUM(CASE WHEN ProcStatus = 7 THEN 1 ELSE 0 END) AS condition_status,
        SUM(CASE WHEN ProcStatus = 8 THEN 1 ELSE 0 END) AS invalid,
        
        -- Completion rate
        ROUND(100.0 * SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) / 
              NULLIF(SUM(CASE WHEN ProcStatus IN (1,2) THEN 1 ELSE 0 END), 0), 2) AS completion_rate,
        
        -- Fee statistics
        SUM(CASE WHEN ProcFee = 0 THEN 1 ELSE 0 END) AS zero_fee_count,
        SUM(CASE WHEN ProcFee > 0 THEN 1 ELSE 0 END) AS with_fee_count,
        MIN(CASE WHEN ProcFee > 0 THEN ProcFee END) AS min_fee,
        MAX(ProcFee) AS max_fee,
        ROUND(AVG(CASE WHEN ProcFee > 0 THEN ProcFee END), 2) AS avg_fee,
        SUM(ProcFee) AS total_fees,
        
        -- Payment statistics
        COUNT(DISTINCT CASE WHEN total_paid > 0 THEN ProcNum END) AS procedures_with_payment,
        ROUND(COUNT(DISTINCT CASE WHEN total_paid > 0 THEN ProcNum END) * 100.0 / 
              NULLIF(COUNT(*), 0), 2) AS payment_rate,
        SUM(total_paid) AS total_payments,
        ROUND(SUM(total_paid) * 100.0 / NULLIF(SUM(ProcFee), 0), 2) AS overall_payment_percentage,
        SUM(CASE WHEN ProcStatus = 2 THEN total_paid ELSE 0 END) AS completed_payments,
        ROUND(SUM(CASE WHEN ProcStatus = 2 THEN total_paid ELSE 0 END) * 100.0 / 
              NULLIF(SUM(CASE WHEN ProcStatus = 2 THEN ProcFee ELSE 0 END), 0), 2) AS completed_payment_percentage
    FROM (
        SELECT bp.*, pa.total_paid
        FROM BaseProcedures bp
        LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    ) AS combined_data
),

-- 9. PROCEDURE PAIRS
-- Identifies pairs of procedures performed on the same patient on the same day
-- Used for bundling analysis and procedure relationship studies
ProcedurePairs AS (
    SELECT 
        p1.PatNum,
        p1.ProcDate,
        p1.ProcNum AS proc1_num,
        p2.ProcNum AS proc2_num,
        p1.CodeNum AS code1_num,
        p2.CodeNum AS code2_num,
        pc1.ProcCode AS proc1_code,
        pc2.ProcCode AS proc2_code,
        pc1.Descript AS proc1_desc,
        pc2.Descript AS proc2_desc,
        p1.ProcFee AS proc1_fee,
        p2.ProcFee AS proc2_fee,
        p1.ProcStatus AS proc1_status,
        p2.ProcStatus AS proc2_status
    FROM BaseProcedures p1
    JOIN BaseProcedures p2 ON 
        p1.PatNum = p2.PatNum AND 
        p1.ProcDate = p2.ProcDate AND
        p1.ProcNum < p2.ProcNum  -- Avoid duplicates
    JOIN procedurecode pc1 ON p1.CodeNum = pc1.CodeNum
    JOIN procedurecode pc2 ON p2.CodeNum = pc2.CodeNum
    WHERE 
        p1.CodeCategory = 'Standard' AND  -- Exclude special codes
        p2.CodeCategory = 'Standard'
),

-- 10. COMMON PAIRS
-- Counts the most frequent procedure pairs and their associated fees
-- Used to identify common procedure bundling patterns
CommonPairs AS (
    SELECT 
        proc1_code,
        proc2_code,
        proc1_desc,
        proc2_desc,
        COUNT(*) AS pair_count,
        SUM(proc1_fee + proc2_fee) AS total_pair_fee,
        ROUND(AVG(proc1_fee + proc2_fee), 2) AS avg_pair_fee
    FROM ProcedurePairs
    GROUP BY proc1_code, proc2_code, proc1_desc, proc2_desc
),

-- 11. VISIT COUNTS
-- Identifies patient visits with multiple procedures
-- Used to analyze procedure bundling by visit
VisitCounts AS (
    SELECT
        PatNum,
        ProcDate,
        COUNT(*) AS procedures_in_visit
    FROM BaseProcedures
    WHERE 
        ProcStatus = 2 AND  -- Completed procedures
        CodeCategory = 'Standard'  -- Standard codes
    GROUP BY PatNum, ProcDate
),

-- 12. BUNDLED PAYMENTS
-- Calculates payment data for visits with multiple procedures
-- Used to analyze payment patterns based on bundle size
BundledPayments AS (
    SELECT
        v.PatNum,
        v.ProcDate,
        v.procedures_in_visit,
        COUNT(DISTINCT pl.ProcNum) AS procedure_count,
        SUM(pl.ProcFee) AS total_fee,
        SUM(pa.total_paid) AS total_paid,
        CASE WHEN SUM(pl.ProcFee) > 0 
            THEN SUM(pa.total_paid) / SUM(pl.ProcFee) 
            ELSE NULL 
        END AS payment_ratio,
        CASE 
            WHEN v.procedures_in_visit = 1 THEN 'Single Procedure'
            WHEN v.procedures_in_visit BETWEEN 2 AND 3 THEN '2-3 Procedures'
            WHEN v.procedures_in_visit BETWEEN 4 AND 5 THEN '4-5 Procedures'
            ELSE '6+ Procedures'
        END AS bundle_size
    FROM VisitCounts v
    JOIN BaseProcedures pl ON 
        v.PatNum = pl.PatNum AND 
        v.ProcDate = pl.ProcDate AND
        pl.ProcStatus = 2 AND
        pl.CodeCategory = 'Standard'
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    GROUP BY v.PatNum, v.ProcDate, v.procedures_in_visit, bundle_size
),

-- 13. EDGE CASES
-- Identifies payment anomalies and edge cases in procedure billing
-- Used to flag unusual payment patterns that require investigation
EdgeCases AS (
    SELECT 
      pl.ProcNum,
      pl.PatNum,
      pl.ProcDate,
      pl.ProcCode,
      pl.Descript,
      pl.ProcStatus,
      pl.ProcFee,
      COALESCE(pa.total_paid, 0) AS total_paid,
      pa.payment_ratio,
      CASE 
        WHEN pl.ProcFee = 0 AND COALESCE(pa.total_paid, 0) > 0 THEN 'Zero_fee_payment'
        WHEN pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) > pl.ProcFee * 1.05 THEN 'Significant_overpayment'
        WHEN pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) > pl.ProcFee THEN 'Minor_overpayment'
        WHEN pl.ProcStatus = 2 AND pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) = 0 THEN 'Completed_unpaid'
        WHEN pl.ProcStatus = 2 AND pl.ProcFee > 0 AND COALESCE(pa.total_paid, 0) / pl.ProcFee < 0.50 THEN 'Completed_underpaid'
        WHEN pl.ProcStatus != 2 AND COALESCE(pa.total_paid, 0) > 0 THEN 'Non_completed_with_payment'
        ELSE 'Normal'
      END AS edge_case_type
    FROM BaseProcedures pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
),

-- 14. STANDARD FEES
-- Compares procedure fees to standard fee schedules
-- Used to analyze fee variations and adherence to standard pricing
StandardFees AS (
    SELECT 
        bp.ProcNum,
        bp.CodeNum,
        bp.ProcFee AS recorded_fee,
        f.Amount AS standard_fee,
        f.FeeSched,
        fs.Description AS fee_schedule_desc,
        CASE 
            WHEN f.Amount = 0 THEN 'Zero Standard Fee'
            WHEN bp.ProcFee = 0 AND f.Amount > 0 THEN 'Zero Fee Override'
            WHEN bp.ProcFee > f.Amount THEN 'Above Standard'
            WHEN bp.ProcFee < f.Amount THEN 'Below Standard'
            WHEN bp.ProcFee = f.Amount THEN 'Matches Standard'
            ELSE 'Fee Missing'
        END AS fee_relationship
    FROM BaseProcedures bp
    LEFT JOIN fee f ON bp.CodeNum = f.CodeNum 
        AND f.FeeSched = 55  -- Consider making this a parameter
        AND f.ClinicNum = 0
    LEFT JOIN feesched fs ON f.FeeSched = fs.FeeSchedNum
),

-- 15. PROCEDURE ADJUSTMENTS
-- Aggregates adjustment information for procedures
-- Used to analyze write-offs and other fee modifications
ProcedureAdjustments AS (
    SELECT
        bp.ProcNum,
        bp.ProcFee,
        COUNT(a.AdjNum) AS adjustment_count,
        COALESCE(SUM(a.AdjAmt), 0) AS total_adjustments,
        bp.ProcFee + COALESCE(SUM(a.AdjAmt), 0) AS adjusted_fee  -- Adjustments are typically negative
    FROM BaseProcedures bp
    LEFT JOIN adjustment a ON bp.ProcNum = a.ProcNum
    GROUP BY bp.ProcNum, bp.ProcFee
),

-- 16. PATIENT RESPONSIBILITY
-- Calculates patient responsibility after payments and adjustments
-- Used to analyze financial burden on patients
PatientResponsibility AS (
    SELECT
        bp.ProcNum,
        bp.ProcFee,
        pa.total_paid,
        adj.total_adjustments,
        bp.ProcFee - (pa.total_paid + ABS(adj.total_adjustments)) AS patient_responsibility,
        CASE 
            WHEN bp.ProcFee = 0 THEN 'Zero Fee'
            WHEN bp.ProcFee - (pa.total_paid + ABS(adj.total_adjustments)) <= 0 THEN 'Fully Covered'
            WHEN bp.ProcFee - (pa.total_paid + ABS(adj.total_adjustments)) < bp.ProcFee * 0.2 THEN 'Mostly Covered'
            WHEN bp.ProcFee - (pa.total_paid + ABS(adj.total_adjustments)) < bp.ProcFee * 0.5 THEN 'Partially Covered'
            ELSE 'Primarily Patient Responsibility'
        END AS responsibility_category
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    LEFT JOIN ProcedureAdjustments adj ON bp.ProcNum = adj.ProcNum
),

-- 17. FEE RANGES
-- Categorizes procedures by fee amounts for analysis
-- Used to examine pricing patterns and payment behaviors across price points
FeeRanges AS (
    SELECT
        bp.ProcNum,
        bp.ProcFee,
        bp.ProcCode,
        bp.ProcStatus,
        bp.CodeCategory,
        sf.fee_relationship,
        pr.responsibility_category,
        CASE
            WHEN bp.ProcFee = 0 THEN 'Zero Fee'
            WHEN bp.ProcFee < 100 THEN 'Under $100'
            WHEN bp.ProcFee < 250 THEN '$100-$249'
            WHEN bp.ProcFee < 500 THEN '$250-$499'
            WHEN bp.ProcFee < 1000 THEN '$500-$999'
            WHEN bp.ProcFee < 2000 THEN '$1000-$1999'
            ELSE '$2000+'
        END AS fee_range
    FROM BaseProcedures bp
    JOIN StandardFees sf ON bp.ProcNum = sf.ProcNum
    JOIN PatientResponsibility pr ON bp.ProcNum = pr.ProcNum
),

-- 18. UNPAID COMPLETED
-- Identifies completed procedures with no payments
-- Used for accounts receivable and unpaid services analysis
UnpaidCompleted AS (
    SELECT 
        pl.ProcNum,
        pl.PatNum,
        pl.ProcDate,
        EXTRACT(MONTH FROM pl.ProcDate) AS proc_month,
        pl.ProcFee,
        pa.total_paid
    FROM BaseProcedures pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcStatus = 2 -- Completed
      AND pl.ProcFee > 0 -- Has a fee
      AND pl.CodeCategory = 'Standard' -- Not an excluded code
      AND (pa.total_paid IS NULL OR pa.total_paid = 0) -- No payments
),

-- 19. PAYMENT RATIOS
-- Categorizes procedures by payment percentage rates
-- Used for analyzing payment effectiveness and identifying partial payments
PaymentRatios AS (
    SELECT
        pl.ProcNum,
        pl.ProcStatus,
        pl.ProcFee,
        pa.total_paid,
        pa.payment_ratio,
        CASE
            WHEN pl.ProcFee = 0 THEN 'Zero Fee'
            WHEN pa.total_paid IS NULL OR pa.total_paid = 0 THEN 'No Payment'
            WHEN pa.payment_ratio >= 0.98 THEN '98-100%+'
            WHEN pa.payment_ratio >= 0.95 THEN '95-98%'
            WHEN pa.payment_ratio >= 0.90 THEN '90-95%'
            WHEN pa.payment_ratio >= 0.75 THEN '75-90%'
            WHEN pa.payment_ratio >= 0.50 THEN '50-75%'
            WHEN pa.payment_ratio > 0 THEN '1-50%'
            ELSE 'No Payment'
        END AS payment_category
    FROM BaseProcedures pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcStatus = 2  -- Completed procedures only
      AND pl.ProcFee > 0     -- Only procedures with fees
      AND pl.CodeCategory = 'Standard'  -- Exclude exempted codes
)

-- End of CTEs
-- Note: Your main query should follow this comment
-- Example usage:
-- SELECT * FROM BaseProcedures bp
-- JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
-- WHERE bp.ProcStatus = 2
