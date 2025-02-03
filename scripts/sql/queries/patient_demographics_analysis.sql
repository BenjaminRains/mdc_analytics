-- Patient Demographics Analysis Report
-- Provides comprehensive patient statistics across multiple categories

-- Initialize base counts for percentage calculations
SELECT COUNT(*) INTO @ActivePatCount
FROM patient
WHERE PatStatus = 0;  -- Active patients only

SELECT COUNT(*) INTO @AllPatCount
FROM patient
WHERE PatStatus IN (0,2,3,5);  -- Patient, Inactive, Archived, Deceased

-- Get special recall types for recall analysis
SELECT GROUP_CONCAT(preference.ValueString)
INTO @SpecialRecallTypes
FROM preference
WHERE preference.PrefName IN (
    'RecallTypeSpecialProphy',
    'RecallTypeSpecialChildProphy',
    'RecallTypeSpecialPerio'
);

-- Main Demographics Analysis
SELECT * FROM (
    -- 1. Gender Distribution
    SELECT 
        CASE patient.Gender 
            WHEN 0 THEN 'Male'
            WHEN 1 THEN 'Female'
            WHEN 2 THEN 'Unknown'
        END AS 'Category',
        COUNT(*) AS '# of Active',
        ROUND(COUNT(*) / @ActivePatCount * 100, 1) AS '% of Active'
    FROM patient
    WHERE PatStatus = 0
    GROUP BY Gender

    UNION ALL
    SELECT '', '', ''  -- Blank row separator
    
    UNION ALL
    
    -- 2. Age Distribution
    SELECT 
        CONCAT('ages ', age_range) AS 'Category',
        COUNT(*) AS '# of Active',
        ROUND(COUNT(*) / @ActivePatCount * 100, 1) AS '% of Active'
    FROM (
        SELECT 
            CASE 
                WHEN TIMESTAMPDIFF(YEAR, Birthdate, CURDATE()) < 10 THEN '0-9'
                WHEN TIMESTAMPDIFF(YEAR, Birthdate, CURDATE()) < 20 THEN '10-19'
                WHEN TIMESTAMPDIFF(YEAR, Birthdate, CURDATE()) < 30 THEN '20-29'
                WHEN TIMESTAMPDIFF(YEAR, Birthdate, CURDATE()) < 40 THEN '30-39'
                WHEN TIMESTAMPDIFF(YEAR, Birthdate, CURDATE()) < 50 THEN '40-49'
                WHEN TIMESTAMPDIFF(YEAR, Birthdate, CURDATE()) < 60 THEN '50-59'
                WHEN TIMESTAMPDIFF(YEAR, Birthdate, CURDATE()) < 70 THEN '60-69'
                WHEN TIMESTAMPDIFF(YEAR, Birthdate, CURDATE()) >= 70 THEN '70+'
                ELSE 'unknown'
            END AS age_range
        FROM patient
        WHERE PatStatus = 0
    ) age_groups
    GROUP BY age_range

    UNION ALL
    SELECT '', '', ''  -- Blank row separator
    
    -- 3. Insurance Status
    UNION ALL
    SELECT 
        CASE WHEN pp.PatPlanNum IS NOT NULL THEN 'Insured' ELSE 'Uninsured' END AS 'Category',
        COUNT(DISTINCT p.PatNum) AS '# of Active',
        ROUND(COUNT(DISTINCT p.PatNum) / @ActivePatCount * 100, 1) AS '% of Active'
    FROM patient p
    LEFT JOIN patplan pp ON pp.PatNum = p.PatNum
    WHERE p.PatStatus = 0
    GROUP BY CASE WHEN pp.PatPlanNum IS NOT NULL THEN 'Insured' ELSE 'Uninsured' END

    -- 4. Visit History
    UNION ALL
    SELECT 
        CASE 
            WHEN TIMESTAMPDIFF(MONTH, MAX(a.AptDateTime), CURDATE()) <= 12 THEN 'Patients - 12 mo'
            WHEN TIMESTAMPDIFF(MONTH, MAX(a.AptDateTime), CURDATE()) <= 24 THEN 'Patients - 24 mo'
            WHEN TIMESTAMPDIFF(MONTH, MAX(a.AptDateTime), CURDATE()) <= 36 THEN 'Patients - 36 mo'
            WHEN MAX(a.AptDateTime) IS NOT NULL THEN 'Patients - > 36 mo'
            ELSE 'Patients No Visit'
        END AS 'Category',
        COUNT(DISTINCT p.PatNum) AS '# of Active',
        ROUND(COUNT(DISTINCT p.PatNum) / @ActivePatCount * 100, 1) AS '% of Active'
    FROM patient p
    LEFT JOIN appointment a ON a.PatNum = p.PatNum 
        AND a.AptStatus = 2  -- Completed appointments only
    WHERE p.PatStatus = 0
    GROUP BY 
        CASE 
            WHEN TIMESTAMPDIFF(MONTH, MAX(a.AptDateTime), CURDATE()) <= 12 THEN 'Patients - 12 mo'
            WHEN TIMESTAMPDIFF(MONTH, MAX(a.AptDateTime), CURDATE()) <= 24 THEN 'Patients - 24 mo'
            WHEN TIMESTAMPDIFF(MONTH, MAX(a.AptDateTime), CURDATE()) <= 36 THEN 'Patients - 36 mo'
            WHEN MAX(a.AptDateTime) IS NOT NULL THEN 'Patients - > 36 mo'
            ELSE 'Patients No Visit'
        END

    UNION ALL
    SELECT '', '', ''  -- Blank row separator

    -- 5. New Patient Analysis
    UNION ALL
    SELECT 
        CASE 
            WHEN DATE_FORMAT(MIN(a.AptDateTime), '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m') 
                THEN 'New Pats This Month'
            WHEN YEAR(MIN(a.AptDateTime)) = YEAR(CURDATE()) 
                THEN 'New Pats This Year'
            WHEN MIN(a.AptDateTime) IS NULL 
                THEN 'Pats with no first visit'
        END AS 'Category',
        COUNT(DISTINCT p.PatNum) AS '# of Active',
        ROUND(COUNT(DISTINCT p.PatNum) / @ActivePatCount * 100, 1) AS '% of Active'
    FROM patient p
    LEFT JOIN appointment a ON a.PatNum = p.PatNum 
        AND a.AptStatus = 2  -- Completed appointments only
    WHERE p.PatStatus = 0
    GROUP BY 
        CASE 
            WHEN DATE_FORMAT(MIN(a.AptDateTime), '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m') 
                THEN 'New Pats This Month'
            WHEN YEAR(MIN(a.AptDateTime)) = YEAR(CURDATE()) 
                THEN 'New Pats This Year'
            WHEN MIN(a.AptDateTime) IS NULL 
                THEN 'Pats with no first visit'
        END

    UNION ALL
    SELECT '', '', ''  -- Blank row separator

    -- 6. Recall Status
    UNION ALL
    SELECT 
        CASE 
            WHEN r.DateScheduled > CURDATE() THEN 'Future Recalls Scheduled'
            WHEN r.DateDue <= CURDATE() AND r.DateScheduled = '0001-01-01' THEN 'Past Due Recall'
            ELSE 'No recall'
        END AS 'Category',
        COUNT(DISTINCT p.PatNum) AS '# of Active',
        ROUND(COUNT(DISTINCT p.PatNum) / @ActivePatCount * 100, 1) AS '% of Active'
    FROM patient p
    LEFT JOIN recall r ON r.PatNum = p.PatNum 
        AND FIND_IN_SET(r.RecallTypeNum, @SpecialRecallTypes)
        AND r.IsDisabled = 0
    WHERE p.PatStatus = 0
    GROUP BY 
        CASE 
            WHEN r.DateScheduled > CURDATE() THEN 'Future Recalls Scheduled'
            WHEN r.DateDue <= CURDATE() AND r.DateScheduled = '0001-01-01' THEN 'Past Due Recall'
            ELSE 'No recall'
        END

    UNION ALL
    SELECT '', '', ''  -- Blank row separator

    -- 7. Appointment Status
    UNION ALL
    SELECT 
        CASE 
            WHEN a.AptDateTime > CURDATE() AND a.AptStatus = 1 THEN 'Pats With Future Appts Booked'
            WHEN a.AptStatus = 3 THEN 'Pats With Past Due appts (not recall)'
            ELSE 'Pats Without Sched Appts'
        END AS 'Category',
        COUNT(DISTINCT p.PatNum) AS '# of Active',
        ROUND(COUNT(DISTINCT p.PatNum) / @ActivePatCount * 100, 1) AS '% of Active'
    FROM patient p
    LEFT JOIN appointment a ON a.PatNum = p.PatNum
    WHERE p.PatStatus = 0
    GROUP BY 
        CASE 
            WHEN a.AptDateTime > CURDATE() AND a.AptStatus = 1 THEN 'Pats With Future Appts Booked'
            WHEN a.AptStatus = 3 THEN 'Pats With Past Due appts (not recall)'
            ELSE 'Pats Without Sched Appts'
        END

    UNION ALL
    SELECT '', '', ''  -- Blank row separator

    -- 8. Patient Status Summary
    UNION ALL
    SELECT 
        CASE PatStatus
            WHEN 0 THEN 'Patient status'
            WHEN 2 THEN 'Inactive status'
            WHEN 3 THEN 'Archived status'
            WHEN 5 THEN 'Deceased status'
            ELSE 'Total Patients'
        END AS 'Category',
        COUNT(*) AS '# of Active',
        ROUND(COUNT(*) / @AllPatCount * 100, 1) AS '% of Active'
    FROM patient
    WHERE PatStatus IN (0,2,3,5)
    GROUP BY PatStatus WITH ROLLUP

) Demographics
ORDER BY Category;

-- Common Usage Examples:
/*
-- For monthly practice analysis
SELECT * FROM patient_demographics 
WHERE Category IN ('New Pats This Month', 'Future Recalls Scheduled');

-- For insurance analysis
SELECT * FROM patient_demographics 
WHERE Category IN ('Insured', 'Uninsured');

-- For age distribution
SELECT * FROM patient_demographics 
WHERE Category LIKE 'ages%';
*/ 