/*
 * Insurance Opportunity Analysis for Out-of-Network Practice
 *
 * Purpose: Analyze insurance payment patterns and identify marketing opportunities
 * for out-of-network patients based on carrier performance and patient coverage
 *
 * Focus Areas:
 * - Carrier Payment Performance: Identify carriers with best payment rates
 * - Patient Insurance Coverage: Track active insurance plans
 * - Treatment Opportunities: Match patients with pending treatment to good carriers
 * - Marketing Targeting: Identify patient segments for procedure promotions
 */

WITH 
CarrierPaymentPerformance AS (
    SELECT 
        c.CarrierNum,
        c.CarrierName,
        c.ElectID,
        COUNT(DISTINCT cp.ClaimNum) as total_claims,
        -- Payment performance
        AVG(cp.InsPayAmt / NULLIF(cp.ProcFee, 0)) * 100 as avg_payment_percentage,
        AVG(cp.WriteOff / NULLIF(cp.ProcFee, 0)) * 100 as avg_writeoff_percentage,
        AVG(cp.DedApplied) as avg_deductible,
        -- Processing metrics
        AVG(DATEDIFF(DAY, cl.DateService, cp.DateCP)) as avg_days_to_payment,
        -- Financial impact
        SUM(cp.InsPayAmt) as total_payments,
        SUM(cp.ProcFee) as total_billed,
        -- Procedure coverage
        COUNT(DISTINCT cp.ProcNum) as unique_procedures_covered,
        -- Plan types
        COUNT(DISTINCT i.PlanNum) as active_plans,
        STRING_AGG(
            DISTINCT CONCAT(
                i.PlanType, ': ',
                COUNT(*), ' claims'
            ),
            '; '
        ) as plan_type_distribution
    FROM carrier c
    JOIN insplan i ON c.CarrierNum = i.CarrierNum
    JOIN claim cl ON i.PlanNum = cl.PlanNum
    JOIN claimproc cp ON cl.ClaimNum = cp.ClaimNum
    WHERE cl.DateService BETWEEN '2024-01-01' AND '2024-12-31'
        AND NOT c.IsHidden
    GROUP BY 
        c.CarrierNum,
        c.CarrierName,
        c.ElectID
),
PatientInsuranceCoverage AS (
    SELECT 
        p.PatNum,
        p.LName,
        p.FName,
        p.HasIns,
        p.InsEst as estimated_insurance,
        i.CarrierNum,
        i.PlanNum,
        i.PlanType,
        i.GroupName,
        -- Active coverage check
        CASE 
            WHEN s.DateTerm = '0001-01-01' OR s.DateTerm >= CURRENT_DATE 
            THEN 1 ELSE 0 
        END as is_active_coverage,
        -- Financial metrics
        p.EstBalance,
        p.BalTotal,
        -- Treatment status
        CASE WHEN p.PlannedIsDone = 0 THEN 1 ELSE 0 END as has_pending_treatment
    FROM patient p
    JOIN inssub s ON p.PatNum = s.Subscriber
    JOIN insplan i ON s.PlanNum = i.PlanNum
    WHERE p.PatStatus = 1  -- Active patients only
        AND NOT i.IsHidden
),
ProcedurePaymentAnalysis AS (
    SELECT 
        i.CarrierNum,
        pl.ProcCode,
        pl.Descript as procedure_description,
        COUNT(DISTINCT cp.ClaimNum) as claim_count,
        AVG(cp.InsPayAmt) as avg_insurance_payment,
        AVG(cp.ProcFee) as avg_billed_amount,
        AVG(cp.InsPayAmt / NULLIF(cp.ProcFee, 0)) * 100 as payment_percentage,
        -- Procedure success metrics
        COUNT(DISTINCT CASE 
            WHEN cp.InsPayAmt >= cp.ProcFee * 0.7  -- 70% or better payment
            THEN cp.ClaimNum 
        END) * 100.0 / NULLIF(COUNT(DISTINCT cp.ClaimNum), 0) as good_payment_rate
    FROM insplan i
    JOIN claim c ON i.PlanNum = c.PlanNum
    JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum
    JOIN procedurelog pl ON cp.ProcNum = pl.ProcNum
    WHERE c.DateService BETWEEN '2024-01-01' AND '2024-12-31'
    GROUP BY 
        i.CarrierNum,
        pl.ProcCode,
        pl.Descript
    HAVING COUNT(DISTINCT cp.ClaimNum) >= 5  -- Minimum claims for significance
)

