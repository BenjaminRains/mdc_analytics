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
-- 6. AppointmentStatusCategories - Standardizes appointment status code translations
-- 7. ProcedureAppointmentSummary - Combines procedures with appointments and payments
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
-- 20. PaymentLinks - Calculates payment linkage metrics for procedures
-- 21. LinkagePatterns - Categorizes procedures by payment linkage patterns
-- 22. PaymentSplits - Analyzes how payments are split between insurance and direct payments
-- 23. StatusHistory - Analyzes procedure status and transition patterns
-- 24. TransitionAnalysis - Summarizes procedure status transitions and patterns
-- 25. MonthlyData - Aggregates procedure data by month for temporal analysis
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

-- 5. APPOINTMENT DETAILS
-- Provides appointment information within date range
-- Used for joining procedures to appointments and tracking appointment status
AppointmentDetails AS (
    SELECT
        a.AptNum,
        a.AptDateTime,
        a.AptStatus
    FROM appointment a
    WHERE a.AptDateTime >= '{{START_DATE}}' AND a.AptDateTime < '{{END_DATE}}'
),

-- 6. APPOINTMENT STATUS CATEGORIES
-- Standardizes appointment status code translations
-- Ensures consistent categorization of appointment statuses across reports
AppointmentStatusCategories AS (
    SELECT 
        AptStatus,
        CASE AptStatus
            WHEN 1 THEN 'Scheduled'
            WHEN 2 THEN 'Complete'
            WHEN 3 THEN 'UnschedList'
            WHEN 4 THEN 'ASAP'
            WHEN 5 THEN 'Broken'
            WHEN 6 THEN 'Planned'
            WHEN 7 THEN 'CPHAScheduled'
            WHEN 8 THEN 'PinBoard'
            WHEN 9 THEN 'WebSchedNewPt'
            WHEN 10 THEN 'WebSchedRecall'
            ELSE 'Unknown'
        END AS StatusDescription
    FROM (SELECT DISTINCT AptStatus FROM AppointmentDetails) AS statuses
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

-- 7. PROCEDURE APPOINTMENT SUMMARY
-- Combines procedures with their associated appointments and payments
-- Provides consolidated view of procedure execution and appointment information
ProcedureAppointmentSummary AS (
    SELECT
        bp.ProcNum,
        bp.PatNum,
        bp.ProcDate,
        bp.ProcStatus,
        bp.ProcFee,
        bp.AptNum,
        bp.DateComplete,
        bp.ProcCode,
        bp.Descript,
        bp.CodeCategory,
        pa.total_paid,
        pa.payment_ratio,
        ad.AptDateTime,
        ad.AptStatus,
        sc.is_successful
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    LEFT JOIN AppointmentDetails ad ON bp.AptNum = ad.AptNum
    LEFT JOIN SuccessCriteria sc ON bp.ProcNum = sc.ProcNum
),

-- 8. PROCEDURE METRICS
-- Calculates key metrics about procedures including counts, status, fees, and payments
-- Used for dashboard metrics and summary reports
ProcedureMetrics AS (
    SELECT
        COUNT(*) AS total_procedures,
        SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_procedures,
        SUM(CASE WHEN ProcStatus = 1 THEN 1 ELSE 0 END) AS planned_procedures,
        SUM(CASE WHEN ProcStatus = 6 THEN 1 ELSE 0 END) AS deleted_procedures,
        SUM(CASE WHEN CodeCategory = 'Excluded' THEN 1 ELSE 0 END) AS excluded_procedures,
        SUM(CASE WHEN ProcFee = 0 THEN 1 ELSE 0 END) AS zero_fee_procedures,
        SUM(CASE WHEN ProcFee > 0 THEN 1 ELSE 0 END) AS with_fee_procedures,
        AVG(CASE WHEN ProcStatus = 2 AND ProcFee > 0 THEN payment_ratio ELSE NULL END) AS avg_payment_ratio_completed,
        SUM(CASE WHEN ProcStatus = 2 AND payment_ratio >= 0.95 THEN 1 ELSE 0 END) AS paid_95pct_plus_count,
        SUM(CASE WHEN is_successful THEN 1 ELSE 0 END) AS successful_procedures,
        ROUND(100.0 * SUM(CASE WHEN is_successful THEN 1 ELSE 0 END) / 
               NULLIF(SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END), 0), 2) AS success_rate_pct,
        SUM(ProcFee) AS total_fees,
        SUM(CASE WHEN ProcStatus = 2 THEN ProcFee ELSE 0 END) AS completed_fees,
        SUM(total_paid) AS total_payments,
        ROUND(SUM(total_paid) / NULLIF(SUM(ProcFee), 0) * 100, 2) AS overall_payment_rate_pct
    FROM ProcedureAppointmentSummary
),

