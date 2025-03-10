# Payment Split Analysis - Duplicate Joins Query

## Overview
The `duplicate_joins_flat.sql` query identifies problematic payment splits in the dental practice management system. It focuses on detecting payments that may have been incorrectly split across procedures, resulting in accounting discrepancies or potential data integrity issues.

## Purpose
This query serves several key purposes:
- Identify payments with suspicious splitting patterns
- Detect financial discrepancies between payments and their splits
- Track known problematic claims (specifically claims 2536, 2542, 6519)
- Prioritize potential issues for further investigation

## Query Structure
The query uses a hierarchical CTE structure:
1. Base data collection (`PaymentLevelMetrics`, `ClaimMetrics`)
2. Analysis layer (`PaymentSplitAnalysis`, `ProblemClaimDetails`)
3. Specific problem analysis (`ProblemClaimAnalysis`)
4. Consolidated results with prioritization

## Field Definitions

### Core Fields
| Field | Type | Description |
|-------|------|-------------|
| record_type | VARCHAR | Indicates source of record ('Payment' or 'Claim') |
| PayNum | INT | Unique payment identifier |
| PayDate | DATE | Date the payment was recorded |
| payment_category | VARCHAR | Classification of payment (Insurance, Check/Cash, Card/Online, etc.) |
| split_count | INT | Number of splits created from this payment |
| PayAmt | DECIMAL | Original payment amount |
| total_split_amount | DECIMAL | Sum of all split amounts |
| split_difference | DECIMAL | Absolute difference between PayAmt and total_split_amount |

### Analysis Fields
| Field | Type | Description |
|-------|------|-------------|
| has_known_oversplit_claims | BOOLEAN | Flag indicating payment involves known problematic claims |
| is_suspicious | BOOLEAN | Flag for payments meeting suspicious criteria (high split count with discrepancy) |
| claim_nums | VARCHAR | Comma-separated list of claim numbers associated with this payment |
| common_claim_count | INT | Count of known problematic claims associated with payment |
| claimproc_count | INT | Total count of claim procedures linked to this payment |

## Business Logic Explanations

### Payment Categorization
Payments are categorized based on PayType into:
- Insurance (PayType 417, 574, 634)
- Check/Cash (PayType 69, 70, 71)
- Card/Online (PayType 391, 412)
- Refund (PayType 72)
- Transfer (PayType 0)
- Other (all other PayTypes)

### Suspicious Payment Detection
Payments are flagged as suspicious when:
- They have more than 5 splits AND
- The difference between payment amount and total split amount exceeds $1

### Known Oversplit Detection
Payments are flagged as having known oversplit claims when:
- They have more than 1 split AND
- The number of claim procedures is at least double the split count

### Problem Claim Tracking
The query specifically tracks claims 2536, 2542, and 6519, which have been identified as problematic based on prior analysis.

## Example Results and Interpretation

A sample row from the results might look like:

```
record_type: Payment
PayNum: 12345
PayDate: 2024-02-15
payment_category: Insurance
split_count: 8
has_known_oversplit_claims: 1
is_suspicious: 1
claim_nums: 2536,6702,8901
common_claim_count: 1
PayAmt: 1250.00
total_split_amount: 1252.50
split_difference: 2.50
claimproc_count: 18
```

**Interpretation**: This insurance payment has been split 8 times but is linked to 18 claim procedures, suggesting over-splitting. It involves one known problematic claim (#2536), has a $2.50 discrepancy between payment and splits, and has been flagged as suspicious. This would be a high-priority case for investigation.

## Pandas Usage Examples

```python
import pandas as pd
import matplotlib.pyplot as plt

# Load the query results
df = pd.read_csv('duplicate_joins_flat_2024-01-01_2025-02-28.csv')

# Basic statistics on split counts
split_stats = df.groupby('payment_category')['split_count'].agg(['mean', 'median', 'max', 'count'])
print(split_stats)

# Analyze suspicious payments
suspicious = df[df['is_suspicious'] == 1]
print(f"Found {len(suspicious)} suspicious payments out of {len(df)} total payments ({len(suspicious)/len(df)*100:.2f}%)")

# Visualize split difference by payment category for suspicious payments
plt.figure(figsize=(10, 6))
suspicious.boxplot(column='split_difference', by='payment_category')
plt.title('Split Differences by Payment Category (Suspicious Payments Only)')
plt.suptitle('')  # Remove default title
plt.ylabel('Amount Difference ($)')
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig('suspicious_payment_differences.png')

# Correlation between split_count and claimproc_count
print(f"Correlation between split count and claim procedure count: {df['split_count'].corr(df['claimproc_count']):.3f}")
```

## Relationships to Other Queries

This query relates to several other validation queries:

| Query | Relationship |
|-------|--------------|
| `payment_type_distribution.sql` | Provides broader context on payment types that can be joined with this analysis |
| `split_discrepancy_details.sql` | Offers deeper dive into specific split discrepancies identified here |
| `claim_payment_ratios.sql` | Analyzes relationship between claims and payments from a different perspective |
| `provider_payment_patterns.sql` | Can identify if certain providers are associated with problematic splits |

## Changelog

| Date | Change |
|------|--------|
| 2025-03-07 | Initial documentation created |
