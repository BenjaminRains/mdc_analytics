/*
 * Insurance Opportunity Analysis for Out-of-Network Practice
 *
 * Purpose: Extract raw data for pandas analysis of insurance patterns and opportunities
 * 
 * Analysis Questions:
 * 
 * 1. Carrier Performance
 *    - Which carriers have the highest estimated vs. billed fee ratios?
 *    - How do payment estimates vary by carrier for the same procedures?
 *    - Which carriers have the most claims volume?
 *    - Are there carriers with consistently higher write-offs or deductibles?
 * 
 * 2. Procedure Analysis
 *    - What are the most frequent procedures by carrier?
 *    - Which procedures have the highest payment rates?
 *    - How do fee schedules vary across carriers for common procedures?
 *    - Are certain procedures more likely to have high deductibles?
 * 
 * 3. Insurance Plan Insights
 *    - How do payment rates vary by plan type?
 *    - Which group plans have the most favorable payment terms?
 *    - Are there patterns in coverage levels across different plan types?
 *    - Which plans consistently apply higher deductibles?
 * 
 * 4. Patient Coverage Patterns
 *    - What percentage of patients have active insurance coverage?
 *    - How many patients have multiple insurance plans?
 *    - Are there patterns in estimated insurance by patient status?
 *    - Which patient segments have the highest insurance estimates?
 * 
 * 5. Financial Opportunity Analysis
 *    - What is the total potential revenue from pending claims?
 *    - Which carrier-procedure combinations offer the best payment rates?
 *    - Are there procedures with consistently low payment estimates?
 *    - What is the average expected patient responsibility by carrier?
 * 
 * 6. Processing Efficiency
 *    - What is the average time between service date and processing?
 *    - Which carriers have the fastest processing times?
 *    - Are there patterns in claim status by carrier?
 *    - How do processing times vary by procedure type?
 * 
 * Note: Complex calculations and formatting will be handled in pandas notebooks
 * for more flexibility and easier maintenance
 */
 -- Date range: @start_date to @end_date
 -- Dependent CTEs:

WITH DateRange AS (
    SELECT 
        @start_date AS start_date,
        @end_date AS end_date
)
-- Get all treatment planned procedures with patient and insurance info
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
    AND tp.DateTP >= @start_date  -- Only look at recent treatment plans
ORDER BY 
    tp.DateTP DESC,
    p.PatNum,
    tp.TreatPlanNum,
    ptp.ItemOrder;