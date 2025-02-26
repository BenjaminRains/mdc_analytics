-- APPOINTMENT DETAILS
-- Provides appointment information within date range
-- Used for joining procedures to appointments and tracking appointment status
-- dependent CTEs: None
-- Date filter: 2024-01-01 to 2025-01-01
-- NOTE: AptDateTime is formatted as '0001-01-01 00:00:00' when null
AppointmentDetails AS (
    SELECT
        a.AptNum,
        NULLIF(DATE(a.AptDateTime), '0001-01-01') AS AptDate,
        a.AptStatus
    FROM appointment a
    WHERE a.AptDateTime >= '{{START_DATE}}' 
      AND a.AptDateTime < '{{END_DATE}}'
)