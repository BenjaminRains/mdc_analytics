-- Debug query to examine specific procedures and their aging
WITH ProcedureBalances AS (
    SELECT 
        pl.ProcNum,
        pl.ProcDate,
        pl.ProcFee,
        -- Payments
        COALESCE(
            (SELECT SUM(SplitAmt) 
             FROM paysplit 
             WHERE ProcNum = pl.ProcNum 
             AND DatePay < '2024-01-01'), 
            0
        ) as payment_amt,
        
        -- Insurance
        COALESCE(
            (SELECT SUM(InsPayAmt) 
             FROM claimproc 
             WHERE ProcNum = pl.ProcNum 
             AND Status = 1 
             AND ProcDate < '2024-01-01'), 
            0
        ) as insurance_amt,
        
        -- Adjustments
        COALESCE(
            (SELECT SUM(CASE WHEN AdjAmt > 0 THEN AdjAmt ELSE 0 END)
             FROM adjustment 
             WHERE ProcNum = pl.ProcNum 
             AND AdjDate < '2024-01-01'), 
            0
        ) as positive_adj_amt,
        
        COALESCE(
            (SELECT SUM(CASE WHEN AdjAmt < 0 THEN AdjAmt ELSE 0 END)
             FROM adjustment 
             WHERE ProcNum = pl.ProcNum 
             AND AdjDate < '2024-01-01'), 
            0
        ) as negative_adj_amt,
        
        -- Insurance estimate
        (SELECT InsPayEst 
         FROM claimproc 
         WHERE ProcNum = pl.ProcNum 
         AND Status = 1 
         AND ProcDate < '2024-01-01'
         ORDER BY ProcDate DESC 
         LIMIT 1) as insurance_estimate,
        
        -- Latest activity
        GREATEST(
            pl.ProcDate,
            COALESCE(
                (SELECT MAX(DatePay) 
                 FROM paysplit 
                 WHERE ProcNum = pl.ProcNum 
                 AND DatePay < '2024-01-01'
                 AND SplitAmt != 0), 
                pl.ProcDate
            ),
            COALESCE(
                (SELECT MAX(ProcDate) 
                 FROM claimproc 
                 WHERE ProcNum = pl.ProcNum 
                 AND Status = 1 
                 AND ProcDate < '2024-01-01'
                 AND InsPayAmt != 0), 
                pl.ProcDate
            ),
            COALESCE(
                (SELECT MAX(AdjDate) 
                 FROM adjustment 
                 WHERE ProcNum = pl.ProcNum 
                 AND AdjDate < '2024-01-01'
                 AND AdjAmt != 0), 
                pl.ProcDate
            )
        ) as last_activity_date
    FROM procedurelog pl
    WHERE pl.ProcStatus = 2
        AND pl.ProcDate >= '2023-01-01'
        AND pl.ProcDate < '2024-01-01'
        AND pl.ProcFee > 0
        AND pl.ProcFee <= 10000  -- Filter out unusually large fees
),
DuplicateCheck AS (
    SELECT 
        ProcDate,
        ProcFee,
        COUNT(*) as proc_count,
        SUM(ProcFee) as total_fee
    FROM procedurelog
    WHERE ProcStatus = 2
        AND ProcDate >= '2023-01-01'
        AND ProcDate < '2024-01-01'
    GROUP BY ProcDate, ProcFee
    HAVING COUNT(*) > 1
),
IssueSummary AS (
    SELECT 
        'Large Negative Adjustments' as issue_type,
        COUNT(*) as count,
        SUM(ABS(negative_adj_amt)) as total_amount
    FROM ProcedureBalances
    WHERE ABS(negative_adj_amt) > ProcFee
    UNION ALL
    SELECT 
        'Large Unpaid Fees',
        COUNT(*),
        SUM(ProcFee)
    FROM ProcedureBalances
    WHERE ProcFee > 5000 
    AND payment_amt = 0 
    AND insurance_amt = 0
    UNION ALL
    SELECT 
        'Possible Duplicates',
        COUNT(*),
        SUM(ProcFee)
    FROM ProcedureBalances pb
    WHERE EXISTS (
        SELECT 1 
        FROM DuplicateCheck dc 
        WHERE dc.ProcDate = pb.ProcDate 
        AND dc.ProcFee = pb.ProcFee
    )
)
-- First query: Overall summary
SELECT * FROM IssueSummary
ORDER BY total_amount DESC;

