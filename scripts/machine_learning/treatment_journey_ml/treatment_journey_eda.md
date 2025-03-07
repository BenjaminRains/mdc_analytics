# Treatment Journey Analysis
Analysis of patient treatment journey success factors and predictive modeling.

## Dataset Overview
- Total records: 23,257
- Success rate: 73.62%
- Journey outcomes:
  - Completed and paid: 17,121
  - In planning: 6,009
  - Cancelled or missed: 127

## Key Features
Most important predictors of treatment success:

### Returning Patients
1. CompletedCount (50.13%)
2. PlannedCount (8.56%)
3. DaysFromPlanToProc (8.08%)
4. Fee amount (5.30%)
5. PatientAge (5.05%)

Model Performance:
- Accuracy: 97%
- Precision: 96-97%
- Recall: 91-99%

### New Patients (First Procedure)
1. Procedure category D9 (37.63%)
2. UCR_Difference (15.45%)
3. Fee amount (14.34%)
4. Estimated insurance (10.27%)
5. Same-day treatment (5.55%)

Success Rate: 99.04%

## Risk Factors

### Returning Patients
High risk indicators:
- Low completion history
- Short planning windows
- Higher fees
- Limited procedure category experience

### New Patients
Risk factors for cancellation/missed appointments:
- Younger age (avg 34.7 vs 46.8 years)
- Lower fees ($50 vs $266)
- Same-day treatment
- No planning window

## Insurance Impact
- Has Insurance: 77.16% success
- No Insurance: 62.33% success
- Exception: First procedures show slightly higher success without insurance (99.49% vs 98.92%)

## Planning Window
- Successful journeys average 56.47 days planning window
- Cancelled/missed appointments often same-day
- Longer planning windows correlate with higher success rates

## Recommendations

### Process Improvements
1. Optimize planning windows (~56 days)
2. Avoid same-day treatments for new patients
3. Provide extra support for:
   - High-fee procedures
   - Patients with limited history
   - Younger patients

### Risk Management
1. Screen based on completion history
2. Consider fee levels in risk assessment
3. Monitor procedure category experience
4. Age-specific support strategies

### Data Quality
1. Review success criteria for new patients
2. Validate procedure category outcomes
3. Consider more granular outcome measures

## Model Applications
1. Risk scoring at treatment planning
2. Resource allocation based on risk levels
3. Customized support strategies
4. Planning window optimization

## Future Analysis
1. Age/planning window relationship
2. Procedure-specific success factors
3. Insurance impact by procedure type
4. Risk scoring system refinement