-- 9. PROCEDURE PAIRS
-- Identifies pairs of procedures performed on the same patient on the same day
-- Used for analyzing common procedure combinations and bundling patterns
ProcedurePairs AS (
    SELECT 
        p1.PatNum,
        p1.ProcDate,
        p1.ProcNum AS proc1_num,
        p1.ProcCode AS proc1_code,
        p1.ProcFee AS proc1_fee,
        p2.ProcNum AS proc2_num,
        p2.ProcCode AS proc2_code,
        p2.ProcFee AS proc2_fee,
        p1.ProcFee + p2.ProcFee AS combined_fee
    FROM BaseProcedures p1
    JOIN BaseProcedures p2 ON 
        p1.PatNum = p2.PatNum AND 
        p1.ProcDate = p2.ProcDate AND
        p1.ProcNum < p2.ProcNum -- Ensures each pair is counted only once
),

-- 10. COMMON PAIRS
-- Counts the most frequent procedure pairs and their associated fees
-- Used for bundling analysis and procedure combination patterns
CommonPairs AS (
    SELECT 
        proc1_code,
        proc2_code,
        COUNT(*) AS pair_count,
        AVG(proc1_fee) AS avg_proc1_fee,
        AVG(proc2_fee) AS avg_proc2_fee,
        AVG(combined_fee) AS avg_combined_fee
    FROM ProcedurePairs
    GROUP BY proc1_code, proc2_code
),

-- 11. VISIT COUNTS
-- Identifies patient visits with multiple procedures
-- Used for analyzing bundling opportunities and visit optimization
VisitCounts AS (
    SELECT
        PatNum,
        ProcDate,
        COUNT(*) AS procedure_count,
        SUM(ProcFee) AS total_fee
    FROM BaseProcedures
    GROUP BY PatNum, ProcDate
    HAVING COUNT(*) > 1
),

-- 12. BUNDLED PAYMENTS
-- Calculates payment data for visits with multiple procedures
-- Used for analyzing how bundled procedures are billed and paid
BundledPayments AS (
    SELECT
        vc.PatNum,
        vc.ProcDate,
        vc.procedure_count,
        vc.total_fee,
        SUM(pa.total_paid) AS total_paid,
        SUM(pa.total_paid) / NULLIF(vc.total_fee, 0) AS payment_ratio,
        COUNT(CASE WHEN pa.total_paid > 0 THEN 1 END) AS procedures_with_payment,
        COUNT(CASE WHEN pa.total_paid = 0 THEN 1 END) AS procedures_without_payment
    FROM VisitCounts vc
    JOIN BaseProcedures bp ON vc.PatNum = bp.PatNum AND vc.ProcDate = bp.ProcDate
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    GROUP BY vc.PatNum, vc.ProcDate, vc.procedure_count, vc.total_fee
),

