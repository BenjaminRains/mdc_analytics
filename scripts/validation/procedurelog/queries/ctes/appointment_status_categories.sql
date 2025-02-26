-- APPOINTMENT STATUS CATEGORIES
-- Standardizes appointment status code translations
-- Ensures consistent categorization of appointment statuses across reports
-- dependent CTEs: AppointmentDetails
AppointmentStatusCategories AS (
    SELECT 
        AptStatus,
        CASE AptStatus
            WHEN 1 THEN 'Scheduled'
            WHEN 2 THEN 'Complete'
            WHEN 3 THEN 'UnschedList'
            WHEN 4 THEN 'ASAP'
            WHEN 5 THEN 'Broken'
            WHEN 6 THEN 'Planned'
            WHEN 7 THEN 'CPHAScheduled'
            WHEN 8 THEN 'PinBoard'
            WHEN 9 THEN 'WebSchedNewPt'
            WHEN 10 THEN 'WebSchedRecall'
            ELSE 'Unknown'
        END AS StatusDescription
    FROM (SELECT DISTINCT AptStatus FROM AppointmentDetails) AS statuses
)