-- Second query: Duplicate details
WITH DuplicateCheck AS (
    SELECT 
        ProcDate,
        ProcFee,
        COUNT(*) as proc_count,
        SUM(ProcFee) as total_fee
    FROM procedurelog
    WHERE ProcStatus = 2
        AND ProcDate >= '2023-01-01'
        AND ProcDate < '2024-01-01'
    GROUP BY ProcDate, ProcFee
    HAVING COUNT(*) > 1
)
SELECT 
    ProcDate,
    ProcFee,
    proc_count as duplicate_count,
    total_fee as duplicate_total
FROM DuplicateCheck
WHERE proc_count > 5  -- Show dates with more than 5 duplicates
ORDER BY total_fee DESC
LIMIT 10;

-- Third query: Pattern Analysis
WITH ProcedureBalances AS (
    SELECT 
        pl.ProcNum,
        pl.ProcDate,
        pl.ProcFee,
        -- Payments
        COALESCE(
            (SELECT SUM(SplitAmt) 
             FROM paysplit 
             WHERE ProcNum = pl.ProcNum 
             AND DatePay < '2024-01-01'), 
            0
        ) as payment_amt,
        
        -- Insurance
        COALESCE(
            (SELECT SUM(InsPayAmt) 
             FROM claimproc 
             WHERE ProcNum = pl.ProcNum 
             AND Status = 1 
             AND ProcDate < '2024-01-01'), 
            0
        ) as insurance_amt,
        
        -- Adjustments
        COALESCE(
            (SELECT SUM(CASE WHEN AdjAmt > 0 THEN AdjAmt ELSE 0 END)
             FROM adjustment 
             WHERE ProcNum = pl.ProcNum 
             AND AdjDate < '2024-01-01'), 
            0
        ) as positive_adj_amt,
        
        COALESCE(
            (SELECT SUM(CASE WHEN AdjAmt < 0 THEN AdjAmt ELSE 0 END)
             FROM adjustment 
             WHERE ProcNum = pl.ProcNum 
             AND AdjDate < '2024-01-01'), 
            0
        ) as negative_adj_amt,
        
        -- Insurance estimate
        (SELECT InsPayEst 
         FROM claimproc 
         WHERE ProcNum = pl.ProcNum 
         AND Status = 1 
         AND ProcDate < '2024-01-01'
         ORDER BY ProcDate DESC 
         LIMIT 1) as insurance_estimate,
        
        -- Latest activity
        GREATEST(
            pl.ProcDate,
            COALESCE(
                (SELECT MAX(DatePay) 
                 FROM paysplit 
                 WHERE ProcNum = pl.ProcNum 
                 AND DatePay < '2024-01-01'
                 AND SplitAmt != 0), 
                pl.ProcDate
            ),
            COALESCE(
                (SELECT MAX(ProcDate) 
                 FROM claimproc 
                 WHERE ProcNum = pl.ProcNum 
                 AND Status = 1 
                 AND ProcDate < '2024-01-01'
                 AND InsPayAmt != 0), 
                pl.ProcDate
            ),
            COALESCE(
                (SELECT MAX(AdjDate) 
                 FROM adjustment 
                 WHERE ProcNum = pl.ProcNum 
                 AND AdjDate < '2024-01-01'
                 AND AdjAmt != 0), 
                pl.ProcDate
            )
        ) as last_activity_date
    FROM procedurelog pl
    WHERE pl.ProcStatus = 2
        AND pl.ProcDate >= '2023-01-01'
        AND pl.ProcDate < '2024-01-01'
        AND pl.ProcFee > 0
        AND pl.ProcFee <= 10000  -- Filter out unusually large fees
),
PatternAnalysis AS (
    SELECT 
        CASE 
            WHEN ProcFee = 1950 THEN '$1,950 Procedures'
            WHEN ProcFee = 1288 THEN '$1,288 Procedures'
            WHEN ProcFee >= 5000 THEN 'Large Fee Procedures'
            ELSE 'Other Procedures'
        END as procedure_category,
        COUNT(*) as procedure_count,
        SUM(ProcFee) as total_fee,
        SUM(CASE WHEN payment_amt = 0 AND insurance_amt = 0 THEN 1 ELSE 0 END) as unpaid_count,
        SUM(CASE WHEN ABS(negative_adj_amt) > ProcFee THEN 1 ELSE 0 END) as large_adj_count,
        COUNT(DISTINCT ProcDate) as distinct_dates,
        AVG(ProcFee) as avg_fee
    FROM ProcedureBalances
    GROUP BY 
        CASE 
            WHEN ProcFee = 1950 THEN '$1,950 Procedures'
            WHEN ProcFee = 1288 THEN '$1,288 Procedures'
            WHEN ProcFee >= 5000 THEN 'Large Fee Procedures'
            ELSE 'Other Procedures'
        END
)
SELECT * FROM PatternAnalysis
ORDER BY total_fee DESC;

