-- BenefitCoverage: Analyzes benefit coverage details and limitations
-- Date filter: 2024-01-01 to 2025-01-01
-- Dependencies: none

BenefitCoverage AS (
    SELECT 
        b.PlanNum,
        b.BenefitType,
        b.CovCatNum,
        b.TimePeriod,
        b.Percent,
        b.MonetaryAmt,
        b.QuantityQualifier,
        b.Quantity,
        b.CoverageLevel,
        b.CodeNum,
        COUNT(*) as benefit_count,
        AVG(CASE WHEN b.Percent != -1 THEN b.Percent ELSE NULL END) as avg_percent,
        MAX(CASE WHEN b.Percent != -1 THEN b.Percent ELSE NULL END) as max_percent,
        MIN(CASE WHEN b.Percent != -1 THEN b.Percent ELSE NULL END) as min_percent,
        SUM(CASE WHEN b.MonetaryAmt != 0 THEN 1 ELSE 0 END) as monetary_rules_count,
        AVG(CASE WHEN b.MonetaryAmt != 0 THEN b.MonetaryAmt ELSE NULL END) as avg_monetary_amt,
        MAX(CASE WHEN b.MonetaryAmt != 0 THEN b.MonetaryAmt ELSE NULL END) as max_monetary_amt
    FROM benefit b
    WHERE b.SecDateTEntry BETWEEN '{{START_DATE}}' AND '{{END_DATE}}'
        OR b.SecDateTEdit BETWEEN '{{START_DATE}}' AND '{{END_DATE}}'
    GROUP BY 
        b.PlanNum,
        b.BenefitType,
        b.CovCatNum,
        b.TimePeriod,
        b.QuantityQualifier,
        b.Quantity,
        b.CoverageLevel,
        b.CodeNum
) 