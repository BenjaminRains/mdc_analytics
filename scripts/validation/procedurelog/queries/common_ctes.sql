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
)

-- End of CTEs
-- Note: Your main query should follow this comment
-- Example usage:
-- SELECT * FROM BaseProcedures bp
-- JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
-- WHERE bp.ProcStatus = 2