-- 13. EDGE CASES
-- Identifies payment anomalies and edge cases in procedure billing
-- Used for exception reporting and data quality analysis
EdgeCases AS (
    SELECT
        bp.ProcNum,
        bp.PatNum,
        bp.ProcCode,
        bp.ProcDate,
        bp.ProcStatus,
        bp.ProcFee,
        pa.total_paid,
        pa.payment_ratio,
        CASE
            WHEN bp.ProcStatus = 2 AND bp.ProcFee = 0 THEN 'Completed zero-fee'
            WHEN bp.ProcStatus = 2 AND bp.ProcFee > 0 AND pa.total_paid = 0 THEN 'Completed unpaid'
            WHEN bp.ProcStatus = 2 AND pa.payment_ratio > 1.05 THEN 'Overpaid'
            WHEN bp.ProcStatus = 2 AND pa.payment_ratio BETWEEN 0.01 AND 0.50 THEN 'Significantly underpaid'
            WHEN bp.ProcStatus = 6 AND pa.total_paid > 0 THEN 'Deleted with payment'
            WHEN bp.ProcStatus = 1 AND pa.total_paid > 0 THEN 'Planned with payment'
            ELSE NULL
        END AS edge_case_type
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    WHERE 
        (bp.ProcStatus = 2 AND bp.ProcFee = 0) OR
        (bp.ProcStatus = 2 AND bp.ProcFee > 0 AND pa.total_paid = 0) OR
        (bp.ProcStatus = 2 AND pa.payment_ratio > 1.05) OR
        (bp.ProcStatus = 2 AND pa.payment_ratio BETWEEN 0.01 AND 0.50) OR
        (bp.ProcStatus = 6 AND pa.total_paid > 0) OR
        (bp.ProcStatus = 1 AND pa.total_paid > 0)
),

-- 14. STANDARD FEES
-- Compares procedure fees to standard fee schedules
-- Used for fee consistency analysis and pricing optimization
StandardFees AS (
    SELECT
        ProcCode,
        COUNT(*) AS procedure_count,
        MIN(ProcFee) AS min_fee,
        MAX(ProcFee) AS max_fee,
        AVG(ProcFee) AS avg_fee,
        STDDEV(ProcFee) AS fee_stddev,
        COUNT(DISTINCT ProcFee) AS unique_fee_count
    FROM BaseProcedures
    WHERE ProcFee > 0
    GROUP BY ProcCode
    HAVING COUNT(*) > 5 -- Only include procedures with significant sample size
),

-- 15. PROCEDURE ADJUSTMENTS
-- Aggregates adjustment information for procedures
-- Used for analyzing write-offs, discounts, and adjustment patterns
ProcedureAdjustments AS (
    SELECT
        bp.ProcNum,
        bp.ProcFee,
        COALESCE(SUM(ca.WriteOff), 0) AS insurance_adjustments,
        COALESCE(SUM(
            CASE WHEN a.AdjType IN (1, 2) -- Positive adjustment types
                THEN a.AdjAmt
                ELSE 0
            END), 0) AS positive_adjustments,
        COALESCE(SUM(
            CASE WHEN a.AdjType IN (3, 4) -- Negative adjustment types
                THEN a.AdjAmt
                ELSE 0
            END), 0) AS negative_adjustments,
        COALESCE(SUM(a.AdjAmt), 0) AS total_direct_adjustments,
        COALESCE(SUM(ca.WriteOff), 0) + COALESCE(SUM(a.AdjAmt), 0) AS total_adjustments
    FROM BaseProcedures bp
    LEFT JOIN claimproc ca ON bp.ProcNum = ca.ProcNum AND ca.WriteOff <> 0
    LEFT JOIN adjustment a ON bp.ProcNum = a.ProcNum
    GROUP BY bp.ProcNum, bp.ProcFee
),

-- 16. PATIENT RESPONSIBILITY
-- Calculates patient responsibility after payments and adjustments
-- Used for analyzing patient financial burden and collection opportunities
PatientResponsibility AS (
    SELECT
        bp.ProcNum,
        bp.PatNum,
        bp.ProcCode,
        bp.ProcStatus,
        bp.ProcFee,
        pa.insurance_paid,
        pa.direct_paid,
        pa.total_paid,
        adj.total_adjustments,
        bp.ProcFee - COALESCE(pa.total_paid, 0) - COALESCE(adj.total_adjustments, 0) AS remaining_responsibility,
        CASE
            WHEN bp.ProcFee = 0 THEN 'Zero Fee'
            WHEN bp.ProcFee - COALESCE(pa.total_paid, 0) - COALESCE(adj.total_adjustments, 0) <= 0 THEN 'Fully Resolved'
            WHEN pa.insurance_paid > 0 AND bp.ProcFee - COALESCE(pa.total_paid, 0) - COALESCE(adj.total_adjustments, 0) > 0 THEN 'Patient Portion Due'
            WHEN pa.insurance_paid = 0 AND pa.direct_paid = 0 AND adj.total_adjustments = 0 THEN 'No Activity'
            ELSE 'Partial Payment'
        END AS responsibility_status
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    LEFT JOIN ProcedureAdjustments adj ON bp.ProcNum = adj.ProcNum
),

