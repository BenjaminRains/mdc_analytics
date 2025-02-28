/*
 * Carrier and Insurance Plan Configuration Analysis
 *
 * Purpose: Extract detailed carrier and plan configuration data
 * to understand setup parameters that affect payment behavior
 *
 * Categories:
 * - Carrier Configuration
 * - Plan Settings
 * - Fee Schedule Links
 * - Electronic Filing Settings
 * - Special Handling Flags
 */

WITH 
CarrierConfiguration AS (
    SELECT 
        c.CarrierNum,
        c.CarrierName,
        c.ElectID,
        c.TIN,
        c.Address,
        c.City,
        c.State,
        c.Zip,
        c.Phone,
        -- Electronic filing settings
        c.NoSendElect,
        c.TrustedEtransFlags,
        c.EraAutomationOverride,
        -- Special handling
        c.IsCoinsuranceInverted,
        c.CobInsPaidBehaviorOverride,
        c.OrthoInsPayConsolidate,
        -- Grouping
        c.CarrierGroupName,
        -- Audit fields
        c.SecUserNumEntry,
        c.SecDateEntry,
        c.SecDateTEdit as LastModified,
        -- Active status
        c.IsHidden
    FROM carrier c
),
PlanConfiguration AS (
    SELECT 
        i.PlanNum,
        i.CarrierNum,
        i.GroupName,
        i.GroupNum,
        i.PlanType,
        i.DivisionNo,
        -- Fee schedule links
        i.FeeSched,
        i.CopayFeeSched,
        i.AllowedFeeSched,
        i.ManualFeeSchedNum,
        -- Claim configuration
        i.ClaimFormNum,
        i.UseAltCode,
        i.ClaimsUseUCR,
        i.FilingCode,
        i.FilingCodeSubtype,
        -- Special features
        i.IsMedical,
        i.ShowBaseUnits,
        i.CodeSubstNone,
        i.IsBlueBookEnabled,
        -- Financial settings
        i.CobRule,
        i.ExclusionFeeRule,
        i.HasPpoSubstWriteoffs,
        i.InsPlansZeroWriteOffsOnAnnualMaxOverride,
        i.InsPlansZeroWriteOffsOnFreqOrAgingOverride,
        -- Per visit amounts
        i.PerVisitPatAmount,
        i.PerVisitInsAmount,
        -- Ortho settings
        i.OrthoType,
        i.OrthoAutoProcFreq,
        i.OrthoAutoFeeBilled,
        i.OrthoAutoClaimDaysWait,
        -- Plan notes
        i.PlanNote,
        -- Active status
        i.IsHidden,
        -- Audit fields
        i.SecUserNumEntry,
        i.SecDateEntry,
        i.SecDateTEdit as LastModified
    FROM insplan i
),
PlanUsageMetrics AS (
    SELECT 
        i.PlanNum,
        i.CarrierNum,
        COUNT(DISTINCT c.ClaimNum) as total_claims,
        COUNT(DISTINCT c.PatNum) as total_patients,
        SUM(cp.InsPayAmt) as total_payments,
        SUM(cp.WriteOff) as total_writeoffs,
        SUM(cp.DedApplied) as total_deductibles,
        AVG(cp.InsPayAmt) as avg_payment,
        MAX(c.DateService) as last_claim_date,
        MIN(c.DateService) as first_claim_date
    FROM insplan i
    JOIN claim c ON i.PlanNum = c.PlanNum
    JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum
    WHERE c.DateService BETWEEN '2024-01-01' AND '2024-12-31'
    GROUP BY i.PlanNum, i.CarrierNum
)

