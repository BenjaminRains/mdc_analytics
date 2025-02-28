-- PatientInsuranceStatus: Analyzes patient insurance relationships and status
-- Date filter: 2024-01-01 to 2025-01-01
-- Dependencies: none

PatientInsuranceStatus AS (
    SELECT 
        p.PatNum,
        p.Guarantor,
        p.HasIns,
        p.InsEst as InsuranceEstimate,
        p.EstBalance,
        p.BalTotal,
        -- Insurance metrics
        COUNT(DISTINCT ins.InsSubNum) as insurance_plan_count,
        COUNT(DISTINCT CASE 
            WHEN ins.DateTerm = '0001-01-01' 
                OR ins.DateTerm >= CURRENT_DATE 
            THEN ins.InsSubNum 
        END) as active_insurance_count,
        -- Claims and payments
        COUNT(DISTINCT cp.ClaimNum) as total_claims,
        SUM(cp.InsPayEst) as total_insurance_estimates,
        SUM(cp.InsPayAmt) as total_insurance_payments,
        SUM(cp.WriteOff) as total_writeoffs,
        SUM(cp.DedApplied) as total_deductibles,
        -- Status tracking
        MAX(ins.DateEffective) as latest_coverage_start,
        MAX(CASE 
            WHEN ins.DateTerm != '0001-01-01' 
            THEN ins.DateTerm 
        END) as latest_coverage_end,
        -- Financial analysis
        SUM(CASE 
            WHEN cp.Status IN (1, 4, 5) -- Received statuses
            THEN cp.InsPayAmt 
            END) / NULLIF(SUM(cp.InsPayEst), 0) as payment_to_estimate_ratio,
        AVG(CASE 
            WHEN cp.Status IN (1, 4, 5)
            THEN DATEDIFF(cp.DateCP, cp.ProcDate)
            END) as avg_days_to_payment
    FROM patient p
    LEFT JOIN inssub ins ON p.PatNum = ins.Subscriber
    LEFT JOIN claimproc cp ON p.PatNum = cp.PatNum
        AND cp.ProcDate BETWEEN '{{START_DATE}}' AND '{{END_DATE}}'
    WHERE p.PatStatus = 1 -- Active patients only
    GROUP BY 
        p.PatNum,
        p.Guarantor,
        p.HasIns,
        p.InsEst,
        p.EstBalance,
        p.BalTotal
) 