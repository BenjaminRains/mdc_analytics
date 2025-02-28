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
 -- Date range: 2024-01-01 to 2025-01-01
 -- Dependent CTEs:

WITH DateRange AS (
    SELECT 
        '2024-01-01' AS start_date,
        '2024-12-31' AS end_date
),

-- Get treatment planned procedures
TreatmentPlanned AS (
    SELECT 
        pl.ProcNum,
        pl.PatNum,
        pl.ProcDate,
        pl.ProcFee as billed_fee,
        pl.CodeNum,
        proctp.Priority as treatment_priority,
        proctp.PatAmt as patient_portion,
        tp.DateTP as treatment_plan_date,
        tp.TPStatus as treatment_plan_status,
        pc.ProcCode,
        pc.Descript as procedure_description
    FROM procedurelog pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    LEFT JOIN proctp ON pl.ProcNum = proctp.ProcNumOrig
    LEFT JOIN treatplan tp ON proctp.TreatPlanNum = tp.TreatPlanNum
    WHERE pl.ProcStatus = 1  -- Treatment Planned
    AND pl.ProcDate >= (SELECT start_date FROM DateRange)
    AND pl.ProcDate < (SELECT end_date FROM DateRange)
),

-- Get insurance plan performance metrics
PlanPerformance AS (
    SELECT 
        ip.PlanNum,
        c.CarrierNum,
        c.CarrierName,
        ip.GroupName,
        ip.Percentage as coverage_percentage,
        COUNT(DISTINCT cp.ClaimNum) as total_claims,
        SUM(cp.InsPayEst) as total_estimated,
        SUM(cp.InsPayAmt) as total_paid,
        SUM(cp.WriteOff) as total_writeoff,
        SUM(cp.DedApplied) as total_deductible,
        AVG(cp.InsPayAmt / NULLIF(cp.FeeBilled, 0)) as payment_ratio
    FROM insplan ip
    JOIN carrier c ON ip.CarrierNum = c.CarrierNum
    JOIN claimproc cp ON ip.PlanNum = cp.PlanNum
    WHERE cp.DateCP >= (SELECT start_date FROM DateRange)
    AND cp.DateCP < (SELECT end_date FROM DateRange)
    GROUP BY ip.PlanNum, c.CarrierNum, c.CarrierName, ip.GroupName, ip.Percentage
    HAVING total_claims >= 100  -- Only include plans with significant claims volume
)

-- Combine treatment planned procedures with plan performance
SELECT 
    -- Patient Info
    tp.PatNum,
    pat.LName as patient_last_name,
    pat.FName as patient_first_name,
    pat.HasIns as has_insurance,
    
    -- Procedure Info
    tp.ProcNum,
    tp.ProcCode,
    tp.procedure_description,
    tp.billed_fee,
    tp.treatment_priority,
    tp.patient_portion,
    tp.treatment_plan_date,
    tp.treatment_plan_status,
    
    -- Insurance Plan Info
    pp.CarrierName,
    pp.GroupName,
    pp.coverage_percentage,
    pp.payment_ratio,
    pp.total_claims,
    pp.total_estimated,
    pp.total_paid,
    
    -- Calculated Fields
    ROUND(tp.billed_fee * pp.payment_ratio, 2) as estimated_insurance_payment,
    ROUND(tp.billed_fee * (1 - pp.payment_ratio), 2) as estimated_patient_responsibility,
    
    -- Prioritization Score (higher is better)
    ROUND(
        (pp.payment_ratio * 0.4) +  -- 40% weight on payment ratio
        (pp.coverage_percentage/100 * 0.4) +  -- 40% weight on coverage percentage
        (CASE 
            WHEN tp.treatment_priority = 1 THEN 0.2
            WHEN tp.treatment_priority = 2 THEN 0.1
            ELSE 0
        END)  -- 20% weight on treatment priority
    , 3) as opportunity_score

FROM TreatmentPlanned tp
JOIN patient pat ON tp.PatNum = pat.PatNum
LEFT JOIN patplan pp_link ON tp.PatNum = pp_link.PatNum
LEFT JOIN PlanPerformance pp ON pp_link.PlanNum = pp.PlanNum

WHERE pat.PatStatus = 0  -- Only active patients
AND (pat.HasIns = 1 OR pp.PlanNum IS NULL)  -- Patients with insurance or unlinked claims

ORDER BY 
    opportunity_score DESC,
    tp.treatment_plan_date ASC,
    tp.billed_fee DESC; 