SELECT 
    -- Carrier Information
    cc.CarrierNum,
    cc.CarrierName,
    cc.ElectID,
    cc.TIN,
    
    -- Contact Details
    CONCAT(
        cc.Address, ', ',
        cc.City, ', ',
        cc.State, ' ',
        cc.Zip
    ) as full_address,
    cc.Phone,
    
    -- Electronic Configuration
    CASE cc.NoSendElect 
        WHEN 0 THEN 'Electronic Filing Enabled'
        ELSE 'No Electronic Filing'
    END as electronic_filing_status,
    
    -- Special Handling Flags
    CONCAT(
        CASE cc.IsCoinsuranceInverted WHEN 1 THEN 'Inverted Coins;' ELSE '' END,
        CASE cc.CobInsPaidBehaviorOverride WHEN 1 THEN 'COB Override;' ELSE '' END,
        CASE cc.OrthoInsPayConsolidate WHEN 1 THEN 'Ortho Consolidated;' ELSE '' END
    ) as special_handling_flags,
    
    -- Plan Counts and Types
    COUNT(DISTINCT pc.PlanNum) as total_plans,
    STRING_AGG(
        DISTINCT CONCAT(
            pc.PlanType, ': ',
            COUNT(*), ' plans'
        ),
        '; '
    ) as plan_type_distribution,
    
    -- Fee Schedule Usage
    STRING_AGG(
        DISTINCT CASE 
            WHEN pc.FeeSched > 0 THEN 'Standard'
            WHEN pc.AllowedFeeSched > 0 THEN 'Allowed'
            WHEN pc.CopayFeeSched > 0 THEN 'Copay'
            WHEN pc.ManualFeeSchedNum > 0 THEN 'Manual'
            ELSE 'None'
        END,
        '; '
    ) as fee_schedule_types,
    
    -- Claims Configuration
    STRING_AGG(
        DISTINCT CONCAT(
            'Form:', pc.ClaimFormNum,
            CASE pc.UseAltCode WHEN 1 THEN ' (Alt)' ELSE '' END
        ),
        '; '
    ) as claim_form_config,
    
    -- Usage Metrics
    SUM(pum.total_claims) as total_claims_2024,
    SUM(pum.total_patients) as total_patients_2024,
    FORMAT(SUM(pum.total_payments), 'C') as total_payments_2024,
    FORMAT(AVG(pum.avg_payment), 'C') as avg_payment_per_claim,
    
    -- Active Plans Detail
    STRING_AGG(
        DISTINCT CASE 
            WHEN NOT pc.IsHidden 
            THEN CONCAT(
                pc.GroupName, ' (',
                pc.GroupNum, ') - Type:',
                pc.PlanType
            )
        END,
        '; '
    ) as active_plans,
    
    -- Special Features
    STRING_AGG(
        DISTINCT CONCAT(
            CASE 
                WHEN pc.IsBlueBookEnabled = 1 THEN 'BlueBook;'
                ELSE ''
            END,
            CASE 
                WHEN pc.HasPpoSubstWriteoffs = 1 THEN 'PPO Writeoffs;'
                ELSE ''
            END,
            CASE 
                WHEN pc.IsMedical = 1 THEN 'Medical;'
                ELSE ''
            END
        ),
        ' '
    ) as enabled_features,
    
    -- Financial Rules
    STRING_AGG(
        DISTINCT CONCAT(
            'COB:', pc.CobRule,
            ';Excl:', pc.ExclusionFeeRule,
            CASE 
                WHEN pc.InsPlansZeroWriteOffsOnAnnualMaxOverride = 1 
                THEN ';ZeroWO-Max'
                ELSE ''
            END,
            CASE 
                WHEN pc.InsPlansZeroWriteOffsOnFreqOrAgingOverride = 1 
                THEN ';ZeroWO-Freq'
                ELSE ''
            END
        ),
        ' | '
    ) as financial_rules,
    
    -- Per Visit Settings
    STRING_AGG(
        DISTINCT CASE 
            WHEN pc.PerVisitPatAmount > 0 OR pc.PerVisitInsAmount > 0
            THEN CONCAT(
                'Pat:', FORMAT(pc.PerVisitPatAmount, 'C'),
                '/Ins:', FORMAT(pc.PerVisitInsAmount, 'C')
            )
        END,
        '; '
    ) as per_visit_amounts,
    
    -- Ortho Configuration
    STRING_AGG(
        DISTINCT CASE 
            WHEN pc.OrthoType > 0
            THEN CONCAT(
                'Type:', pc.OrthoType,
                ';Freq:', pc.OrthoAutoProcFreq,
                ';Wait:', pc.OrthoAutoClaimDaysWait,
                ';Fee:', FORMAT(pc.OrthoAutoFeeBilled, 'C')
            )
        END,
        ' | '
    ) as ortho_config,
    
    -- Audit Information
    MAX(pc.LastModified) as last_plan_modified,
    cc.LastModified as last_carrier_modified

FROM CarrierConfiguration cc
LEFT JOIN PlanConfiguration pc ON cc.CarrierNum = pc.CarrierNum
LEFT JOIN PlanUsageMetrics pum ON pc.PlanNum = pum.PlanNum
WHERE NOT cc.IsHidden
GROUP BY 
    cc.CarrierNum,
    cc.CarrierName,
    cc.ElectID,
    cc.TIN,
    cc.Address,
    cc.City,
    cc.State,
    cc.Zip,
    cc.Phone,
    cc.NoSendElect,
    cc.IsCoinsuranceInverted,
    cc.CobInsPaidBehaviorOverride,
    cc.OrthoInsPayConsolidate,
    cc.LastModified
ORDER BY 
    total_claims_2024 DESC,
    cc.CarrierName; 