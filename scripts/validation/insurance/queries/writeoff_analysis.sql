/*
 * Write-off Analysis
 *
 * Purpose: Analyze patterns in insurance write-offs and their impact on revenue
 *
 * Output columns:
 * - CarrierName: Insurance carrier name
 * - WriteOffMetrics: Various write-off related metrics
 * - ProcedureImpact: How write-offs affect different procedures
 * - PatientImpact: Patient-level write-off analysis
 * - TimeBasedTrends: Monthly/quarterly write-off patterns
 *
 * Analysis Categories:
 * - Write-off Patterns: How different carriers handle write-offs
 * - Procedure Impact: Which procedures see the most write-offs
 * - Financial Impact: Overall effect on revenue
 * - Patient Impact: How write-offs affect patient portions
 */

-- Dependent CTEs: procedure_payment_journey.sql, patient_insurance_status.sql, insurance_fee_schedules.sql

WITH ProcedurePaymentJourney, PatientInsuranceStatus, InsuranceFeeSchedules

SELECT 
    c.CarrierName,
    c.ElectID,
    
    -- Volume and Financial Impact
    COUNT(DISTINCT ppj.ProcNum) as TotalProcedures,
    COUNT(DISTINCT ppj.ClaimNum) as TotalClaims,
    SUM(ppj.ProcFee) as TotalBilled,
    SUM(ppj.WriteOff) as TotalWriteoffs,
    SUM(ppj.WriteOff) / NULLIF(SUM(ppj.ProcFee), 0) * 100 as WriteOffPercentage,
    
    -- Write-off Patterns
    AVG(CASE 
        WHEN ppj.payment_status = 'Paid' 
        THEN ppj.WriteOff / NULLIF(ppj.ProcFee, 0) 
        END) * 100 as AvgWriteOffPercent,
    MAX(ppj.WriteOff) as MaxWriteOff,
    COUNT(DISTINCT CASE 
        WHEN ppj.WriteOff > 0 
        THEN ppj.ProcNum 
        END) as ProceduresWithWriteoffs,
        
    -- Fee Schedule Impact
    AVG(CASE 
        WHEN ifs.FeeAmount > 0 AND ppj.WriteOff > 0
        THEN ppj.WriteOff / ifs.FeeAmount 
        END) * 100 as AvgWriteOffToFeeRatio,
    
    -- Patient Impact
    COUNT(DISTINCT pis.PatNum) as PatientsAffected,
    AVG(pis.total_writeoffs) as AvgWriteOffPerPatient,
    MAX(pis.total_writeoffs) as MaxWriteOffPerPatient,
    
    -- Procedure Analysis
    STRING_AGG(
        DISTINCT CONCAT(
            t.CodeNum, ':', 
            CAST(t.proc_count AS VARCHAR), ':$',
            CAST(ROUND(t.avg_writeoff, 2) AS VARCHAR)
        ),
        ', '
    ) as TopProceduresWithWriteoffs,
    
    -- Monthly Trends
    STRING_AGG(
        DISTINCT CONCAT(
            FORMAT(m.proc_month, 'yyyy-MM'), ':$',
            CAST(ROUND(m.monthly_writeoff, 2) AS VARCHAR)
        ),
        ', '
    ) ORDER BY m.proc_month as MonthlyWriteoffTrends
    
FROM carrier c
LEFT JOIN insplan ip ON c.CarrierNum = ip.CarrierNum
LEFT JOIN ProcedurePaymentJourney ppj ON ip.PlanNum = ppj.PlanNum
LEFT JOIN PatientInsuranceStatus pis ON ppj.PatNum = pis.PatNum
LEFT JOIN InsuranceFeeSchedules ifs ON ip.PlanNum = ifs.PlanNum
CROSS APPLY (
    -- Top procedures with write-offs
    SELECT TOP 5 
        ppj2.CodeNum,
        COUNT(*) as proc_count,
        AVG(ppj2.WriteOff) as avg_writeoff
    FROM ProcedurePaymentJourney ppj2
    WHERE ppj2.PlanNum = ip.PlanNum
        AND ppj2.WriteOff > 0
    GROUP BY ppj2.CodeNum
    ORDER BY SUM(ppj2.WriteOff) DESC
) t
CROSS APPLY (
    -- Monthly write-off trends
    SELECT 
        DATEADD(MONTH, DATEDIFF(MONTH, 0, ppj3.ProcDate), 0) as proc_month,
        SUM(ppj3.WriteOff) as monthly_writeoff
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
    TotalWriteoffs DESC,
    CarrierName; 