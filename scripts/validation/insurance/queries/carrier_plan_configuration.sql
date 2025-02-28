/*
 * Carrier and Insurance Plan Configuration Analysis
 * 
 * Purpose: Extract and analyze carrier configuration, plan setup, and claims performance
 * to identify patterns, optimize payment processing, and improve carrier relationships.
 *
 * Key Analysis Questions:
 * 1. Carrier Performance & Volume
 *    - Which carriers process the most claims/payments?
 *    - How do average payment amounts vary by carrier?
 *    - What is the claims-to-patient ratio for each carrier?
 *    - Are there significant differences in deductible applications?
 *
 * 2. Fee Schedule Implementation
 *    - How many plans use each fee schedule type?
 *    - Which carriers have the most diverse fee schedule setups?
 *    - Are certain fee schedule types associated with higher payment rates?
 *
 * 3. Electronic Filing & Automation
 *    - What percentage of carriers support electronic filing?
 *    - How does claim volume correlate with electronic filing settings?
 *    - Are there payment efficiency differences based on filing methods?
 *
 * 4. Plan Configuration Patterns
 *    - What are the common COB rule configurations?
 *    - How prevalent are PPO writeoff settings?
 *    - Which special features (BlueBook, Medical, etc.) are most common?
 *
 * 5. Payment Processing Efficiency
 *    - What is the relationship between plan settings and payment amounts?
 *    - Do certain configuration patterns lead to higher writeoffs?
 *    - How do deductible applications vary across carriers?
 *
 * 6. Temporal Analysis
 *    - Are there patterns in claim submission timing?
 *    - How recent are carrier and plan modifications?
 *    - What is the typical lifecycle of claims by carrier?
 *
 * Categories:
 * - Carrier Configuration
 * - Plan Settings
 * - Fee Schedule Links
 * - Electronic Filing Settings
 * - Special Handling Flags
 */
-- Date range: 2024-01-01 to 2025-01-01
-- Dependent CTEs: date_range.sql, carrier_configuration.sql, plan_configuration.sql, plan_usage_metrics.sql

SELECT 
    -- Carrier Info
    cc.CarrierNum,
    cc.CarrierName,
    cc.ElectID,
    cc.TIN,
    cc.Address,
    cc.City,
    cc.State,
    cc.Zip,
    cc.Phone,
    
    -- Electronic Filing
    cc.NoSendElect,
    cc.TrustedEtransFlags,
    cc.EraAutomationOverride,
    
    -- Special Handling
    cc.IsCoinsuranceInverted,
    cc.CobInsPaidBehaviorOverride,
    cc.OrthoInsPayConsolidate,
    
    -- Plan Metrics
    COUNT(DISTINCT pc.PlanNum) as total_plans,
    COUNT(DISTINCT CASE WHEN pc.FeeSched > 0 THEN pc.PlanNum END) as plans_with_standard_fees,
    COUNT(DISTINCT CASE WHEN pc.AllowedFeeSched > 0 THEN pc.PlanNum END) as plans_with_allowed_fees,
    COUNT(DISTINCT CASE WHEN pc.CopayFeeSched > 0 THEN pc.PlanNum END) as plans_with_copay_fees,
    COUNT(DISTINCT CASE WHEN pc.ManualFeeSchedNum > 0 THEN pc.PlanNum END) as plans_with_manual_fees,
    
    -- Usage Metrics
    SUM(pum.total_claims) as total_claims_2024,
    SUM(pum.total_patients) as total_patients_2024,
    ROUND(COALESCE(SUM(pum.total_payments), 0), 2) as total_payments_2024,
    ROUND(COALESCE(SUM(pum.total_writeoffs), 0), 2) as total_writeoffs_2024,
    ROUND(COALESCE(SUM(pum.total_deductibles), 0), 2) as total_deductibles_2024,
    ROUND(COALESCE(AVG(pum.avg_payment), 0), 2) as avg_payment_per_claim,
    
    -- Plan Type Counts
    COUNT(DISTINCT CASE WHEN pc.IsMedical = 1 THEN pc.PlanNum END) as medical_plans,
    COUNT(DISTINCT CASE WHEN pc.IsBlueBookEnabled = 1 THEN pc.PlanNum END) as bluebook_plans,
    COUNT(DISTINCT CASE WHEN pc.HasPpoSubstWriteoffs = 1 THEN pc.PlanNum END) as ppo_writeoff_plans,
    
    -- Financial Rule Counts
    COUNT(DISTINCT CASE WHEN pc.CobRule = 0 THEN pc.PlanNum END) as cob_standard_plans,
    COUNT(DISTINCT CASE WHEN pc.CobRule = 1 THEN pc.PlanNum END) as cob_override_plans,
    COUNT(DISTINCT CASE WHEN pc.CobRule = 2 THEN pc.PlanNum END) as cob_special_plans,
    
    -- Dates
    MIN(pc.LastModified) as earliest_plan_modified,
    MAX(pc.LastModified) as latest_plan_modified,
    cc.LastModified as carrier_last_modified,
    MIN(pum.first_claim_date) as first_claim_date,
    MAX(pum.last_claim_date) as last_claim_date

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
    cc.TrustedEtransFlags,
    cc.EraAutomationOverride,
    cc.IsCoinsuranceInverted,
    cc.CobInsPaidBehaviorOverride,
    cc.OrthoInsPayConsolidate,
    cc.LastModified
ORDER BY 
    total_claims_2024 DESC,
    cc.CarrierName; 