-- PROVIDER VOLUME
-- Aggregates procedure volumes and status metrics by provider
-- Dependent CTEs: base_procedures.sql
ProviderVolume AS (
    SELECT 
        bp.ProvNum,
        COUNT(*) AS TotalProcedures,
        SUM(bp.ProcFee) AS TotalProcFees,
        COUNT(DISTINCT bp.PatNum) AS UniquePatients,
        COUNT(DISTINCT DATE(bp.ProcDate)) AS DaysWithActivity,
        COUNT(DISTINCT bp.CodeNum) AS UniqueProcCodes,
        
        -- Status counts
        SUM(CASE WHEN bp.ProcStatus = 1 THEN 1 ELSE 0 END) AS StatusTreatmentPlanned,
        SUM(CASE WHEN bp.ProcStatus = 2 THEN 1 ELSE 0 END) AS StatusComplete,
        SUM(CASE WHEN bp.ProcStatus = 3 THEN 1 ELSE 0 END) AS StatusInProgress,
        SUM(CASE WHEN bp.ProcStatus = 4 THEN 1 ELSE 0 END) AS StatusDeleted,
        SUM(CASE WHEN bp.ProcStatus = 5 THEN 1 ELSE 0 END) AS StatusRejected,
        SUM(CASE WHEN bp.ProcStatus = 6 THEN 1 ELSE 0 END) AS StatusCondPlanned,
        SUM(CASE WHEN bp.ProcStatus = 7 THEN 1 ELSE 0 END) AS StatusNeedToDo,
        
        -- Ratios and percentages
        CASE 
            WHEN SUM(CASE WHEN bp.ProcStatus = 2 THEN 1 ELSE 0 END) > 0 
            THEN ROUND(SUM(CASE WHEN bp.ProcStatus = 1 THEN 1 ELSE 0 END) * 1.0 / 
                      SUM(CASE WHEN bp.ProcStatus = 2 THEN 1 ELSE 0 END), 2)
            ELSE 0 
        END AS PlannedToCompletedRatio,
        
        -- Appointment linkage
        SUM(CASE WHEN bp.AptNum > 0 THEN 1 ELSE 0 END) AS ProcsWithAppointment,
        ROUND(100.0 * SUM(CASE WHEN bp.AptNum > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS PctWithAppointment,
        
        -- Date anomalies
        SUM(CASE 
            WHEN bp.ProcStatus = 2 AND bp.DateComplete > CURRENT_DATE 
            THEN 1 ELSE 0 
        END) AS FutureDateCompleteCount,
        SUM(CASE 
            WHEN bp.ProcStatus = 2 AND bp.DateComplete IS NULL 
            THEN 1 ELSE 0 
        END) AS CompletedNoDateCount
    FROM BaseProcedures bp
    WHERE bp.ProvNum > 0
    GROUP BY bp.ProvNum
)