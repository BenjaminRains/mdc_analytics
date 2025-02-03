# Monthly Adjustment Analysis Report
# ================================

# 1. Overall Adjustment Volume and Value
SELECT 
    COUNT(*) as TotalAdjustments,
    COUNT(DISTINCT PatNum) as UniquePatients,
    ROUND(SUM(AdjAmt), 2) as TotalAdjustmentAmount,
    ROUND(AVG(AdjAmt), 2) as AvgAdjustmentAmount
FROM adjustment
WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH);

# 2. AdjType Distribution and Financial Impact
SELECT 
    AdjType,
    COUNT(*) as Count,
    COUNT(DISTINCT PatNum) as UniquePatients,
    ROUND(AVG(AdjAmt), 2) as AvgAmount,
    ROUND(SUM(AdjAmt), 2) as TotalAmount,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) 
        FROM adjustment 
        WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)), 2) as PercentageOfTotal
FROM adjustment
WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
GROUP BY AdjType
ORDER BY Count DESC;


# 4. Daily Adjustment Patterns
SELECT 
    DATE(AdjDate) as AdjustmentDate,
    COUNT(*) as TotalAdjustments,
    COUNT(DISTINCT PatNum) as UniquePatients,
    ROUND(SUM(AdjAmt), 2) as TotalAmount,
    COUNT(DISTINCT AdjType) as UniqueAdjTypes
FROM adjustment
WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
GROUP BY DATE(AdjDate)
ORDER BY AdjustmentDate;

# 5. Multi-Procedure Adjustment Analysis
SELECT 
    a.AdjType,
    COUNT(DISTINCT a.AdjNum) as AdjustmentCount,
    ROUND(AVG(ABS(a.AdjAmt)), 2) as AvgAdjustmentAmount,
    COUNT(DISTINCT pl.CodeNum) as UniqueProcedureCodes,
    COUNT(pl.ProcNum) as TotalProcedureLinks,
    ROUND(COUNT(pl.ProcNum) * 1.0 / COUNT(DISTINCT a.AdjNum), 1) as AvgProcsPerAdjustment
FROM adjustment a
LEFT JOIN procedurelog pl ON a.PatNum = pl.PatNum 
    AND pl.ProcDate BETWEEN DATE_SUB(a.AdjDate, INTERVAL 30 DAY) AND a.AdjDate
WHERE a.AdjDate >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
GROUP BY a.AdjType
HAVING AdjustmentCount > 5
ORDER BY AvgAdjustmentAmount DESC;

# 6. Note Usage Analysis
SELECT 
    AdjType,
    COUNT(*) as TotalAdjustments,
    SUM(CASE WHEN TRIM(AdjNote) = '' THEN 1 ELSE 0 END) as EmptyNotes,
    SUM(CASE WHEN TRIM(AdjNote) != '' THEN 1 ELSE 0 END) as NotesPresent,
    ROUND(SUM(CASE WHEN TRIM(AdjNote) != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as NoteUsagePercentage,
    ROUND(AVG(AdjAmt), 2) as AvgAmount
FROM adjustment
WHERE AdjDate >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
GROUP BY AdjType
HAVING TotalAdjustments > 5
ORDER BY TotalAdjustments DESC; 