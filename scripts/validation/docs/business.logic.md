## Fee Schedule System

### Fee Schedule Usage (2024 Analysis)

1. **Primary Fee Schedules**
   - Standard (#55):
     * 18,633 procedures (documented: 20,724)
     * Average fee: $181.46
     * Variance from documented: -10.1%
   - StandardServices (#54):
     * 17,498 procedures (documented: 19,672)
     * Average fee: $191.08
     * Variance from documented: -11.1%

2. **Employer/Organization Fee Schedules**
   - US STEEL (#8278):
     * 14,590 procedures
     * Average fee: $162.02
     * Consistent monthly volume
   - Methodist Hosp OON (#8274):
     * 14,433 procedures
     * Average fee: $193.04
     * Highest organization rate

3. **Insurance Carrier Fee Schedules**
   - Cleveland Cliffs (#8286):
     * 13,451 procedures
     * Documented avg: $170-180
     * Actual avg: $151.78
     * Historical range: $140-160
     * Average undercharge: $21.61
     * Adjustment patterns:
       - More reductions than increases
       - Consistent undercharging pattern
   - Liberty (#8291):
     * 13,240 procedures
     * Documented avg: $120-130
     * Actual avg: $184.32
     * Historical range: $160-220
     * Average overcharge: $60.00
     * Adjustment patterns:
       - Almost exclusively increases
       - Consistent overcharging pattern

### Fee Schedule Patterns

1. **Historical Trends (2021-2024)**
   - Cleveland Cliffs:
     * Lower volatility
     * Consistently charges below documented fees
     * Average $21.61 below fee schedule
   - Liberty:
     * Higher volatility
     * Consistently charges above documented fees
     * Average $60.00 above fee schedule

2. **Seasonal Patterns**
   - Volume dips in January
   - Peak volumes in March and August
   - Year-end (December) shows moderate decline
   - Consistent cyclical patterns year over year

3. **Fee Structure**
   - Standard schedules: $181-191
   - Organization schedules: $162-193
   - Insurance schedules: $151-184
   - Most common procedures:
     * Evaluations: $60-109
     * Preventive: $31-108
     * Basic diagnostic: $33-76

### Implementation Details

1. **Fee Determination Process**
   - Base fee from fee schedule (fee.Amount)
   - Adjustments applied based on:
     * Insurance requirements
     * Contract terms
     * Seasonal patterns
     * Volume considerations

2. **Fee Schedule Hierarchy**
   ```
   Patient -> Insurance/Employer -> Fee Schedule -> Base Fee
                                              -> Actual ProcFee
   ```

3. **Validation Requirements**
   - Monitor fee schedule accuracy
   - Track adjustment patterns
   - Validate against contracts
   - Review seasonal variations
   - Check volume reporting

### Key Relationships
- Procedures (procedurelog) link to fees through CodeNum
- Fee schedules (feesched) define pricing structure
- Organizations may have multiple fee schedules
- Insurance plans tied to specific fee schedules
- Patient assignments determine applicable fees

### Fee Schedule Implementation

1. **ProcFee Determination**
   - ProcFee in procedurelog represents final charged amount
   - Base fee comes from fee schedule (fee.Amount)
   - Actual ProcFee may differ from fee schedule amount due to:
     * Insurance adjustments
     * Provider discretion
     * Special circumstances
     * Package pricing

2. **Fee Schedule Hierarchy**
   ```
   Patient -> Insurance/Employer -> Fee Schedule -> Base Fee
                                              -> Actual ProcFee
   ```

### Data Patterns

1. **Fee Variations**
   - Standard schedules show consistent pricing ($181-191)
   - Organization schedules vary moderately:
     * Highest: Methodist Hosp OON ($193.04)
     * Lowest: US STEEL ($162.02)
   - Insurance carriers show expected variation:
     * Cleveland Cliffs ($151.78)
     * Liberty ($184.32)

2. **Usage Volume**
   - Volume tiers observed:
     * High: Standard/StandardServices (1600-2000 procedures/month)
     * Medium: Organization schedules (1000-1400 procedures/month)
     * Stable: Insurance schedules (1000-1400 procedures/month)
   - Consistent seasonal patterns across all schedules
   - No significant long-term growth or decline trends
   - Predictable monthly variations
