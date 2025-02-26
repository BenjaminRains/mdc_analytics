-- BasePayments: Pre-filter base payments based on the defined date range.
-- Date filter: 2024-01-01 to 2025-01-01
BasePayments AS (
    SELECT PayNum, PayDate, PayAmt, PayType
    FROM payment 
    WHERE PayDate >= '2024-01-01' AND PayDate < '2025-01-01'
)