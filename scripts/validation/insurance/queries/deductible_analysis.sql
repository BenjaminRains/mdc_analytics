/*
 * Deductible Analysis
 *
 * Purpose: Analyze insurance deductible patterns and their impact on patient responsibility
 *
 * Output columns:
 * - CarrierName: Insurance carrier name
 * - DeductibleMetrics: Various deductible-related metrics
 * - PatientImpact: How deductibles affect patient portions
 * - TimingPatterns: When deductibles are most commonly applied
 * - ProcedurePatterns: Which procedures commonly trigger deductibles
 *
 * Analysis Categories:
 * - Deductible Patterns: How different carriers apply deductibles
 * - Patient Financial Impact: Effect on patient responsibility
 * - Seasonal Trends: When deductibles are most commonly applied
 * - Procedure Impact: Which procedures typically involve deductibles
 */
-- Date range: @start_date to @end_date
-- Dependent CTEs: procedure_payment_journey.sql, patient_insurance_status.sql

WITH ProcedurePaymentJourney, PatientInsuranceStatus

SELECT 
    c.CarrierName,
    c.ElectID,
    
    -- Volume Metrics
    COUNT(DISTINCT ppj.ProcNum) as TotalProcedures,
    COUNT(DISTINCT ppj.ClaimNum) as TotalClaims,
    COUNT(DISTINCT CASE 
        WHEN ppj.DedApplied > 0 
        THEN ppj.ClaimNum 
        END) as ClaimsWithDeductible,
    
    -- Financial Impact
    SUM(ppj.ProcFee) as TotalBilled,
    SUM(ppj.DedApplied) as TotalDeductiblesApplied,
    SUM(ppj.DedApplied) / NULLIF(SUM(ppj.ProcFee), 0) * 100 as DeductiblePercentage,
    
    -- Deductible Patterns
    AVG(CASE 
        WHEN ppj.DedApplied > 0 
        THEN ppj.DedApplied 
        END) as AvgDeductibleWhenApplied,
    MAX(ppj.DedApplied) as MaxDeductibleApplied,
    
    -- Patient Impact
    COUNT(DISTINCT pis.PatNum) as PatientsAffected,
    AVG(pis.total_deductibles) as AvgDeductiblePerPatient,
    MAX(pis.total_deductibles) as MaxDeductiblePerPatient,
    
    -- Payment Analysis
    AVG(CASE 
        WHEN ppj.DedApplied > 0 
        THEN ppj.remaining_patient_portion / ppj.ProcFee 
        END) * 100 as AvgPatientPortionWithDeductible,
    
    -- Seasonal Analysis
    STRING_AGG(
        DISTINCT CONCAT(
            FORMAT(m.proc_month, 'yyyy-MM'), ':$',
            CAST(ROUND(m.monthly_deductible, 2) AS VARCHAR), ':',
            CAST(m.deductible_count AS VARCHAR), ' claims'
        ),
        ', '
    ) ORDER BY m.proc_month as MonthlyDeductibleTrends,
    
    -- Procedure Analysis
    STRING_AGG(
        DISTINCT CONCAT(
            t.CodeNum, ':', 
            CAST(t.proc_count AS VARCHAR), ':$',
            CAST(ROUND(t.avg_deductible, 2) AS VARCHAR), ':',
            CAST(ROUND(t.deductible_frequency * 100, 1) AS VARCHAR), '%'
        ),
        ', '
    ) as TopProceduresWithDeductibles,
    
    -- Early Year vs Late Year
    SUM(CASE 
        WHEN MONTH(ppj.ProcDate) <= 3 
        THEN ppj.DedApplied 
        END) as Q1Deductibles,
    SUM(CASE 
        WHEN MONTH(ppj.ProcDate) > 9 
        THEN ppj.DedApplied 
        END) as Q4Deductibles,
    
    -- Claim Processing Impact
    AVG(CASE 
        WHEN ppj.DedApplied > 0 
        THEN ppj.days_to_payment 
        END) as AvgProcessingDaysWithDeductible,
    AVG(CASE 
        WHEN ppj.DedApplied = 0 
        THEN ppj.days_to_payment 
        END) as AvgProcessingDaysNoDeductible
    
FROM carrier c
LEFT JOIN insplan ip ON c.CarrierNum = ip.CarrierNum
LEFT JOIN ProcedurePaymentJourney ppj ON ip.PlanNum = ppj.PlanNum
LEFT JOIN PatientInsuranceStatus pis ON ppj.PatNum = pis.PatNum
CROSS APPLY (
    -- Top procedures with deductibles
    SELECT TOP 5 
        ppj2.CodeNum,
        COUNT(*) as proc_count,
        AVG(ppj2.DedApplied) as avg_deductible,
        COUNT(CASE WHEN ppj2.DedApplied > 0 THEN 1 END) * 1.0 / COUNT(*) as deductible_frequency
    FROM ProcedurePaymentJourney ppj2
    WHERE ppj2.PlanNum = ip.PlanNum
    GROUP BY ppj2.CodeNum
    HAVING COUNT(CASE WHEN ppj2.DedApplied > 0 THEN 1 END) > 0
    ORDER BY COUNT(CASE WHEN ppj2.DedApplied > 0 THEN 1 END) DESC
) t
CROSS APPLY (
    -- Monthly deductible trends
    SELECT 
        DATEADD(MONTH, DATEDIFF(MONTH, 0, ppj3.ProcDate), 0) as proc_month,
        SUM(ppj3.DedApplied) as monthly_deductible,
        COUNT(DISTINCT CASE WHEN ppj3.DedApplied > 0 THEN ppj3.ClaimNum END) as deductible_count
    FROM ProcedurePaymentJourney ppj3
    WHERE ppj3.PlanNum = ip.PlanNum
    GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, ppj3.ProcDate), 0)
) m
WHERE NOT c.IsHidden
GROUP BY 
    c.CarrierNum,
    c.CarrierName,
    c.ElectID
HAVING COUNT(DISTINCT ppj.ProcNum) > 0
ORDER BY 
    TotalDeductiblesApplied DESC,
    CarrierName; 