-- Core payment records filtered by date range - foundation for payment analysis queries
BasePayments AS (
    SELECT PayNum, PayDate, PayAmt, PayType
    FROM payment 
    WHERE PayDate >= @start_date AND PayDate < @end_date
)