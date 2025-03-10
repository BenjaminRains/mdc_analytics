-- System-wide payment metrics summary
-- Using the consolidated PaymentBase CTE as data foundation
-- Renamed from PaymentBaseCounts to better reflect its purpose
{% include "payment_base.sql" %}
PaymentSystemSummary AS (
SELECT
'system_summary' as metric,
-- Basic counts
COUNT(DISTINCT pb.PayNum) as total_payments,
COUNT(pb.SplitNum) as total_splits,
COUNT(DISTINCT pb.ProcNum) as total_procedures,
-- Financial metrics
SUM(DISTINCT pb.PayAmt) as total_payment_amount,
AVG(DISTINCT pb.PayAmt) as avg_payment_amount,
-- Payment quality indicators
COUNT(DISTINCT CASE WHEN pb.PayAmt < 0 THEN pb.PayNum END) as negative_payments,
COUNT(DISTINCT CASE WHEN pb.PayAmt = 0 THEN pb.PayNum END) as zero_payments,
-- Date range
MIN(pb.PayDate) as min_date,
MAX(pb.PayDate) as max_date,
-- Ratios and averages
CAST(COUNT(pb.SplitNum) AS FLOAT) /
NULLIF(COUNT(DISTINCT pb.PayNum), 0) as avg_splits_per_payment,
COUNT(DISTINCT pb.ProcNum) * 1.0 /
NULLIF(COUNT(DISTINCT pb.PayNum), 0) as avg_procedures_per_payment,
-- Source breakdown
COUNT(DISTINCT CASE WHEN pb.payment_source = 'Insurance' THEN pb.PayNum END) as insurance_payments,
COUNT(DISTINCT CASE WHEN pb.payment_source = 'Patient' THEN pb.PayNum END) as patient_payments,
COUNT(DISTINCT CASE WHEN pb.payment_source = 'Transfer' THEN pb.PayNum END) as transfer_payments,
COUNT(DISTINCT CASE WHEN pb.payment_source = 'Refund' THEN pb.PayNum END) as refund_payments
FROM PaymentBase pb
GROUP BY 'system_summary'
)