-- 17. FEE RANGES
-- Categorizes procedures by fee amounts for analysis
-- Used for financial segmentation and pricing tier analysis
FeeRanges AS (
    SELECT
        ProcNum,
        ProcCode,
        ProcStatus,
        ProcFee,
        CASE
            WHEN ProcFee = 0 THEN 'Zero Fee'
            WHEN ProcFee < 100 THEN 'Under $100'
            WHEN ProcFee >= 100 AND ProcFee < 250 THEN '$100-$249'
            WHEN ProcFee >= 250 AND ProcFee < 500 THEN '$250-$499'
            WHEN ProcFee >= 500 AND ProcFee < 1000 THEN '$500-$999'
            WHEN ProcFee >= 1000 AND ProcFee < 2500 THEN '$1000-$2499'
            WHEN ProcFee >= 2500 THEN '$2500+'
        END AS fee_range
    FROM BaseProcedures
),

-- 18. UNPAID COMPLETED
-- Identifies completed procedures with no payments
-- Used for accounts receivable analysis and collection targeting
UnpaidCompleted AS (
    SELECT
        bp.ProcNum,
        bp.PatNum,
        bp.ProcDate,
        bp.DateComplete,
        bp.ProcStatus,
        bp.ProcCode,
        bp.Descript,
        bp.ProcFee,
        bp.CodeCategory,
        DATEDIFF(CURRENT_DATE, bp.DateComplete) AS days_since_completion
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    WHERE bp.ProcStatus = 2  -- Completed
      AND bp.ProcFee > 0     -- Has a fee
      AND (pa.total_paid IS NULL OR pa.total_paid = 0)  -- No payment
      AND bp.CodeCategory = 'Standard'  -- Not excluded
),

-- 19. PAYMENT RATIOS
-- Categorizes procedures by payment percentage rates
-- Used for analyzing payment effectiveness and partial payment patterns
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
),

-- 20. PAYMENT LINKS
-- Calculates payment linkage metrics for procedures
-- Used for identifying payment tracking issues and linkage patterns
PaymentLinks AS (
    SELECT 
        bp.ProcNum,
        bp.ProcStatus,
        bp.ProcFee,
        bp.ProcDate,
        bp.DateComplete,
        -- Count linked payment splits
        COUNT(DISTINCT ps.SplitNum) AS paysplit_count,
        -- Count linked claim procs with payment
        COUNT(DISTINCT cp.ClaimProcNum) AS claimproc_count,
        -- Payment amounts
        COALESCE(SUM(ps.SplitAmt), 0) AS direct_payment_amount,
        COALESCE(SUM(cp.InsPayAmt), 0) AS insurance_payment_amount,
        -- Insurance estimate amount (expected insurance)
        COALESCE(SUM(cp.InsEstTotal), 0) AS insurance_estimate_amount,
        -- Days from procedure to payment metrics
        MIN(CASE WHEN ps.SplitAmt > 0 THEN 
            DATEDIFF(ps.DatePay, COALESCE(bp.DateComplete, bp.ProcDate))
            END) AS min_direct_days_to_payment,
        MIN(CASE WHEN cp.InsPayAmt > 0 THEN 
            DATEDIFF(cp.DateCP, COALESCE(bp.DateComplete, bp.ProcDate))
            END) AS min_insurance_days_to_payment,
        LEAST(
            COALESCE(MIN(CASE WHEN ps.SplitAmt > 0 THEN 
                DATEDIFF(ps.DatePay, COALESCE(bp.DateComplete, bp.ProcDate))
                END), 999999),
            COALESCE(MIN(CASE WHEN cp.InsPayAmt > 0 THEN 
                DATEDIFF(cp.DateCP, COALESCE(bp.DateComplete, bp.ProcDate))
                END), 999999)
        ) AS min_days_to_payment,
        MAX(CASE WHEN ps.SplitAmt > 0 OR cp.InsPayAmt > 0 THEN 
            GREATEST(
                COALESCE(DATEDIFF(ps.DatePay, COALESCE(bp.DateComplete, bp.ProcDate)), 0),
                COALESCE(DATEDIFF(cp.DateCP, COALESCE(bp.DateComplete, bp.ProcDate)), 0)
            )
            END) AS max_days_to_payment,
        -- Flag for zero insurance payments with claims
        CASE WHEN COUNT(DISTINCT cp.ClaimProcNum) > 0 AND 
                  COALESCE(SUM(cp.InsPayAmt), 0) = 0 
             THEN 1 ELSE 0 END AS has_zero_insurance_payment
    FROM BaseProcedures bp
    LEFT JOIN paysplit ps ON bp.ProcNum = ps.ProcNum
    LEFT JOIN claimproc cp ON bp.ProcNum = cp.ProcNum
    GROUP BY 
        bp.ProcNum, 
        bp.ProcStatus,
        bp.ProcFee,
        bp.ProcDate,
        bp.DateComplete
),

