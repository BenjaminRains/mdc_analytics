{% import "cte_macros.sql" as macros %}

{{ macros.begin_ctes() }}
{{ macros.include_cte("payment_level_metrics.sql", True) }}
{{ macros.include_cte("claim_metrics.sql") }}

SELECT p.PayNum, p.PayAmt, cm.claimproc_count
FROM PaymentLevelMetrics p
LEFT JOIN ClaimMetrics cm ON p.PayNum = cm.PayNum
LIMIT 100; 