SELECT 
    cpp.CarrierName,
    cpp.ElectID,
    
    -- Carrier Performance Metrics
    cpp.total_claims,
    CAST(ROUND(cpp.avg_payment_percentage, 1) AS VARCHAR) + '%' as avg_payment_rate,
    CAST(ROUND(cpp.avg_writeoff_percentage, 1) AS VARCHAR) + '%' as avg_writeoff_rate,
    cpp.avg_days_to_payment,
    
    -- Financial Performance
    FORMAT(cpp.total_payments, 'C') as total_payments,
    FORMAT(cpp.total_payments / cpp.total_claims, 'C') as avg_payment_per_claim,
    
    -- Patient Coverage
    COUNT(DISTINCT pic.PatNum) as covered_patients,
    COUNT(DISTINCT CASE 
        WHEN pic.has_pending_treatment = 1 
        THEN pic.PatNum 
    END) as patients_with_pending_treatment,
    
    -- Best Performing Procedures
    STRING_AGG(
        DISTINCT CASE 
            WHEN ppa.payment_percentage >= 70  -- Show procedures with good payment rates
            THEN CONCAT(
                ppa.ProcCode, ' (',
                ppa.procedure_description, '): ',
                CAST(ROUND(ppa.payment_percentage, 1) AS VARCHAR), '% paid, ',
                FORMAT(ppa.avg_insurance_payment, 'C'), ' avg payment'
            )
        END,
        '; '
    ) as best_paying_procedures,
    
    -- Marketing Opportunity Score (0-100)
    CAST(ROUND(
        (cpp.avg_payment_percentage * 0.4) +  -- Payment rate weight
        (CASE WHEN cpp.avg_days_to_payment <= 30 THEN 30 ELSE 0 END) +  -- Quick payment bonus
        (CASE WHEN cpp.total_claims >= 100 THEN 20 ELSE cpp.total_claims * 0.2 END) +  -- Volume bonus
        (CASE WHEN cpp.avg_writeoff_percentage <= 20 THEN 10 ELSE 0 END)  -- Low writeoff bonus
    , 0) AS INT) as opportunity_score,
    
    -- Patient Marketing List
    STRING_AGG(
        DISTINCT CASE 
            WHEN pic.has_pending_treatment = 1 
            AND pic.is_active_coverage = 1
            THEN CONCAT(
                pic.LName, ', ', pic.FName,
                ' (Est. Ins: ', FORMAT(pic.estimated_insurance, 'C'), ')'
            )
        END,
        '; '
    ) as target_patients,
    
    -- Plan Details
    cpp.plan_type_distribution,
    cpp.active_plans as number_of_plans,
    
    -- Procedure Recommendations
    STRING_AGG(
        DISTINCT CASE 
            WHEN ppa.good_payment_rate >= 80  -- Highly successful procedures
            THEN CONCAT(
                ppa.ProcCode, ' - ',
                ppa.procedure_description, ' (',
                CAST(ROUND(ppa.good_payment_rate, 0) AS VARCHAR), '% success rate)'
            )
        END,
        '; '
    ) as recommended_procedures

FROM CarrierPaymentPerformance cpp
LEFT JOIN PatientInsuranceCoverage pic ON cpp.CarrierNum = pic.CarrierNum
LEFT JOIN ProcedurePaymentAnalysis ppa ON cpp.CarrierNum = ppa.CarrierNum
GROUP BY 
    cpp.CarrierNum,
    cpp.CarrierName,
    cpp.ElectID,
    cpp.total_claims,
    cpp.avg_payment_percentage,
    cpp.avg_writeoff_percentage,
    cpp.avg_days_to_payment,
    cpp.total_payments,
    cpp.plan_type_distribution,
    cpp.active_plans
HAVING COUNT(DISTINCT pic.PatNum) > 0
ORDER BY 
    opportunity_score DESC,
    cpp.total_payments DESC; 