-- Fourth query: Negative Adjustment Analysis
WITH LargeNegativeAdjustments AS (
    SELECT 
        a.ProcNum,
        pl.ProcDate,
        pl.ProcFee,
        a.AdjDate,
        a.AdjAmt,
        ABS(a.AdjAmt) / pl.ProcFee as adjustment_ratio,
        -- Get the next and previous adjustments
        LAG(a.AdjAmt) OVER (PARTITION BY a.ProcNum ORDER BY a.AdjDate) as prev_adjustment,
        LEAD(a.AdjAmt) OVER (PARTITION BY a.ProcNum ORDER BY a.AdjDate) as next_adjustment
    FROM adjustment a
    JOIN procedurelog pl ON pl.ProcNum = a.ProcNum
    WHERE a.AdjAmt < 0 
    AND ABS(a.AdjAmt) > pl.ProcFee
    AND pl.ProcDate >= '2023-01-01'
    AND pl.ProcDate < '2024-01-01'
)
SELECT 
    ProcNum,
    ProcDate,
    ProcFee,
    AdjDate,
    AdjAmt as negative_adjustment,
    adjustment_ratio as times_larger_than_fee,
    prev_adjustment,
    next_adjustment,
    CASE 
        WHEN prev_adjustment IS NOT NULL OR next_adjustment IS NOT NULL THEN 'Multiple Adjustments'
        WHEN adjustment_ratio >= 10 THEN 'Likely Decimal Error'
        ELSE 'Needs Review'
    END as likely_issue
FROM LargeNegativeAdjustments
ORDER BY ABS(AdjAmt) DESC;

-- Fifth query: Duplicate Entry Analysis
WITH DuplicateGroups AS (
    SELECT 
        ProcDate,
        ProcFee,
        COUNT(*) as entry_count,
        GROUP_CONCAT(ProcNum ORDER BY ProcNum) as proc_numbers,
        MIN(ProcNum) as first_entry,
        MAX(ProcNum) as last_entry,
        DATEDIFF(MAX(ProcNum), MIN(ProcNum)) as id_spread
    FROM procedurelog
    WHERE ProcStatus = 2
        AND ProcDate >= '2023-01-01'
        AND ProcDate < '2024-01-01'
        AND ProcFee IN (1950, 1288)  -- Focus on the two most duplicated amounts
    GROUP BY ProcDate, ProcFee
    HAVING COUNT(*) > 2
)
SELECT 
    ProcDate,
    ProcFee,
    entry_count,
    proc_numbers,
    first_entry,
    last_entry,
    id_spread,
    CASE 
        WHEN id_spread <= 10 THEN 'Batch Entry'
        WHEN id_spread > 1000 THEN 'Scattered Entry'
        ELSE 'Mixed Pattern'
    END as entry_pattern
FROM DuplicateGroups
ORDER BY entry_count DESC, ProcDate;

