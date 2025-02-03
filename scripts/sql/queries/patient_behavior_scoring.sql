-- Patient Behavior Scoring Analysis
-- Extends demographics analysis with behavioral scoring metrics

-- Initialize base counts (same as original)
SELECT COUNT(*) INTO @ActivePatCount FROM patient WHERE PatStatus = 0;

-- Create scoring weights
SET @RECALL_WEIGHT = 0.3;        -- 30% importance
SET @APPOINTMENT_WEIGHT = 0.25;   -- 25% importance
SET @VISIT_WEIGHT = 0.25;        -- 25% importance
SET @FINANCIAL_WEIGHT = 0.2;     -- 20% importance

-- Main Patient Behavior Analysis
SELECT 
    p.PatNum,
    CONCAT(p.LName, ', ', p.FName) AS PatientName,
    
    -- 1. Recall Compliance Score (0-100)
    CASE 
        WHEN r.DateScheduled > CURDATE() THEN 100  -- Future recall scheduled
        WHEN r.DateDue > DATE_SUB(CURDATE(), INTERVAL 1 MONTH) THEN 80  -- Recently due
        WHEN r.DateDue > DATE_SUB(CURDATE(), INTERVAL 3 MONTH) THEN 60  -- Overdue 1-3 months
        WHEN r.DateDue > DATE_SUB(CURDATE(), INTERVAL 6 MONTH) THEN 40  -- Overdue 3-6 months
        WHEN r.DateDue IS NOT NULL THEN 20  -- Severely overdue
        ELSE 0  -- No recall
    END AS RecallScore,
    
    -- 2. Appointment Reliability Score (0-100)
    (
        SELECT 100 - (
            -- Count broken appointments from appointment status
            SELECT COUNT(DISTINCT a.AptNum)
            FROM appointment a 
            WHERE a.PatNum = p.PatNum 
                AND a.AptDateTime > DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
                AND a.AptStatus = 5  -- Broken/Missed appointment
        ) * 20
        LIMIT 100  -- Cap at 100 points
    ) AS AppointmentScore,
    
    -- 3. Visit Frequency Score (0-100)
    CASE 
        WHEN TIMESTAMPDIFF(MONTH, LastVisit.VisitDate, CURDATE()) <= 6 THEN 100
        WHEN TIMESTAMPDIFF(MONTH, LastVisit.VisitDate, CURDATE()) <= 12 THEN 80
        WHEN TIMESTAMPDIFF(MONTH, LastVisit.VisitDate, CURDATE()) <= 18 THEN 60
        WHEN TIMESTAMPDIFF(MONTH, LastVisit.VisitDate, CURDATE()) <= 24 THEN 40
        WHEN LastVisit.VisitDate IS NOT NULL THEN 20
        ELSE 0
    END AS VisitScore,
    
    -- 4. Financial Responsibility Score (0-100)
    CASE 
        WHEN FinancialHistory.BalanceRatio <= 0.1 THEN 100  -- Excellent payment history
        WHEN FinancialHistory.BalanceRatio <= 0.2 THEN 80   -- Good payment history
        WHEN FinancialHistory.BalanceRatio <= 0.3 THEN 60   -- Fair payment history
        WHEN FinancialHistory.BalanceRatio <= 0.4 THEN 40   -- Poor payment history
        ELSE 20  -- Very poor payment history
    END AS FinancialScore,
    
    -- 5. Composite Risk Score (0-100)
    ROUND(
        (RecallScore * @RECALL_WEIGHT) +
        (AppointmentScore * @APPOINTMENT_WEIGHT) +
        (VisitScore * @VISIT_WEIGHT) +
        (FinancialScore * @FINANCIAL_WEIGHT)
    ) AS RiskScore,
    
    -- 6. Risk Category
    CASE 
        WHEN RiskScore >= 90 THEN 'Excellent'
        WHEN RiskScore >= 75 THEN 'Good'
        WHEN RiskScore >= 60 THEN 'Fair'
        WHEN RiskScore >= 40 THEN 'At Risk'
        ELSE 'High Risk'
    END AS RiskCategory

FROM patient p
LEFT JOIN (
    -- Get last visit date
    SELECT 
        PatNum,
        MAX(AptDateTime) AS VisitDate
    FROM appointment 
    WHERE AptStatus = 2  -- Completed
    GROUP BY PatNum
) LastVisit ON LastVisit.PatNum = p.PatNum

LEFT JOIN (
    -- Calculate payment history ratio
    SELECT 
        PatNum,
        SUM(CASE WHEN DatePay <= DueDate THEN 1 ELSE 0 END) / COUNT(*) AS BalanceRatio
    FROM ledger
    WHERE DatePay IS NOT NULL
    GROUP BY PatNum
) FinancialHistory ON FinancialHistory.PatNum = p.PatNum

LEFT JOIN recall r ON r.PatNum = p.PatNum 
    AND FIND_IN_SET(r.RecallTypeNum, @SpecialRecallTypes)
    AND r.IsDisabled = 0

WHERE p.PatStatus = 0  -- Active patients only
ORDER BY RiskScore DESC; 