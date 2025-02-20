# Treatment Journey ML Analysis TODO

## 1. Data Validation Analysis

### A. Threshold Sensitivity Analysis
```sql
-- Create view to test different thresholds
WITH ThresholdTests AS (
    SELECT 
        ProcNum,
        ProcFee,
        total_paid,
        CASE WHEN total_paid >= ProcFee * 0.90 THEN 1 ELSE 0 END as threshold_90,
        CASE WHEN total_paid >= ProcFee * 0.95 THEN 1 ELSE 0 END as threshold_95,
        CASE WHEN total_paid >= ProcFee * 0.98 THEN 1 ELSE 0 END as threshold_98
    FROM PaymentActivity
)
```
- [x] Run analysis for 90%, 95%, and 98% thresholds
- [x] Compare success rates across thresholds
- [x] Identify edge cases at each threshold
- [x] Document patterns in "almost successful" cases

### B. Payment Split Analysis
- [x] Calculate success rates by split pattern
- [x] Analyze correlation between split complexity and success
- [x] Review high-split cases (>15 splits)
- [x] Document typical split patterns for successful cases

### C. Adjustment Pattern Analysis
- [x] Categorize common adjustment types
- [x] Calculate success rates with/without adjustments
- [x] Identify "normal" vs "concerning" adjustment patterns
- [x] Review large adjustments impact on success

## 2. Business Logic Validation

### A. Zero-Fee Procedure Context
- [x] Analyze bundled procedures
- [x] Track zero-fee success in relation to paid procedures
- [x] Document common zero-fee + paid procedure combinations
- [ ] Propose bundled success criteria refinements based on 40.1% success rate

### B. Payment Type Patterns
- [x] Compare direct-pay vs insurance success patterns
- [x] Analyze combined payment type success factors
- [ ] Document typical payment timing patterns
- [ ] Review prepayment impact on success

### C. Edge Case Review
- [x] List all cases within 2% of threshold
- [ ] Review small balance write-offs
- [x] Analyze insurance rounding patterns
- [ ] Document processing fee impacts

## 3. NEW: Advanced Analysis Needed

### A. Temporal Success Patterns
- [ ] Analyze time between procedure and payment completion
- [ ] Identify seasonal payment pattern variations
- [ ] Study impact of payment delays on success
- [ ] Review success rates by day of week/month

### B. Provider Impact Analysis
- [ ] Compare success rates across providers
- [ ] Analyze provider-specific payment patterns
- [ ] Study provider fee variation impact
- [ ] Document provider-specific adjustment patterns

### C. Insurance Plan Analysis
- [ ] Detailed analysis of 84.3% insurance success rate
- [ ] Compare success rates by insurance plan type
- [ ] Study insurance estimate accuracy
- [ ] Document plan-specific payment patterns

### D. Complex Split Investigation
- [ ] Analyze why complex splits (99.4%) outperform normal splits
- [ ] Document successful complex split patterns
- [ ] Study timing of split payments
- [ ] Review patient characteristics in complex splits

## 4. Model Development Plan

### A. Initial Model Testing
- [ ] Create baseline model with updated target definition
- [ ] Analyze misclassifications with new thresholds
- [ ] Document feature importance with split patterns
- [ ] Test prediction stability across payment types

### B. Target Definition Iterations
- [ ] Test separate targets for direct vs insurance payments
- [ ] Evaluate bundled procedure specific targets
- [ ] Compare model performance with adjustment-aware targets
- [ ] Validate against updated business rules

### C. Feature Engineering
- [ ] Create payment pattern features based on findings
- [ ] Add temporal success indicators
- [ ] Include adjustment pattern features
- [ ] Test bundled procedure features with 40.1% context

## 5. Documentation Updates

### A. Update Analysis Documentation
- [x] Document threshold analysis results
- [x] Update payment pattern definitions
- [x] Add adjustment type classifications
- [x] Document success criteria changes

### B. Code Updates
- [x] Refine target definition
- [x] Add validation checks
- [x] Update success criteria
- [ ] Add documentation for new findings

### C. Business Rules Documentation
- [x] Document final success criteria
- [x] Add example cases
- [x] Include validation rules
- [ ] Document exceptions based on new findings

## Next Steps
1. ~~Begin with threshold sensitivity analysis~~
2. ~~Review results with stakeholders~~
3. ~~Update target definition based on findings~~
4. Focus on temporal success patterns
5. Investigate provider impact
6. Analyze insurance plan variations
7. Study complex split success factors

## Questions to Answer
1. ~~What defines a "normal" payment pattern?~~
2. ~~How should bundled procedures be handled?~~
3. ~~Which adjustment types indicate success/failure?~~
4. Why do complex splits show higher success rates?
5. What drives insurance payment timing?
6. How do provider patterns affect success?
7. What characteristics define successful bundled procedures?

## Success Metrics
- ~~Clear, documented success criteria~~
- ~~Stakeholder-approved target definition~~
- ~~Validated against historical data~~
- Stable model performance across payment types
- ~~Documented edge cases and handling~~ 