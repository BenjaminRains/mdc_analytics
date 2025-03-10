-- Consolidated payment data foundation CTE
-- Combines: base_payments.sql, payment_details_base.sql, payment_source_categories.sql
-- Note: payment_system_summary.sql elements will be used in a separate analytics/summary CTE

PaymentBase AS (
    SELECT 
        -- Core payment fields from base_payments.sql
        p.PayNum,
        p.PayDate,
        p.PayType,
        p.PayAmt,
        p.PayNote,
        
        -- Split and claim details from payment_details_base.sql
        ps.SplitNum,
        ps.SplitAmt,
        ps.ProcNum,
        cp.ClaimNum,
        
        -- Source categorization logic from payment_source_categories.sql
        CASE 
            WHEN p.PayType IN (417, 574, 634) THEN 'Insurance'
            WHEN p.PayType = 0 THEN 'Transfer'
            WHEN p.PayType = 72 THEN 'Refund'
            WHEN EXISTS (
                SELECT 1 
                FROM paysplit ps2
                JOIN claimproc cp2 ON ps2.ProcNum = cp2.ProcNum
                WHERE ps2.PayNum = p.PayNum 
                  AND cp2.Status IN (1, 2, 4, 6)
            ) THEN 'Insurance'
            ELSE 'Patient'
        END as payment_source,
        
        -- Additional payment method categorization
        CASE 
            WHEN p.PayType IN (417, 574, 634) THEN 'Insurance'
            WHEN p.PayType IN (69, 70, 71) THEN 'Check/Cash'
            WHEN p.PayType IN (391, 412) THEN 'Card/Online'
            WHEN p.PayType = 72 THEN 'Refund'
            WHEN p.PayType = 0 THEN 'Transfer'
            ELSE 'Other'
        END AS payment_method
    FROM payment p
    -- Left joins ensure we get all payments even if they don't have splits
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    LEFT JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
    LEFT JOIN claim c ON cp.ClaimNum = c.ClaimNum
    WHERE p.PayDate >= @start_date AND p.PayDate < @end_date
)