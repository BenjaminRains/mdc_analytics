# Treatment Journey ML Analysis

## Overview
This script analyzes dental procedures from planning through payment completion to identify successful treatment journeys. It considers multiple factors including payments, insurance claims, adjustments, and procedure types.

## Key Components

### 1. Excluded Procedures
```sql
WITH ExcludedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
        '~GRP~', 'D9987', 'D9986',  -- Notes and cancellations
        'Watch', 'Ztoth',           -- Monitoring
        'D0350',                    -- Photos
        '00040', 'D2919',          -- Post-proc
        '00051'                     -- Scans
        -- ... other administrative codes
    )
)
```
**Business Input Needed**: 
- Are there other procedure codes that should be excluded?
- Should any current exclusions be considered clinical procedures?

### 2. Payment Success Definition
Based on empirical analysis:
- Direct payments: 98.5% success rate with 95% threshold
- Insurance payments: 84.3% success rate with 90% threshold
- Complex splits (4-15 splits): 99.4% success rate
- Bundled procedures: 40.1% success rate
- Zero-fee procedures: Differentiated by administrative vs clinical

### 3. Payment Categories
The script categorizes payments into:
- Direct only (98.5% success)
- Insurance only (84.3% success)
- Both payment types
- No payment
- Administrative zero-fee
- Clinical zero-fee

**Business Input Needed**:
- Are these categories meaningful for your analysis?
- Should we track prepayments differently?
- How should we categorize payment plans? (payment plans are not currently tracked)

### 4. Payment Split Analysis
```sql
PaymentSplitMetrics AS (
    SELECT 
        ps.ProcNum,
        COUNT(*) as split_count,
        CASE 
            WHEN COUNT(*) BETWEEN 1 AND 3 THEN 'normal_split'
            WHEN COUNT(*) BETWEEN 4 AND 15 THEN 'complex_split'
            WHEN COUNT(*) > 15 THEN 'review_needed'
            ELSE 'no_splits'
        END as split_pattern
    FROM paysplit ps
    GROUP BY ps.ProcNum
)
```
- Normal splits (1-3): Standard success rates
- Complex splits (4-15): Higher success rate (99.4%)
- Review needed (>15): Requires manual review

**Business Input Needed**:
- Are these split count ranges appropriate?
- Should high split counts affect success criteria?
- How should we handle split payments across multiple procedures?

### 5. Insurance Validation
```sql
InsuranceAccuracy AS (
    SELECT 
        cp.ProcNum,
        cp.InsPayEst,
        cp.InsPayAmt,
        CASE
            WHEN cp.InsPayAmt = cp.InsPayEst THEN 'exact_match'
            WHEN cp.InsPayAmt > cp.InsPayEst THEN 'over_estimate'
            WHEN cp.InsPayAmt < cp.InsPayEst THEN 'under_estimate'
            ELSE 'no_estimate'
        END as estimate_accuracy
    FROM claimproc cp
    WHERE cp.Status = 1  -- Only active claims
)
```
**Business Input Needed**:
- How should insurance estimate accuracy affect success criteria?
- Should we handle in-network vs out-of-network claims differently?
- What insurance payment patterns need special attention?

## Current Success Rates (Updated)
- Overall success rate: 47.9%
- Direct payment success: 98.5%
- Insurance payment success: 84.3%
- Complex split success: 99.4%
- Bundled procedure success: 40.1%

## Areas Under Investigation

### 1. Temporal Analysis
- Payment timing patterns
- Seasonal variations
- Day-of-week effects
- Payment delay impact

### 2. Provider Impact
- Provider-specific success rates
- Fee variation effects
- Adjustment patterns by provider

### 3. Insurance Plan Analysis
- Plan-specific success rates
- Estimate accuracy
- Payment timing patterns

### 4. Complex Split Success
- Why complex splits outperform
- Patient characteristics
- Payment timing patterns

## Validation Plan

### 1. Data-Driven Validation
- Threshold sensitivity analysis (completed)
- Payment pattern analysis (completed)
- Adjustment impact analysis (completed)
- Temporal pattern analysis (in progress)

### 2. Business Logic Validation
- Zero-fee context (completed)
- Adjustment impact (completed)
- Edge cases (in progress)
- Provider patterns (planned)

### 3. Stakeholder Validation
- Success definition workshop (completed)
- Business rule confirmation (completed)
- Exception handling (in progress)
- New pattern review (planned)

## Next Steps
1. Complete temporal analysis
2. Investigate provider impact
3. Analyze insurance plan variations
4. Study complex split success factors
5. Refine bundled procedure criteria

## Success Metrics
1. Clear success criteria (completed)
2. Stakeholder approval (completed)
3. Historical validation (completed)
4. Model stability (in progress)
5. Pattern documentation (in progress)

## Understanding Payment Thresholds

### Current Approach
We use a 95% threshold for considering a procedure "paid in full". This means:
- A $1000 procedure is "successful" at $950+ paid
- A $200 procedure is "successful" at $190+ paid
- A $50 procedure is "successful" at $47.50+ paid

### Threshold Tradeoffs