-- 21. LINKAGE PATTERNS
-- Categorizes procedures by payment linkage patterns
-- Used for analyzing payment source distribution and payment status
LinkagePatterns AS (
    SELECT
        ProcNum,
        ProcStatus,
        ProcFee,
        paysplit_count,
        claimproc_count,
        direct_payment_amount,
        insurance_payment_amount,
        insurance_estimate_amount,
        direct_payment_amount + insurance_payment_amount AS total_payment_amount,
        min_days_to_payment,
        max_days_to_payment,
        has_zero_insurance_payment,
        CASE
            WHEN paysplit_count = 0 AND claimproc_count = 0 THEN 'No payment links'
            WHEN paysplit_count > 0 AND claimproc_count = 0 THEN 'Direct payment only'
            WHEN paysplit_count = 0 AND claimproc_count > 0 THEN 'Insurance only'
            ELSE 'Mixed payment sources'
        END AS payment_source_type,
        CASE
            WHEN direct_payment_amount + insurance_payment_amount >= ProcFee * 0.95 THEN 'Fully paid'
            WHEN direct_payment_amount + insurance_payment_amount > 0 THEN 'Partially paid'
            ELSE 'Unpaid'
        END AS payment_status,
        CASE
            WHEN insurance_estimate_amount > 0 AND insurance_payment_amount = 0 THEN 'Expected insurance not received'
            WHEN insurance_estimate_amount > 0 AND insurance_payment_amount < insurance_estimate_amount * 0.9 THEN 'Insurance underpaid'
            WHEN insurance_estimate_amount > 0 AND insurance_payment_amount > insurance_estimate_amount * 1.1 THEN 'Insurance overpaid'
            ELSE 'Normal insurance pattern'
        END AS insurance_pattern
    FROM PaymentLinks
),

-- 22. PAYMENT SPLITS
-- Analyzes how payments are split between insurance and direct payments
-- Used for understanding payment source distribution and insurance vs. patient contribution
PaymentSplits AS (
    SELECT
        pl.ProcNum,
        pl.ProcStatus,
        pl.ProcFee,
        pa.insurance_paid,
        pa.direct_paid,
        pa.total_paid,
        CASE
            WHEN pa.total_paid IS NULL OR pa.total_paid = 0 THEN 'No Payment'
            WHEN pa.insurance_paid > 0 AND pa.direct_paid > 0 THEN 'Split Payment'
            WHEN pa.insurance_paid > 0 THEN 'Insurance Only'
            WHEN pa.direct_paid > 0 THEN 'Direct Payment Only'
            ELSE 'No Payment'
        END AS payment_type,
        CASE
            WHEN pa.total_paid IS NULL OR pa.total_paid = 0 THEN 0
            WHEN pa.total_paid > 0 THEN pa.insurance_paid / pa.total_paid
            ELSE 0
        END AS insurance_ratio
    FROM BaseProcedures pl
    LEFT JOIN PaymentActivity pa ON pl.ProcNum = pa.ProcNum
    WHERE pl.ProcFee > 0  -- Only procedures with fees
),

