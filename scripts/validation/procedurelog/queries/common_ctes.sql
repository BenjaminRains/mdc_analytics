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
)

-- End of CTEs
-- Note: Your main query should follow this comment
-- Example usage:
-- SELECT * FROM BaseProcedures bp
-- JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
-- WHERE bp.ProcStatus = 2
