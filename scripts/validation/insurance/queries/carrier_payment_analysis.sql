/*
 * Carrier Payment Analysis
 *
 * Purpose: Analyze insurance carrier payment patterns, efficiency, and fee schedule adherence
 *
 * Output columns:
 * - CarrierName: Name of the insurance carrier
 * - TotalProcedures: Total procedures submitted to this carrier
 * - TotalPayments: Total amount paid by carrier
 * - AvgPaymentRatio: Average ratio of payment to billed amount
 * - AvgDaysToPayment: Average days from procedure to payment
 * - WriteOffPercent: Percentage of billed amount written off
 * - BlueBookAdherence: Percentage of payments matching BlueBook amounts
 * - FeeScheduleVariance: Average variance from fee schedule
 * - ClaimEfficiency: Percentage of claims paid without rejection
 * - TopProcedureCodes: Most common procedures by carrier
 *
 * Analysis Categories:
 * - Payment Efficiency: How quickly and reliably the carrier pays
 * - Fee Schedule Adherence: How well payments match expected amounts
 * - Claim Processing: Success rate of claim submissions
 * - Financial Impact: Overall financial performance with the carrier
 */

-- Dependent CTEs: insurance_fee_schedules.sql, procedure_payment_journey.sql

WITH InsuranceFeeSchedules, ProcedurePaymentJourney

SELECT 
    c.CarrierName,
    c.ElectID,
    -- Volume Metrics
    COUNT(DISTINCT ppj.ProcNum) as TotalProcedures,
    COUNT(DISTINCT ppj.ClaimNum) as TotalClaims,
    COUNT(DISTINCT CASE WHEN ppj.payment_status = 'Paid' THEN ppj.ClaimNum END) as PaidClaims,
    
    -- Financial Metrics
    SUM(ppj.ProcFee) as TotalBilled,
    SUM(ppj.InsPayAmt) as TotalPayments,
    SUM(ppj.WriteOff) as TotalWriteoffs,
    SUM(ppj.DedApplied) as TotalDeductibles,
    AVG(ppj.InsPayAmt / NULLIF(ppj.ProcFee, 0)) as AvgPaymentRatio,
    
    -- Timing Metrics
    AVG(ppj.days_to_payment) as AvgDaysToPayment,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ppj.days_to_payment) as MedianDaysToPayment,
    
    -- Fee Schedule Analysis
    AVG(CASE 
        WHEN ifs.FeeAmount > 0 
        THEN ABS(ppj.InsPayAmt - ifs.FeeAmount) / ifs.FeeAmount 
        END) as AvgFeeScheduleVariance,
    
    -- BlueBook Analysis
    COUNT(DISTINCT CASE 
        WHEN ppj.BlueBookPayAmt IS NOT NULL 
        THEN ppj.ProcNum 
        END) as BlueBookProcedures,
    AVG(CASE 
        WHEN ppj.BlueBookPayAmt IS NOT NULL 
        THEN ABS(ppj.InsPayAmt - ppj.BlueBookPayAmt) / NULLIF(ppj.BlueBookPayAmt, 0)
        END) as BlueBookVariance,
    
    -- Efficiency Metrics
    COUNT(DISTINCT CASE WHEN ppj.payment_status = 'Rejected' THEN ppj.ClaimNum END) * 100.0 / 
        NULLIF(COUNT(DISTINCT ppj.ClaimNum), 0) as RejectionRate,
    AVG(CASE 
        WHEN ppj.payment_status = 'Paid' 
        THEN ppj.total_insurance_handled / NULLIF(ppj.ProcFee, 0) 
        END) as AvgCoverageRate,
    
    -- Most Common Procedures
    STRING_AGG(
        DISTINCT CONCAT(
            t.CodeNum, ':', CAST(t.proc_count AS VARCHAR)
        ),
        ', '
    ) as TopProcedureCodes
FROM carrier c
LEFT JOIN insplan ip ON c.CarrierNum = ip.CarrierNum
LEFT JOIN ProcedurePaymentJourney ppj ON ip.PlanNum = ppj.PlanNum
LEFT JOIN InsuranceFeeSchedules ifs ON ip.PlanNum = ifs.PlanNum
CROSS APPLY (
    SELECT TOP 5 CodeNum, COUNT(*) as proc_count
    FROM ProcedurePaymentJourney ppj2
    WHERE ppj2.PlanNum = ip.PlanNum
    GROUP BY CodeNum
    ORDER BY COUNT(*) DESC
) t
WHERE NOT c.IsHidden
GROUP BY 
    c.CarrierNum,
    c.CarrierName,
    c.ElectID
HAVING COUNT(DISTINCT ppj.ProcNum) > 0
ORDER BY 
    TotalPayments DESC,
    CarrierName; 