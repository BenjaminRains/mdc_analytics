-- Date range: @start_date to @end_date
-- Dependent CTEs:
-- Description: Valid carriers are those that are not hidden and have plans in the date range

ValidCarriers AS (
    SELECT 
        c.CarrierNum,
        c.CarrierName,
        c.ElectID,
        COUNT(DISTINCT ip.PlanNum) as PlanCount
    FROM carrier c
    INNER JOIN insplan ip ON c.CarrierNum = ip.CarrierNum
    WHERE NOT c.IsHidden
    GROUP BY c.CarrierNum, c.CarrierName, c.ElectID
)