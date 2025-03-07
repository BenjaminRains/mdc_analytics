# Payment Split Pattern Analysis

## Executive Summary

Our analysis has identified a significant anomaly in payment splits beginning July 2024 and escalating dramatically through October-November 2024. The data shows an exponential increase in splits per payment, primarily affecting Type 0 transfers with $0 payment amounts. While stakeholders implemented a "hidden splits" policy in November 2024 to address this issue, our analysis shows that the problem persists despite these changes. The system appears to be generating excessive splits that, while not causing accounting errors, significantly impact system efficiency and data quality.

![Daily Split Count and Ratio](../../images/daily_split_ratio.png)

## Key Findings

1. **Pattern Evolution**:
   - Normal operation (Jan-Jun 2024): 2-10 splits per payment
   - Initial anomalies (Jul 2024): Occasional spikes up to 40 splits per payment
   - Problem escalation (Aug-Oct 2024): Regular spikes of 100-400 splits per payment
   - Peak anomaly (Nov 1, 2024): 457.6 splits per payment
   - Post-policy change (Nov 15-Dec 2024): Continued high split counts (avg 35.75)

2. **Issue Characteristics**:
   - 98.3% of suspicious payments are Type 0 transfers
   - 92.8% of suspicious payments have negative split amounts
   - Most problematic payments show $0.00 payment amount with massive negative splits
   - Three specific claims (2536, 2542, 6519) generate most excessive splits
   - Each affected procedure has exactly 10,348 splits with symmetric amounts

3. **Scale of Impact**:
   - 992 payments affected across 29 days
   - 250,898 suspicious splits generated
   - Top payment (#915894) generated 5,500 splits
   - Payment-split discrepancies exceeding $800,000

![Impact of Policy Change](../../images/policy_change_impact.png)

## Detailed Pattern Analysis

### Normal vs. Abnormal Transfer Patterns

#### Normal Transfer Pattern (Example: PayNum 917342, Dec 27, 2024)
- 12 splits total
- 2.0 splits per procedure
- 6 procedures involved
- Typical business transaction pattern

#### Abnormal Transfer Pattern (Example: PayNum 915884, Nov 1, 2024)
- 4,158 splits
- Multiple splits per procedure (often 100+ per procedure)
- Primarily Type 0 transfers with $0 payment amount
- Massive negative split amounts
- Still nets to $0 as intended

### Payment Type Analysis

The vast majority (98.3%) of problematic payments are Type 0 transfers:

| Payment Type | % of Suspicious Payments |
|--------------|--------------------------|
| Type 0       | 98.3%                    |
| Type 71      | 0.7%                     |
| Other Types  | 1.0%                     |

### Payment-Split Discrepancies

Top 5 payment-split discrepancies show the magnitude of the issue:

1. Payment #915434: $0.00 payment, $-859,064.88 splits, $859,064.88 difference (4,946 splits)
2. Payment #910740: $49,500.00 payment, $891,000.00 splits, $841,500.00 difference (36 splits)
3. Payment #915873: $0.00 payment, $-804,328.20 splits, $804,328.20 difference (3,564 splits)
4. Payment #910580: $47,000.00 payment, $846,000.00 splits, $799,000.00 difference (18 splits)
5. Payment #913762: $43,900.00 payment, $790,200.00 splits, $746,300.00 difference (18 splits)

## System Behavior Progression

The issue shows a clear progression pattern:

| Time Period | Splits per Payment (Avg) | Maximum Splits | % of Suspicious Days |
|-------------|--------------------------|----------------|----------------------|
| Jan-Jun 2024| 5.35                     | 15.7           | 0%                   |
| Jul-Oct 2024| 20.81                    | 412.8          | 7.6%                 |
| Nov-Dec 2024| 35.75                    | 457.6          | 27.3%                |

## Specific Claims Analysis

Three claims (2536, 2542, 6519) are generating the most excessive splits:

- **Claim 2536**: Procedures 61980, 108306 ($122.20 transfer)
  - Each procedure: 10,348 splits, symmetric amounts (-$14,530 to +$14,530)
  
- **Claim 2542**: Procedures 61979, 108309 ($189.20 transfer)
  - Each procedure: 10,348 splits, symmetric amounts (-$14,530 to +$14,530)
  
- **Claim 6519**: Procedure 95856 ($305.00 transfer)
  - 10,348 splits, symmetric amounts (-$14,530 to +$14,530)

Activity concentrated in 6-day period (Oct 30 - Nov 5, 2024)

## Policy Change Assessment

In November 2024, stakeholders implemented a "hidden splits" policy with stricter enforcement of pay split documentation. Our analysis of the policy change effectiveness shows:

- Suspicious days **increased** from 7.6% pre-policy to 27.3% post-policy
- Average splits per payment **increased by 71.7%** (from 20.81 to 35.75)
- December 2024 still shows **4 suspicious days** with a maximum of 278.9 splits per payment
- 9.7% of December payments have >100 splits
- 67.7% of December payments show significant split differences

This suggests the policy change has altered but not resolved the underlying technical issue.

## Business Impact Assessment

1. **No Direct Financial Impact**:
   - All transfers net to $0 as intended
   - Original claim amounts preserved
   - Final accounting is correct
   - Staff able to complete intended transfers
   - No lost or misallocated money

2. **Significant System Inefficiency**:
   - Excessive split generation (250,898+ suspicious splits)
   - Unnecessarily large split amounts
   - Progressive escalation pattern
   - Database bloat from extra records
   - Potential performance impacts

## Root Cause Analysis

The pattern strongly suggests a **system processing error specific to transfer payments**. Evidence points to:

1. **Recursive Split Generation**: When processing Type 0 transfers with $0 amounts, the system appears to be creating recursive or duplicate splits.

2. **Payment-Split Accounting Disconnect**: The system is recording negative split amounts for zero-value payments, creating massive discrepancies.

3. **Configuration Change**: The clear start date (July 1, 2024) suggests a system change or upgrade occurred that introduced this behavior.

4. **Policy Change Complication**: The "hidden splits" policy implementation in November appears to have exacerbated rather than resolved the issue.

## Recommendations

### Immediate Actions

1. **Implement Emergency Filter**: Create validation rule to prevent payments with >20 splits from automatic processing

2. **Reassess "Hidden Splits" Implementation**: Review how the November policy change was technically implemented

3. **Isolate Type 0 Transfers**: Add extra validation specifically for Type 0 payments with $0 amounts

### System Corrections

1. **Review Code Changes**: Examine any payment processing code changes implemented before July 1, 2024

2. **Fix Split Logic**: Correct the logic that's allowing negative split amounts for zero-value payments

3. **Implement Validation Rules**: 
   - Total split amount must equal payment amount
   - Maximum splits per payment should be capped (perhaps at 20)
   - Payment-type specific validation rules

### Monitoring & Prevention

1. **Develop Monitoring Dashboard**: Create daily visualization of split patterns to quickly identify anomalies

2. **Add System Alerts**: Implement automatic notifications when payments exceed split thresholds

3. **Regular Data Quality Checks**: Establish weekly review of split metrics to catch emerging issues

## Conclusion

The payment split anomaly represents a significant system inefficiency that, while not causing direct financial errors, requires immediate technical attention. The current "hidden splits" policy has not resolved the underlying issue and may be contributing to its persistence. A focused technical intervention targeting the split generation logic, particularly for Type 0 transfers, is needed to restore normal system function.