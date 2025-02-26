-- APPOINTMENT DETAILS
-- Provides appointment information within date range
-- Used for joining procedures to appointments and tracking appointment status
-- dependent CTEs: None
AppointmentDetails AS (
    SELECT
        a.AptNum,
        a.AptDateTime,
        a.AptStatus
    FROM appointment a
    WHERE a.AptDateTime >= '{{START_DATE}}' AND a.AptDateTime < '{{END_DATE}}'
)