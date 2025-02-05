# Fee Schedule Analysis Documentation

## Overview
A fee schedule is a comprehensive pricing system that insurance companies use to determine reimbursement rates for dental procedures. Each procedure has a specific code and corresponding fee amount, creating a standardized pricing structure.

## Fee Schedule Types

### Primary Fee Schedules
- **Standard (#55)**
  * Base schedule for standard pricing
  * Average fee: $181.46
  * Highest volume: ~18,600 procedures/year
  * Most consistent pricing structure

- **StandardServices (#54)**
  * Similar to Standard but with specialized services
  * Average fee: $191.08
  * High volume: ~17,500 procedures/year
  * Shifted to increased fees in late 2022

### Insurance Carrier Fee Schedules
- **Cleveland Cliffs (United Concordia) (#8286)**
  * Base range: $140-160
  * Moderate volume: ~13,450 procedures/year
  * Mixed adjustment pattern:
    - 65% increased from base fee
    - 35% reduced from base fee
  * Stable monthly volumes (1200-1400)

- **Liberty (#8291)**
  * Base range: $160-220
  * Volume: ~13,240 procedures/year
  * Strong upward adjustment pattern:
    - Over 90% increased from base fee
    - Very few reductions
  * More volatile monthly volumes

### Employer/Organization Fee Schedules
- **US STEEL (#8278)**
  * Average fee: $162.02
  * Consistent monthly volume
  * ~14,590 procedures/year

- **Methodist Hosp OON (#8274)**
  * Average fee: $193.04
  * Highest organization rate
  * ~14,433 procedures/year

## Fee Determination Process

### Fee Schedule Hierarchy
```
Patient -> Insurance/Employer -> Fee Schedule -> Base Fee
                                           -> Actual ProcFee
```

### Adjustment Patterns
1. **Base Fee**: Initial fee from schedule (fee.Amount)
2. **Adjustments** based on:
   - Insurance requirements
   - Contract terms
   - Seasonal patterns
   - Volume considerations

### Seasonal Trends
- January: Consistent volume dips
- March/August: Peak volumes
- December: Moderate decline
- Yearly patterns remain consistent

## Implementation Details

### Key Tables
- `procedurelog`: Contains actual procedure fees
- `fee`: Defines base fee schedule amounts
- `feesched`: Master fee schedule definitions
- `procedurecode`: Procedure definitions and codes

### Validation Requirements
1. Monitor fee schedule accuracy
2. Track adjustment patterns
3. Validate against contracts
4. Review seasonal variations
5. Check volume reporting

### Common Procedures
- Evaluations: $60-109
- Preventive: $31-108
- Basic diagnostic: $33-76

## Analysis Findings (2021-2023)

### Volume Patterns
- **High Volume** (1600-2000 procedures/month)
  * Standard (#55)
  * StandardServices (#54)
- **Medium Volume** (1000-1400 procedures/month)
  * Organization schedules
  * Insurance schedules

### Fee Variations
- Standard schedules: $181-191
- Organization schedules: $162-193
- Insurance schedules: $151-184

### Key Trends
1. Insurance carriers typically start with lower base fees but show frequent upward adjustments
2. Standard schedules maintain more consistent pricing
3. Seasonal patterns affect all schedule types similarly
4. No significant long-term growth or decline trends observed

## Monitoring and Maintenance
1. Regular validation of fee schedule accuracy
2. Tracking of adjustment patterns
3. Monthly volume analysis
4. Seasonal trend monitoring
5. Contract compliance verification

## Data Analysis Implementation

### SQL Analysis Structure
The fee schedule analysis is implemented through a series of CTEs (Common Table Expressions):

1. **DateRange**: Defines analysis period (2021-2024)
2. **BaseProcedures**: Initial data gathering
   - Joins procedurelog, fee, feesched, and procedurecode
   - Filters for completed procedures
   - Captures base vs actual fees
   - Tracks procedure dates and descriptions

3. **FeeAnalysis**: Calculates key metrics
   - Procedure and patient counts
   - Average, min, and max fees
   - Fee differences:
     * Documented Fee: Original fee schedule amount (fee.Amount)
     * Actual Fee: Final charged amount (pl.ProcFee)
     * Average Difference: Actual - Documented
   - Adjustment tracking:
     * Increased: When actual > documented
     * Reduced: When actual < documented
     * No Change: When actual = documented

4. **ProcedureMix**: Analyzes procedure types
   - Groups by procedure codes
   - Tracks volume by procedure type
   - Calculates fee statistics per procedure
   - Filters for procedures with >10 occurrences

### Key Findings
1. **Cleveland Cliffs Pattern**
   - Documented fees: $170-180
   - Actual fees: $140-160
   - Average difference: -$21.61 (consistently under)
   - Stable monthly volumes

2. **Liberty Pattern**
   - Documented fees: $120-130
   - Actual fees: $160-220
   - Average difference: +$60.00 (consistently over)
   - More volatile monthly volumes

### Data Quality Notes
- Analysis focuses on completed procedures (ProcStatus = 2)
- Minimum threshold of 10 procedures for procedure mix analysis
- Tracks specific fee schedules (55, 54, 8278, 8274, 8286, 8291)
- Direct fee comparison (actual vs documented)
- Consistent patterns suggest intentional pricing strategies

## Data Analysis Implementation

### SQL Analysis Structure
The fee schedule analysis is implemented through a series of CTEs (Common Table Expressions):

1. **DateRange**: Defines analysis period (2021-2024)
2. **BaseProcedures**: Initial data gathering
   - Joins procedurelog, fee, feesched, and procedurecode
   - Filters for completed procedures
   - Captures base vs actual fees
   - Tracks procedure dates and descriptions

3. **FeeAnalysis**: Calculates key metrics
   - Procedure and patient counts
   - Average, min, and max fees
   - Fee differences:
     * Documented Fee: Original fee schedule amount (fee.Amount)
     * Actual Fee: Final charged amount (pl.ProcFee)
     * Average Difference: Actual - Documented
   - Adjustment tracking:
     * Increased: When actual > documented
     * Reduced: When actual < documented
     * No Change: When actual = documented

4. **ProcedureMix**: Analyzes procedure types
   - Groups by procedure codes
   - Tracks volume by procedure type
   - Calculates fee statistics per procedure
   - Filters for procedures with >10 occurrences

### Key Metrics Tracked
1. **Volume Metrics**
   - Monthly procedure counts
   - Unique patient counts
   - Procedure mix distribution

2. **Fee Metrics**
   - Average procedure fees
   - Fee ranges (min/max)
   - Adjustment patterns
   - Variance from scheduled fees

3. **Trend Analysis**
   - Monthly variations
   - Seasonal patterns
   - Year-over-year changes
   - Fee schedule utilization

### Data Quality Notes
- Analysis focuses on completed procedures (ProcStatus = 2)
- Minimum threshold of 10 procedures for procedure mix analysis
- Tracks specific fee schedules (55, 54, 8278, 8274, 8286, 8291)
- Includes all adjustments regardless of reason 