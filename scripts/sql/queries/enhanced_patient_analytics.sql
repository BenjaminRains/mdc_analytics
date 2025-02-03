-- Enhanced Patient Analytics
-- Combines demographics and behavioral scoring for comprehensive patient analysis

-- Initialize parameters and variables
SET @AsOf = CURDATE();
SET @RECALL_WEIGHT = 0.3;
SET @APPOINTMENT_WEIGHT = 0.25;
SET @VISIT_WEIGHT = 0.25;
SET @FINANCIAL_WEIGHT = 0.2;

-- Get special recall types (from demographics)
SELECT GROUP_CONCAT(preference.ValueString)
INTO @SpecialRecallTypes
FROM preference
WHERE preference.PrefName IN (
    'RecallTypeSpecialProphy',
    'RecallTypeSpecialChildProphy',
    'RecallTypeSpecialPerio'
);

-- Main Combined Analysis
SELECT 
    -- Demographic Grouping
    dem.AgeGroup,
    dem.Gender,
    dem.InsuranceStatus,
    
    -- Behavioral Metrics
    beh.RiskCategory,
    beh.RiskScore,
    
    -- Combined Metrics
    COUNT(*) AS PatientCount,
    
    -- Average Scores by Demographic Group
    AVG(beh.RecallScore) AS AvgRecallScore,
    AVG(beh.AppointmentScore) AS AvgAppointmentScore,
    AVG(beh.VisitScore) AS AvgVisitScore,
    AVG(beh.FinancialScore) AS AvgFinancialScore,
    
    -- Risk Distribution
    SUM(CASE WHEN beh.RiskCategory = 'Excellent' THEN 1 ELSE 0 END) AS ExcellentCount,
    SUM(CASE WHEN beh.RiskCategory = 'Good' THEN 1 ELSE 0 END) AS GoodCount,
    SUM(CASE WHEN beh.RiskCategory = 'Fair' THEN 1 ELSE 0 END) AS FairCount,
    SUM(CASE WHEN beh.RiskCategory = 'At Risk' THEN 1 ELSE 0 END) AS AtRiskCount,
    SUM(CASE WHEN beh.RiskCategory = 'High Risk' THEN 1 ELSE 0 END) AS HighRiskCount

FROM (
    -- Demographics Subquery
    SELECT 
        p.PatNum,
        CASE 
            WHEN TIMESTAMPDIFF(YEAR, p.Birthdate, CURDATE()) < 18 THEN 'Under 18'
            WHEN TIMESTAMPDIFF(YEAR, p.Birthdate, CURDATE()) < 30 THEN '18-29'
            WHEN TIMESTAMPDIFF(YEAR, p.Birthdate, CURDATE()) < 50 THEN '30-49'
            WHEN TIMESTAMPDIFF(YEAR, p.Birthdate, CURDATE()) < 70 THEN '50-69'
            ELSE '70+'
        END AS AgeGroup,
        CASE p.Gender 
            WHEN 0 THEN 'Male'
            WHEN 1 THEN 'Female'
            ELSE 'Other'
        END AS Gender,
        CASE WHEN pp.PatPlanNum IS NOT NULL THEN 'Insured' ELSE 'Uninsured' END AS InsuranceStatus
    FROM patient p
    LEFT JOIN patplan pp ON pp.PatNum = p.PatNum
    WHERE p.PatStatus = 0
) dem

INNER JOIN (
    -- Behavior Scoring Subquery (from patient_behavior_scoring.sql)
    SELECT 
        p.PatNum,
        -- ... [Previous behavior scoring logic] ...
        RecallScore,
        AppointmentScore,
        VisitScore,
        FinancialScore,
        RiskScore,
        RiskCategory
    FROM patient p
    -- ... [Previous joins and calculations] ...
) beh ON beh.PatNum = dem.PatNum

GROUP BY 
    dem.AgeGroup,
    dem.Gender,
    dem.InsuranceStatus,
    beh.RiskCategory

-- Additional Analysis Views
UNION ALL

-- Trend Analysis
SELECT 
    DATE_FORMAT(a.AptDateTime, '%Y-%m') AS Month,
    COUNT(DISTINCT p.PatNum) AS PatientCount,
    AVG(beh.RiskScore) AS AvgRiskScore
FROM appointment a
INNER JOIN patient p ON p.PatNum = a.PatNum
INNER JOIN behavior_scores beh ON beh.PatNum = p.PatNum
WHERE a.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY DATE_FORMAT(a.AptDateTime, '%Y-%m')

ORDER BY 
    dem.AgeGroup,
    dem.Gender,
    dem.InsuranceStatus,
    beh.RiskScore DESC;

-- Example: High-Risk Patient Demographics
SELECT 
    dem.AgeGroup,
    COUNT(*) AS PatientCount,
    AVG(beh.RiskScore) AS AvgRiskScore
FROM demographics dem
INNER JOIN behavior_scores beh ON beh.PatNum = dem.PatNum
WHERE beh.RiskCategory IN ('At Risk', 'High Risk')
GROUP BY dem.AgeGroup;

-- Example: Insurance Impact Analysis
SELECT 
    dem.InsuranceStatus,
    AVG(beh.FinancialScore) AS AvgFinancialScore,
    AVG(beh.AppointmentScore) AS AvgAppointmentScore
FROM demographics dem
INNER JOIN behavior_scores beh ON beh.PatNum = dem.PatNum
GROUP BY dem.InsuranceStatus; 