-- Sixth query: Detailed records
WITH ProcedureBalances AS (
    SELECT 
        pl.ProcNum,
        pl.ProcDate,
        pl.ProcFee,
        -- Payments
        COALESCE(
            (SELECT SUM(SplitAmt) 
             FROM paysplit 
             WHERE ProcNum = pl.ProcNum 
             AND DatePay < '2024-01-01'), 
            0
        ) as payment_amt,
        
        -- Insurance
        COALESCE(
            (SELECT SUM(InsPayAmt) 
             FROM claimproc 
             WHERE ProcNum = pl.ProcNum 
             AND Status = 1 
             AND ProcDate < '2024-01-01'), 
            0
        ) as insurance_amt,
        
        -- Adjustments
        COALESCE(
            (SELECT SUM(CASE WHEN AdjAmt > 0 THEN AdjAmt ELSE 0 END)
             FROM adjustment 
             WHERE ProcNum = pl.ProcNum 
             AND AdjDate < '2024-01-01'), 
            0
        ) as positive_adj_amt,
        
        COALESCE(
            (SELECT SUM(CASE WHEN AdjAmt < 0 THEN AdjAmt ELSE 0 END)
             FROM adjustment 
             WHERE ProcNum = pl.ProcNum 
             AND AdjDate < '2024-01-01'), 
            0
        ) as negative_adj_amt,
        
        -- Insurance estimate
        (SELECT InsPayEst 
         FROM claimproc 
         WHERE ProcNum = pl.ProcNum 
         AND Status = 1 
         AND ProcDate < '2024-01-01'
         ORDER BY ProcDate DESC 
         LIMIT 1) as insurance_estimate,
        
        -- Latest activity
        GREATEST(
            pl.ProcDate,
            COALESCE(
                (SELECT MAX(DatePay) 
                 FROM paysplit 
                 WHERE ProcNum = pl.ProcNum 
                 AND DatePay < '2024-01-01'
                 AND SplitAmt != 0), 
                pl.ProcDate
            ),
            COALESCE(
                (SELECT MAX(ProcDate) 
                 FROM claimproc 
                 WHERE ProcNum = pl.ProcNum 
                 AND Status = 1 
                 AND ProcDate < '2024-01-01'
                 AND InsPayAmt != 0), 
                pl.ProcDate
            ),
            COALESCE(
                (SELECT MAX(AdjDate) 
                 FROM adjustment 
                 WHERE ProcNum = pl.ProcNum 
                 AND AdjDate < '2024-01-01'
                 AND AdjAmt != 0), 
                pl.ProcDate
            )
        ) as last_activity_date
    FROM procedurelog pl
    WHERE pl.ProcStatus = 2
        AND pl.ProcDate >= '2023-01-01'
        AND pl.ProcDate < '2024-01-01'
        AND pl.ProcFee > 0
        AND pl.ProcFee <= 10000  -- Filter out unusually large fees
),
DuplicateCheck AS (
    SELECT 
        ProcDate,
        ProcFee,
        COUNT(*) as proc_count
    FROM procedurelog
    WHERE ProcStatus = 2
        AND ProcDate >= '2023-01-01'
        AND ProcDate < '2024-01-01'
    GROUP BY ProcDate, ProcFee
    HAVING COUNT(*) > 1
),
DetailedRecords AS (
    SELECT 
        pb.*,
        (pb.ProcFee - pb.payment_amt - pb.insurance_amt + pb.negative_adj_amt - pb.positive_adj_amt) as balance,
        CASE
            WHEN DATEDIFF('2024-01-01', last_activity_date) <= 30 THEN 'Current'
            WHEN DATEDIFF('2024-01-01', last_activity_date) BETWEEN 31 AND 60 THEN '30-60 Days'
            WHEN DATEDIFF('2024-01-01', last_activity_date) BETWEEN 61 AND 90 THEN '60-90 Days'
            ELSE '90+ Days'
        END as aging_bucket,
        CASE 
            WHEN insurance_estimate > 0 THEN 'Insurance'
            ELSE 'Patient'
        END as ar_type,
        CASE 
            WHEN ABS(negative_adj_amt) > ProcFee THEN 'Large Negative Adjustment'
            WHEN ProcFee > 5000 AND payment_amt = 0 AND insurance_amt = 0 THEN 'Large Unpaid Fee'
            WHEN EXISTS (
                SELECT 1 FROM DuplicateCheck dc 
                WHERE dc.ProcDate = pb.ProcDate 
                AND dc.ProcFee = pb.ProcFee
            ) THEN 'Possible Duplicate'
            ELSE NULL
        END as issue_flag
    FROM ProcedureBalances pb
    WHERE (pb.ProcFee - pb.payment_amt - pb.insurance_amt + pb.negative_adj_amt - pb.positive_adj_amt) != 0
)
SELECT 
    *,
    -- Add transaction details back
    (SELECT GROUP_CONCAT(CONCAT(DatePay, ': ', SplitAmt) SEPARATOR '; ')
     FROM paysplit 
     WHERE ProcNum = DetailedRecords.ProcNum 
     AND DatePay < '2024-01-01') as payment_details,
    (SELECT GROUP_CONCAT(CONCAT(ProcDate, ': ', InsPayAmt) SEPARATOR '; ')
     FROM claimproc 
     WHERE ProcNum = DetailedRecords.ProcNum 
     AND Status = 1 
     AND ProcDate < '2024-01-01') as insurance_details,
    (SELECT GROUP_CONCAT(CONCAT(AdjDate, ': ', AdjAmt) SEPARATOR '; ')
     FROM adjustment 
     WHERE ProcNum = DetailedRecords.ProcNum 
     AND AdjDate < '2024-01-01') as adjustment_details
FROM DetailedRecords
ORDER BY ABS(balance) DESC
LIMIT 100; 