# Payment Process Dashboard

## Overview
The `pay_process_dashboard.sql` query provides a comprehensive dashboard view of payment processing health and integrity. It transforms the raw metrics from the payment processing funnel analysis into business-friendly KPIs and calculated metrics that highlight the completeness, accuracy, and distribution of payment data.

## Purpose
This dashboard serves multiple critical business functions:
- Monitoring the overall health of payment data processing
- Identifying gaps in payment relationships (missing splits, unlinked procedures)
- Tracking payment data integrity issues (split amount mismatches)
- Providing visibility into payment type distribution (insurance, patient, transfers)
- Establishing baseline metrics for process improvement initiatives

## Query Structure
The query builds on the `pay_process_funnel.sql` CTE, which aggregates data from multiple upstream CTEs to create a comprehensive dataset of payment processing metrics. The dashboard query then:

1. Presents core metrics directly from the funnel analysis
2. Renames technical metrics with business-friendly terminology
3. Calculates derived gap metrics (missing splits, unlinked procedures)
4. Computes percentage distributions of payment types
5. Formats everything into a single-row dashboard view

## Field Definitions

### Core Metrics
| Field | Type | Description |
|-------|------|-------------|
| base_count | INT | Total number of payments in the system |
| with_splits | INT | Number of payments that have at least one split |
| with_procedures | INT | Number of payments connected to at least one procedure |
| with_insurance | INT | Number of payments with complete insurance information |

### Renamed Business Metrics
| Field | Type | Description | Source Field |
|-------|------|-------------|-------------|
| valid_patient_payments | INT | Number of direct patient payments with positive amounts | patient_payments |
| internal_transfers | INT | Number of internal transfers (zero amount, no procedures) | transfer_count |
| payment_refunds | INT | Number of refunds (negative amount, no procedures) | refund_count |
| split_amount_mismatches | INT | Payments where split amounts don't match payment amounts | mismatch_count |

### Calculated Gap Metrics
| Field | Type | Description | Calculation |
|-------|------|-------------|------------|
| missing_splits | INT | Payments that have no associated splits | base_count - with_splits |
| unlinked_procedures | INT | Payments with splits that aren't linked to procedures | with_splits - with_procedures |
| avg_splits_per_payment | FLOAT | Average number of splits per payment | Calculated in funnel CTE |

### Percentage Metrics
| Field | Type | Description | Calculation |
|-------|------|-------------|------------|
| pct_insurance | DECIMAL | Percentage of payments that are insurance-based | (with_insurance / base_count) * 100 |
| pct_patient | DECIMAL | Percentage of payments that are patient direct | (patient_payments / base_count) * 100 |
| pct_transfer | DECIMAL | Percentage of payments that are internal transfers | (transfer_count / base_count) * 100 |

## Business Logic Explanations

### Payment Classification Logic
The system classifies payments into several categories:
- **Insurance payments**: Payments with complete insurance information
- **Patient payments**: Payments with positive amounts but no insurance information
- **Internal transfers**: Payments with zero amounts and no procedures
- **Refunds**: Payments with negative amounts and no procedures

### Data Quality Metrics
The dashboard highlights potential data quality issues:
- **Missing splits**: Payments should have at least one split; those without splits may indicate incomplete processing
- **Unlinked procedures**: Splits should link to procedures; those without procedure links may indicate broken relationships
- **Split amount mismatches**: The sum of split amounts should equal the payment amount; discrepancies indicate potential accounting issues

### Percentage Calculations
All percentages are calculated against the total payment count (base_count) to show the relative distribution of different payment types and issues.

## Example Results and Interpretation

A sample row from the results might look like:

base_count: 14328
with_splits: 14125
with_procedures: 13980
with_insurance: 8965
valid_patient_payments: 4870
internal_transfers: 312
payment_refunds: 145
missing_splits: 203
unlinked_procedures: 145
avg_splits_per_payment: 2.7
split_amount_mismatches: 37
pct_insurance: 62.6
pct_patient: 34.0
pct_transfer: 2.2



**Interpretation**: This dashboard shows a generally healthy payment processing system where:
- 98.6% of payments have splits (only 203 missing splits)
- 99.0% of payments with splits are linked to procedures
- Insurance payments make up 62.6% of all payments
- Patient payments account for 34.0% of all payments
- Only 37 payments (0.26%) have split amount mismatches

Areas for potential investigation would be:
1. The 203 payments with missing splits (possible incomplete processing)
2. The 37 payments with split amount mismatches (potential accounting discrepancies)

## Pandas Usage Examples

```python
import pandas as pd
import matplotlib.pyplot as plt

# Load the query results
df = pd.read_csv('pay_process_dashboard_2024-01-01_2025-02-28.csv')

# Since this is a single-row dashboard, we'll work with the first row
dashboard = df.iloc[0]

# Create a bar chart of payment distribution
payment_types = ['Insurance', 'Patient', 'Transfer', 'Refund']
payment_counts = [dashboard['with_insurance'], 
                 dashboard['valid_patient_payments'],
                 dashboard['internal_transfers'],
                 dashboard['payment_refunds']]

plt.figure(figsize=(10, 6))
plt.bar(payment_types, payment_counts, color=['blue', 'green', 'orange', 'red'])
plt.title('Payment Distribution by Type')
plt.ylabel('Count')
plt.tight_layout()
plt.savefig('payment_distribution.png')

# Create a funnel chart of the payment processing stages
stages = ['Total Payments', 'With Splits', 'With Procedures', 'With Insurance']
stage_values = [dashboard['base_count'], 
               dashboard['with_splits'],
               dashboard['with_procedures'], 
               dashboard['with_insurance']]

plt.figure(figsize=(10, 6))
plt.bar(stages, stage_values, color=['darkblue', 'blue', 'royalblue', 'lightblue'])
plt.title('Payment Processing Funnel')
plt.ylabel('Count')
plt.ylim(0, dashboard['base_count'] * 1.1)  # Set y-axis limit to show scale
plt.tight_layout()
plt.savefig('payment_funnel.png')

# Calculate and display key metrics
completion_rate = (dashboard['with_insurance'] + dashboard['valid_patient_payments']) / dashboard['base_count'] * 100
error_rate = (dashboard['missing_splits'] + dashboard['unlinked_procedures'] + dashboard['split_amount_mismatches']) / dashboard['base_count'] * 100

print(f"Payment Processing Completion Rate: {completion_rate:.1f}%")
print(f"Payment Processing Error Rate: {error_rate:.1f}%")
```

## Relationships to Other Queries

This dashboard query relates to several other validation queries:

| Query | Relationship |
|-------|--------------|
| `payment_daily_trend.sql` | Shows the same metrics over time as a time series |
| `payment_type_distribution.sql` | Provides deeper analysis of payment types with more detail |
| `paysplit_anomaly_flat.sql` | Identifies specific problematic payments that may contribute to the error metrics |
| `split_discrepancy_details.sql` | Provides detailed analysis of the split amount mismatches identified in this dashboard |

## Usage Guidelines

### When to Run This Query
- Daily or weekly to monitor overall payment processing health
- Before and after system changes to verify process integrity
- When investigating payment processing issues to establish baseline metrics

### How to Interpret Results
- **High completion rates** (>98% with splits and procedures) indicate healthy processing
- **High mismatch counts** require immediate investigation (accounting implications)
- **Unexpected shifts** in payment type distribution may indicate system or process changes

## Changelog

| Date | Change |
|------|--------|
| 2025-03-07 | Initial documentation created |