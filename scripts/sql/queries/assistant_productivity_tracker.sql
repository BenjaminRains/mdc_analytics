-- Assistant Productivity Tracker
-- Tracks daily completed appointments per dental assistant

-- Set analysis date range
SET @FromDate = '2024-05-01';  -- Start date
SET @ToDate = '2024-05-31';    -- End date

-- Main tracking query
SELECT
    DATE_FORMAT(ap.AptDateTime, '%m/%d/%Y') AS 'Date',
    CONCAT(emp.FName, ' ', emp.LName) AS 'Assistant',
    COUNT(DISTINCT ap.AptNum) AS 'Count of Appointments'
FROM appointment ap
INNER JOIN employee emp
    ON emp.EmployeeNum = ap.Assistant
WHERE ap.AptDateTime BETWEEN DATE(@FromDate) AND DATE(@ToDate) + INTERVAL 1 DAY
    AND ap.AptStatus = 2  -- Complete status only
GROUP BY DATE(ap.AptDateTime), ap.Assistant
ORDER BY DATE(ap.AptDateTime) ASC, CONCAT(emp.FName, ' ', emp.LName); 