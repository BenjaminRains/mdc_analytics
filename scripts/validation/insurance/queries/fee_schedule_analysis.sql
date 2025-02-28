/*
 * Fee Schedule Analysis
 *
 * Purpose: Analyze fee schedule effectiveness, payment patterns, and variations across carriers
 *
 * Output columns:
 * - FeeSchedDesc: Fee schedule description
 * - CarrierName: Insurance carrier name
 * - ProcedureCount: Number of procedures using this fee schedule
 * - AvgPaymentRatio: Average payment to fee ratio
 * - FeeScheduleAdherence: How closely payments match fee schedule
 * - WriteOffPatterns: Analysis of write-off patterns
 * - BlueBookComparison: Comparison with BlueBook rates
 *
 * Analysis Categories:
 * - Fee Schedule Usage: How frequently each schedule is used
 * - Payment Patterns: How payments align with scheduled fees
 * - Carrier Variations: How different carriers handle the same fee schedule
 * - BlueBook Alignment: How fee schedules align with BlueBook rates
 */

-- Dependent CTEs: insurance_fee_schedules.sql, procedure_payment_journey.sql

WITH InsuranceFeeSchedules, ProcedurePaymentJourney

SELECT 
    ifs.FeeSchedDesc,
    ifs.FeeSchedGroupDesc,
    c.CarrierName,
    
    -- Usage Metrics
    COUNT(DISTINCT ppj.ProcNum) as ProcedureCount,
    COUNT(DISTINCT ppj.ClaimNum) as ClaimCount,
    COUNT(DISTINCT ppj.PlanNum) as PlanCount,
    
    -- Fee Analysis
    AVG(ifs.FeeAmount) as AvgScheduledFee,
    AVG(ppj.ProcFee) as AvgBilledAmount,
    AVG(ppj.InsPayAmt) as AvgPaidAmount,
    
    -- Payment Patterns
    AVG(CASE 
        WHEN ppj.payment_status = 'Paid' 
        THEN ppj.InsPayAmt / NULLIF(ppj.ProcFee, 0) 
        END) as AvgPaymentRatio,
    
    -- Fee Schedule Adherence
    AVG(CASE 
        WHEN ifs.FeeAmount > 0 AND ppj.payment_status = 'Paid'
        THEN ABS(ppj.InsPayAmt - ifs.FeeAmount) / ifs.FeeAmount 
        END) as FeeScheduleVariance,
    
    -- Write-off Analysis
    SUM(ppj.WriteOff) as TotalWriteoffs,
    AVG(CASE 
        WHEN ppj.payment_status = 'Paid' 
        THEN ppj.WriteOff / NULLIF(ppj.ProcFee, 0) 
        END) as AvgWriteOffRatio,
    
    -- BlueBook Comparison
    COUNT(DISTINCT CASE 
        WHEN ppj.BlueBookPayAmt IS NOT NULL 
        THEN ppj.ProcNum 
        END) as BlueBookProcedures,
    AVG(CASE 
        WHEN ppj.BlueBookPayAmt IS NOT NULL AND ppj.payment_status = 'Paid'
        THEN ppj.BlueBookPayAmt / NULLIF(ifs.FeeAmount, 0) 
        END) as BlueBookToFeeRatio,
    
    -- Procedure Code Analysis
    STRING_AGG(
        DISTINCT CONCAT(
            t.CodeNum, ':', 
            CAST(t.proc_count AS VARCHAR), ':',
            CAST(ROUND(t.avg_pay_ratio * 100, 1) AS VARCHAR), '%'
        ),
        ', '
    ) as TopProceduresWithPayRatio
FROM InsuranceFeeSchedules ifs
JOIN carrier c ON ifs.CarrierNum = c.CarrierNum
LEFT JOIN ProcedurePaymentJourney ppj ON ifs.PlanNum = ppj.PlanNum
    AND ifs.CodeNum = ppj.CodeNum
CROSS APPLY (
    SELECT TOP 5 
        ppj2.CodeNum,
        COUNT(*) as proc_count,
        AVG(CASE 
            WHEN ppj2.payment_status = 'Paid' 
            THEN ppj2.InsPayAmt / NULLIF(ppj2.ProcFee, 0) 
            END) as avg_pay_ratio
    FROM ProcedurePaymentJourney ppj2
    WHERE ppj2.PlanNum = ifs.PlanNum
        AND ppj2.CodeNum = ifs.CodeNum
    GROUP BY ppj2.CodeNum
    ORDER BY COUNT(*) DESC
) t
WHERE NOT c.IsHidden
GROUP BY 
    ifs.FeeSchedDesc,
    ifs.FeeSchedGroupDesc,
    c.CarrierName
HAVING COUNT(DISTINCT ppj.ProcNum) > 0
ORDER BY 
    ifs.FeeSchedDesc,
    ProcedureCount DESC; 