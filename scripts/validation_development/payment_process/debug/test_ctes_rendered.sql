


WITH


TestCTE1 AS (
    SELECT 1 AS id
) 


,

TestCTE2 AS (
    SELECT 2 AS id
) 


SELECT * FROM TestCTE1
JOIN TestCTE2 ON TestCTE1.id <> TestCTE2.id; 