-- 23. STATUS HISTORY
-- Analyzes procedure status and transition patterns
-- Used for tracking status changes and identifying potential workflow issues
StatusHistory AS (
    SELECT 
        pl.ProcNum,
        pl.ProcStatus,
        pl.ProcDate,
        pl.DateComplete,
        pl.AptNum,
        pl.ProcFee,
        pc.ProcCode,
        pc.Descript,
        CASE pl.ProcStatus
            WHEN 1 THEN 'Treatment Planned'
            WHEN 2 THEN 'Completed'
            WHEN 3 THEN 'Existing Current'
            WHEN 4 THEN 'Existing Other'
            WHEN 5 THEN 'Referred'
            WHEN 6 THEN 'Deleted'
            WHEN 7 THEN 'Condition'
            WHEN 8 THEN 'Invalid'
            ELSE 'Unknown'
        END AS status_description,
        -- Time in current status - FIXED with DATEDIFF for MariaDB compatibility
        CASE 
            WHEN pl.DateComplete IS NOT NULL THEN 
                DATEDIFF(CURRENT_DATE, pl.DateComplete) 
            ELSE 
                DATEDIFF(CURRENT_DATE, pl.ProcDate)
        END AS days_in_status,
        -- Identify expected transition patterns
        CASE
            -- Valid normal transitions
            WHEN pl.ProcStatus = 2 AND pl.DateComplete IS NOT NULL THEN 'Completed with date'
            WHEN pl.ProcStatus = 2 AND pl.DateComplete IS NULL THEN 'Completed missing date'
            WHEN pl.ProcStatus = 1 AND pl.DateComplete IS NULL THEN 'Planned (normal)'
            WHEN pl.ProcStatus = 1 AND pl.DateComplete IS NOT NULL THEN 'Planned with completion date'
            WHEN pl.ProcStatus = 6 AND pl.ProcFee = 0 THEN 'Deleted zero-fee'
            WHEN pl.ProcStatus = 6 AND pl.ProcFee > 0 THEN 'Deleted with fee'
            -- Terminal states
            WHEN pl.ProcStatus IN (3, 4, 5, 7) THEN 'Terminal status'
            ELSE 'Other pattern'
        END AS transition_pattern
    FROM BaseProcedures pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
),

-- 24. TRANSITION ANALYSIS
-- Summarizes procedure status transitions and patterns
-- Used for workflow analysis and identifying potential process improvements
TransitionAnalysis AS (
    SELECT
        status_description,
        transition_pattern,
        COUNT(*) AS procedure_count,
        MIN(days_in_status) AS min_days,
        MAX(days_in_status) AS max_days,
        ROUND(AVG(days_in_status), 1) AS avg_days,
        SUM(ProcFee) AS total_fees,
        COUNT(DISTINCT AptNum) AS appointments_count
    FROM StatusHistory
    GROUP BY status_description, transition_pattern
),

-- 25. MONTHLY DATA
-- Aggregates procedure data by month for temporal analysis
-- Used for tracking trends over time and seasonality patterns
MonthlyData AS (
    SELECT 
        EXTRACT(YEAR FROM pl.ProcDate) AS proc_year,
        EXTRACT(MONTH FROM pl.ProcDate) AS proc_month,
        COUNT(*) AS total_procedures,
        SUM(CASE WHEN pl.ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_procedures,
        SUM(CASE WHEN pl.ProcStatus = 1 THEN 1 ELSE 0 END) AS planned_procedures,
        SUM(CASE WHEN pl.ProcStatus = 6 THEN 1 ELSE 0 END) AS deleted_procedures,
        SUM(pl.ProcFee) AS total_fees,
        SUM(CASE WHEN pl.ProcStatus = 2 THEN pl.ProcFee ELSE 0 END) AS completed_fees,
        SUM(pa.total_paid) AS total_payments,
        SUM(CASE WHEN pl.ProcStatus = 2 THEN pa.total_paid ELSE 0 END) AS completed_payments,
        -- Calculate unpaid metrics
        SUM(CASE WHEN pl.ProcStatus = 2 AND pl.ProcFee >