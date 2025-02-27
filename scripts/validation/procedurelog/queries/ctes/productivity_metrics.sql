-- PRODUCTIVITY METRICS
-- Analyzes provider productivity including appointment efficiency
-- Dependent CTEs: base_procedures.sql
ProductivityMetrics AS (
    WITH AppointmentStats AS (
        SELECT 
            bp.ProvNum,
            bp.AptNum,
            COUNT(*) AS ProcsPerAppointment,
            SUM(bp.ProcFee) AS FeePerAppointment,
            -- Calculate appointment duration from pattern
            LENGTH(a.Pattern) - LENGTH(REPLACE(a.Pattern, 'X', '')) AS ProviderTimeBlocks,
            a.Pattern
        FROM BaseProcedures bp
        JOIN appointment a ON bp.AptNum = a.AptNum
        WHERE bp.AptNum > 0
          AND bp.ProcStatus = 2  -- Only completed procedures
        GROUP BY bp.ProvNum, bp.AptNum, a.Pattern
    )
    SELECT 
        ProvNum,
        COUNT(DISTINCT AptNum) AS AppointmentCount,
        
        -- Time calculations
        SUM(ProviderTimeBlocks * 10.0) / 60.0 AS ScheduledHours,
        
        -- Production metrics
        SUM(FeePerAppointment) AS TotalProduction,
        CASE 
            WHEN SUM(ProviderTimeBlocks * 10.0) > 0 
            THEN (SUM(FeePerAppointment) / (SUM(ProviderTimeBlocks * 10.0) / 60.0))
            ELSE 0 
        END AS HourlyProduction,
        
        -- Efficiency metrics
        ROUND(AVG(ProcsPerAppointment), 1) AS AvgProcsPerAppt,
        ROUND(AVG(FeePerAppointment), 2) AS AvgFeePerAppt,
        
        -- Time utilization
        ROUND(100.0 * COUNT(CASE WHEN Pattern LIKE '%X%' THEN 1 END) / 
              NULLIF(COUNT(*), 0), 1) AS PctApptWithProviderTime,
              
        -- Productivity trends
        ROUND(AVG(
            CASE WHEN Pattern LIKE '%X%' 
            THEN FeePerAppointment / (LENGTH(Pattern) - LENGTH(REPLACE(Pattern, 'X', ''))) 
            ELSE NULL END
        ), 2) AS AvgFeePerProviderBlock
    FROM AppointmentStats
    GROUP BY ProvNum
)