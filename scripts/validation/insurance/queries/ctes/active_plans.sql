-- ActivePlans: Identifies currently active insurance plans and their key relationships
-- Date filter: @start_date to @end_date
-- Dependent CTEs: none

ActivePlans AS (
    SELECT 
        ip.PlanNum,
        ip.CarrierNum,
        c.CarrierName,
        ip.GroupName,
        ip.GroupNum,
        ip.PlanType,
        ip.IsMedical,
        ip.IsHidden,
        COUNT(DISTINCT ins.InsSubNum) as subscriber_count,
        COUNT(DISTINCT CASE 
            WHEN ins.DateTerm = '0001-01-01' 
                OR ins.DateTerm >= @start_date
            THEN ins.InsSubNum 
        END) as active_subscriber_count,
        MIN(ins.DateEffective) as earliest_effective_date,
        MAX(CASE 
            WHEN ins.DateTerm = '0001-01-01' THEN '9999-12-31'
            ELSE ins.DateTerm 
        END) as latest_term_date
    FROM insplan ip
    JOIN carrier c ON ip.CarrierNum = c.CarrierNum
    LEFT JOIN inssub ins ON ip.PlanNum = ins.PlanNum
    WHERE 
        (ins.DateEffective <= @end_date
        AND (ins.DateTerm = '0001-01-01' OR ins.DateTerm >= @start_date))
        OR ins.InsSubNum IS NULL -- Include plans with no subscribers for analysis
    GROUP BY 
        ip.PlanNum,
        ip.CarrierNum,
        c.CarrierName,
        ip.GroupName,
        ip.GroupNum,
        ip.PlanType,
        ip.IsMedical,
        ip.IsHidden
) 