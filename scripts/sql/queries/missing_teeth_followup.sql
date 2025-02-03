/*
Missing Teeth Analysis Query
Purpose: Identifies and categorizes patients with missing teeth for implant treatment planning
Last Modified: 2024-03-21

Key Components:
1. Patient Selection: Active patients only (PatStatus = 0)
2. Tooth Status: Uses InitialType = 0 from toothinitial table for missing teeth
3. Excludes wisdom teeth (1,16,17,32)
4. Provides detailed tooth position descriptions
5. Categorizes implant candidacy based on number and position of missing teeth

Tooth Numbering System (Universal 1-32):
- Upper arch: 1-16 (right to left)
- Lower arch: 17-32 (left to right)
- Key positions:
  * Anterior teeth: 7-10 (upper), 23-26 (lower)
  * First molars: 3,14 (upper), 19,30 (lower)
  * Canines: 6,11 (upper), 22,27 (lower)
*/

WITH missing_teeth AS (
    SELECT
        p.PatNum,
        -- Patient name formatting with NULL handling
        CONCAT(
            COALESCE(TRIM(p.LName), ''), ', ',
            COALESCE(TRIM(p.FName), '')
        ) AS PatientName,
        -- Convert ToothNum to CHAR before concatenation
        GROUP_CONCAT(
            CAST(ti.ToothNum AS CHAR) ORDER BY ti.ToothNum
        ) AS MissingTeeth,
        -- Basic counts for treatment planning
        COUNT(ti.ToothNum) AS MissingTeethCount,
        -- Additional counts for specific regions
        SUM(CASE WHEN ti.ToothNum IN (7,8,9,10,23,24,25,26) THEN 1 ELSE 0 END) as AnteriorCount,
        SUM(CASE WHEN ti.ToothNum IN (3,14,19,30) THEN 1 ELSE 0 END) as FirstMolarCount
    FROM patient p
    INNER JOIN toothinitial ti ON p.PatNum = ti.PatNum
    WHERE ti.InitialType = 0                     -- Missing teeth (from validation: 57,872 records)
        AND ti.ToothNum NOT IN (1,16,17,32)     -- Exclude wisdom teeth
        AND p.PatStatus = 0                      -- Active patients only (from validation: 5,472 patients)
    GROUP BY 
        p.PatNum,
        p.LName,
        p.FName
)
SELECT 
    missing_teeth.*,
    -- Treatment recommendations based on validated criteria
    CASE
        WHEN MissingTeethCount = 1 THEN 'Single Tooth Implant Candidate'
        WHEN MissingTeethCount BETWEEN 2 AND 3 AND MissingTeeth REGEXP '7|8|9|10' THEN 'Anterior Bridge/Implant Candidate'
        WHEN MissingTeethCount BETWEEN 2 AND 4 THEN 'Multiple Implant Candidate'
        WHEN MissingTeethCount > 4 AND MissingTeethCount < 10 THEN 'Full Arch Implant Candidate'
        WHEN MissingTeethCount >= 10 THEN 'All-on-4/6 Candidate'
        ELSE 'Review Needed'
    END as ImplantRecommendation,
    -- Specific indicators for treatment planning
    CASE
        WHEN MissingTeeth REGEXP '7|8|9|10' THEN 'Yes'
        ELSE 'No'
    END as HasMissingAnteriorTeeth,
    CASE
        WHEN MissingTeeth REGEXP '3|14|19|30' THEN 'Yes'
        ELSE 'No'
    END as HasMissingFirstMolars
FROM missing_teeth
ORDER BY 
    -- Prioritization based on clinical significance
    CASE
        WHEN MissingTeethCount = 1 THEN 1                                         -- Single tooth cases first
        WHEN MissingTeethCount BETWEEN 2 AND 3 AND MissingTeeth REGEXP '7|8|9|10' THEN 2  -- Anterior cases second
        WHEN MissingTeethCount BETWEEN 2 AND 4 THEN 3                            -- Multiple implants third
        WHEN MissingTeethCount > 4 AND MissingTeethCount < 10 THEN 4            -- Full arch cases fourth
        WHEN MissingTeethCount >= 10 THEN 5                                      -- All-on-4/6 cases last
        ELSE 6
    END,
    MissingTeethCount,
    HasMissingAnteriorTeeth DESC;