#### Higher Threshold (e.g., 98%)
**Pros:**
- More accurate representation of "fully paid"
- Stricter financial compliance
- Clearer revenue tracking

**Cons:**
- May mark legitimate cases as failures
  * Small balance write-offs
  * Insurance rounding differences
  * Payment processing fees
- Could understate practice performance
- Might not reflect patient satisfaction

#### Lower Threshold (e.g., 90%)
**Pros:**
- More forgiving of routine adjustments
- Better matches practical payment patterns
- Accounts for common insurance variations

**Cons:**
- Risk of normalizing underpayment
- Could mask collection issues
- May overstate financial performance

### Real-World Examples

1. **Insurance Rounding** ($999.99 paid on $1000)
   - Currently: Marked as failure
   - Business Impact: Should this 1¢ difference matter?

2. **Credit Card Fees** ($970 net on $1000)
   - Currently: Marked as failure
   - Business Impact: Processing fees are a normal cost

3. **Small Balance Write-offs** ($195 paid on $200)
   - Currently: Marked as failure
   - Business Impact: Is collecting $5 worth the effort?

### Business Questions to Consider

1. **Balance vs Efficiency**
   - What's the cost of collecting small balances?
   - At what point is a balance "too small" to pursue?

2. **Payment Type Considerations**
   - Should insurance payments have different thresholds?
   - How do processing fees affect our success definition?

3. **Practice Goals**
   - Is revenue maximization the primary goal?
   - How do we balance financial and patient satisfaction metrics?

## Questions for Review

1. **Payment Thresholds**
   - Should we adjust the 95% threshold for "paid in full"?
   - Do we need different thresholds for different payment types?
   - How should we handle small remaining balances?

2. **Zero-Fee Procedures**
   - What determines if a zero-fee procedure is clinical vs administrative?
   - Should zero-fee procedures be linked to related paid procedures?
   - Are there specific zero-fee procedures that should always be successful?

3. **Adjustment Handling**
   - Which adjustment types should not affect success status?
   - How should we handle large adjustments?
   - Should certain adjustment patterns trigger review?

4. **Payment Patterns**
   - What defines a normal vs complex payment pattern?
   - How should we handle prepayments and payment plans?
   - What payment splits need special attention?

## Validation Plan

### 1. Data-Driven Validation

#### A. Threshold Sensitivity Analysis
```sql
WITH ThresholdImpact AS (
    SELECT 
        CASE 
            WHEN payment_ratio >= 0.98 THEN 'strict_98'
            WHEN payment_ratio >= 0.95 THEN 'current_95'
            WHEN payment_ratio >= 0.90 THEN 'lenient_90'
            ELSE 'below_90'
        END as threshold_category,
        COUNT(*) as case_count,
        AVG(CASE WHEN target_journey_success = 1 THEN 1.0 ELSE 0.0 END) as success_rate
    FROM treatment_journey_results
    GROUP BY 1
)
```
- Analyze impact of different thresholds
- Identify edge cases at threshold boundaries
- Review business impact of threshold changes

#### B. Payment Pattern Analysis
```sql
WITH PaymentPatterns AS (
    SELECT 
        payment_category,
        split_pattern,
        COUNT(*) as case_count,
        AVG(target_journey_success) as success_rate,
        AVG(payment_ratio) as avg_payment_ratio
    FROM treatment_journey_results
    GROUP BY 1, 2
)
```
- Document typical successful payment patterns
- Identify problematic payment combinations
- Validate split pattern classifications

### 2. Business Logic Validation

#### A. Zero-Fee Context
- Review bundled procedures
- Analyze related procedure success rates
- Validate administrative vs clinical classification

#### B. Adjustment Impact
- Categorize adjustment types
- Measure success rate by adjustment pattern
- Identify legitimate vs problematic adjustments

#### C. Edge Cases
- Small balance write-offs
- Processing fee impacts
- Insurance rounding differences
- Complex split patterns

### 3. Stakeholder Validation

#### A. Success Definition Workshop
Present analysis of:
- Current success rates by category
- Threshold impact analysis
- Edge case examples
- Payment pattern distributions

#### B. Business Rule Confirmation
Validate:
- Payment thresholds
- Adjustment handling
- Zero-fee criteria
- Split pattern rules

#### C. Exception Handling
Document:
- Legitimate exceptions
- Required overrides
- Special case handling
- Review processes

### 4. Model Validation

#### A. Initial Model Testing
- Build baseline model
- Analyze feature importance
- Review misclassifications
- Test prediction stability

#### B. Target Definition Impact
- Compare model versions
- Measure business impact
- Document performance changes
- Validate against rules

## Success Metrics

### 1. Data Quality Metrics
- Coverage of all procedure types
- Consistent success rates across categories
- Minimal unexplained failures
- Clear edge case handling

### 2. Business Alignment
- Stakeholder approval of criteria
- Alignment with practice goals
- Clear documentation
- Reproducible results

### 3. Model Performance
- Stable predictions
- Interpretable results
- Actionable insights
- Reliable feature importance

## Next Steps
1. Execute validation plan
2. Review results with stakeholders
3. Update success criteria
4. Document final rules
5. Deploy validated model 