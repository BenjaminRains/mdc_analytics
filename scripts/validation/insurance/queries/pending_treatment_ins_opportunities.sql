-- Description: This query retrieves all treatment plans that are pending and have insurance information.
-- It includes details about the treatment plan, patient, procedure, and insurance information.
-- date range: 2024-01-01 to 2024-12-31
-- dependent CTEs: date_range.sql

SELECT 
    -- Treatment Plan Info
    tp.TreatPlanNum,
    tp.DateTP,
    tp.Heading as treatment_plan_heading,
    tp.TPStatus,
    
    -- Patient Info
    p.PatNum,
    p.LName,
    p.FName,
    p.Preferred,
    p.PatStatus,
    p.EstBalance,
    p.BalTotal,
    p.InsEst,
    
    -- Treatment Planned Procedure Info
    ptp.ProcTPNum,
    ptp.ItemOrder,
    ptp.Priority as treatment_priority,
    ptp.ProcCode,
    ptp.Descript as procedure_description,
    ptp.FeeAmt as procedure_fee,
    ptp.PriInsAmt as primary_insurance_est,
    ptp.SecInsAmt as secondary_insurance_est,
    ptp.PatAmt as patient_portion_est,
    ptp.Discount,
    ptp.DateTP as proc_treatment_date,
    ptp.Prognosis,
    
    -- Insurance Info
    c.CarrierNum,
    c.CarrierName,
    ip.GroupName,
    ip.GroupNum,
    ip.PlanType,
    ip.IsMedical,
    ins.SubscriberID,
    ins.DateEffective as insurance_effective_date,
    ins.DateTerm as insurance_term_date,
    pp.Ordinal as insurance_ordinal,
    pp.Relationship as insurance_relationship

FROM treatplan tp
JOIN patient p ON tp.PatNum = p.PatNum
JOIN proctp ptp ON tp.TreatPlanNum = ptp.TreatPlanNum
-- Insurance joins
LEFT JOIN patplan pp ON p.PatNum = pp.PatNum 
    AND pp.Ordinal = 1  -- Primary insurance
LEFT JOIN inssub ins ON pp.InsSubNum = ins.InsSubNum
LEFT JOIN insplan ip ON ins.PlanNum = ip.PlanNum
LEFT JOIN carrier c ON ip.CarrierNum = c.CarrierNum

WHERE tp.TPStatus = 0  -- Changed to 0 for active treatment plans
    AND p.PatStatus = 0  -- Active patients only
    AND ptp.FeeAmt > 0  -- Only procedures with fees
    -- Only include current insurance (not termed)
    AND (ins.DateTerm = '0001-01-01' OR ins.DateTerm > CURRENT_DATE())
    AND (ins.DateEffective = '0001-01-01' OR ins.DateEffective <= CURRENT_DATE())
    -- Add date range filter for recent treatment plans
    AND tp.DateTP >= '2024-01-01'  -- Only look at recent treatment plans
ORDER BY 
    tp.DateTP DESC,
    p.PatNum,
    tp.TreatPlanNum,
    ptp.ItemOrder;