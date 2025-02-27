## Procedure Status (procedurelog.ProcStatus)

### Status Values and Meanings
NOTE: The UI shows **Status: ExstCurPro, ExstOther, Referred, Condition**

1. **ProcStatus = 1: Treatment Planned** (20.38%)
   - Represents planned/scheduled procedures
   - No completion dates (0% have DateComplete)
   - 25.18% have appointment links
   - Can be linked to appointments with various statuses
   - Treatment plan dates are rare (2.30% have TreatPlanDate)

2. **ProcStatus = 2: Completed** (51.67%)
   - Represents completed procedures
   - 100% have completion dates
   - High appointment linkage (90.67% have appointments)
   - Makes up majority of all procedures
   - Strong data consistency (no completion date anomalies)

3. **ProcStatus = 3: Administrative/Documentation** (6.00%)
   - Almost exclusively zero-fee procedures (99.96%)
   - No appointment links (0%)
   - No completion dates (0%)
   - Used for administrative documentation rather than actual procedures
   - Primarily "Group Note" entries

4. **ProcStatus = 4: Existing Prior** (0.48%)
   - Average fee: $246.30 (lower than historical average of ~$740)
   - No appointment links (0%)
   - No completion dates (0%)
   - Represents pre-existing conditions or historical procedures
   - Usage has decreased significantly

5. **ProcStatus = 5: Referred** (1.71%)
   - No appointment links (0%)
   - Very low completion date rate (0.94%)
   - Used for procedures referred to external providers
   - Usage has increased from historical 0.33%

6. **ProcStatus = 6: Ordered/Planned** (15.83%)
   - Average fee: $204.05 (consistent with historical ~$208)
   - No appointment links (0%)
   - Very low completion date rate (0.74%)
   - Very low treatment plan date rate (0.46%)
   - Usage has increased from historical 7.23%
   - Used for:
     - Preventive care (fluoride, cleanings, evaluations)
     - Diagnostic procedures (X-rays)
     - Major treatments awaiting scheduling

7. **ProcStatus = 7: Condition** (3.88%)
   - No appointment links (0%)
   - No completion dates (0%)
   - Likely represents declined treatment plans
   - Usage has increased from historical 1.03%

8. **ProcStatus = 8: In Progress** (0.05%)
   - Very rarely used (consistent with historical data)
   - No appointment links (0%)
   - No completion dates (0%)

### Current Distribution (2024 Dataset)
- Status 1: 20.38% (↑ from 6.55%)
- Status 2: 51.67% (↓ from 75.44%)
- Status 3: 6.00% (↑ from 4.31%)
- Status 4: 0.48% (↓ from 5.05%)
- Status 5: 1.71% (↑ from 0.33%)
- Status 6: 15.83% (↑ from 7.23%)
- Status 7: 3.88% (↑ from 1.03%)
- Status 8: 0.05% (≈ 0.06%)

### Key Data Quality Patterns

1. **Completion Dates**
   - Only Status 2 consistently has completion dates (100%)
   - Status 5 and 6 have very low completion dates (<1%)
   - All other statuses have 0% completion dates

2. **Appointment Linkage**
   - Status 2 has highest appointment linkage (90.67%)
   - Status 1 has moderate appointment linkage (25.18%)
   - All other statuses have 0% appointment linkage

3. **Treatment Plan Dates**
   - Generally low across all statuses
   - Status 1 (Treatment Planned): only 2.30%
   - Status 6 (Ordered/Planned): only 0.46%

4. **Fee Patterns**
   - Status 3: Almost exclusively zero-fee (99.96%)
   - Status 4: Average fee $246.30
   - Status 6: Average fee $204.05

### Notable Changes from Historical Data
1. Significant increase in Treatment Planned (Status 1)
2. Decrease in Completed procedures (Status 2)
3. Increase in Ordered/Planned procedures (Status 6)
4. Decrease in average fees for Status 4
5. General shift toward more planning statuses

## Appointment Status (appointment.AptStatus)

### Status Values and Distribution
Based on complete dataset analysis:

1. **AptStatus = 1: Scheduled** (2.75%)
   - 4,390 appointments
   - 1,507 unique patients
   - Date range: 2020-04-24 to 2026-02-03
   - 4,313 linked procedures (15 completed)
   - Used for future appointments

2. **AptStatus = 2: Completed** (86.05%)
   - 137,480 appointments
   - 7,227 unique patients
   - Date range: 2016-02-29 to 2025-01-03
   - 115,934 linked procedures (115,928 completed)
   - Primary status for successful visits

3. **AptStatus = 3: Unspecified** (3.85%)
   - 6,153 appointments
   - 2,211 unique patients
   - Date range: 2020-04-27 to 2025-06-20
   - 5,763 linked procedures

4. **AptStatus = 5: Broken/Missed** (5.03%)
   - 8,041 appointments
   - 3,022 unique patients
   - Date range: 2017-01-06 to 2025-01-03
   - 5,894 linked procedures
   - Only 3 appointments have completed procedures (confirmed anomaly)

5. **AptStatus = 6: Unscheduled** (2.31%)
   - 3,695 appointments
   - 1,716 unique patients
   - Date range: 2020-04-28 to 2025-01-03
   - No linked procedures
   - All have specific times set (potential data anomaly)

6. **AptStatus = 8: Unknown** (<0.01%)
   - 1 appointment
   - 1 unique patient
   - Single occurrence on 2020-05-06
   - No linked procedures

### Data Quality Observations
1. No appointments are incorrectly marked as completed with future dates
2. 487 past appointments remain marked as scheduled (requires attention)
3. All 3,695 unscheduled appointments (Status 6) have specific times set
4. Only 3 broken appointments (0.037%) have completed procedures
5. Status 4 (ASAP) and 7 (WebSched) exist in the schema but are not used

### Key Relationships
- Completed appointments (Status 2):
  - Make up vast majority (86.05%) of all appointments
  - Have highest ratio of linked procedures
  - Almost all linked procedures are marked as completed
- Scheduled appointments (Status 1):
  - Small percentage of total (2.75%)
  - Include some future dates up to 2026
  - Few completed procedures (possibly data entry timing issues)
- Broken appointments (Status 5):
  - Moderate number of linked procedures
  - Very rare to have completed procedures (only 3 cases)

## Missed and Cancelled Appointments

### Recording Methods

1. **Appointment Status (AptStatus = 5)**
   - Used to mark broken/missed appointments in the appointment table
   - Represents immediate no-shows or same-day breaks

2. **Procedure Codes**
   - D9986/626 (Missed Appointments)
   - D9987/627 (Cancelled Appointments)
   - Status Distribution:
     - ~85% recorded with ProcStatus = 2 (Completed)
     - ~15% recorded with ProcStatus = 6 (Ordered/Planned)
     - Rare cases with other ProcStatus values

### Key Relationships
- Two separate tracking systems:
  1. AptStatus = 5 for immediate broken appointments
  2. Procedure codes (D9986/D9987) for administrative recording
- Both systems should be considered for complete missed/cancelled appointment analysis
- No significant overlap between the two methods
- Cancellations (D9987) are more common than missed appointments (D9986)

## Adjustment Table Analysis

### AdjType Categories and Patterns

1. **High-Value Complex Cases**
   - AdjTypes: 616, 550
   - Average amounts: $2,000-$5,600
   - Typically involve 6-7 procedures
   - Often link to multiple procedure types (diagnostic, surgical, consultations)

2. **Routine Multi-Procedure Adjustments**
   - AdjTypes: 188, 474
   - High volume (188: 1,033 adjustments, 474: 338 adjustments)
   - Moderate amounts ($200-550 average)
   - Link to 7-8 procedures on average
   - Most common types by volume

3. **Bulk Processing Adjustments**
   - AdjType: 482
   - Moderate amounts (~$287)
   - Highest procedure linkage (11.4 procedures per adjustment average)
   - Maximum of 23 procedures per adjustment
   - Used for complex multi-procedure cases

4. **Small Value Adjustments**
   - AdjType: 186
   - High volume (420 adjustments)
   - Low amount ($18.58 average)
   - Moderate procedure linkage (4.9 average)

### Note Patterns
- Most AdjTypes (80-100%) don't require notes
- Notable exception: AdjType 235 (only 67% empty notes)
- When present, notes are often standardized (e.g., "FIXED FEE ADJUSTMENT")
- Notes are supplementary information, not primary tracking

### Procedure Relationships
- Large adjustments can link to multiple procedures on same day
- Example: -$27,730 adjustment linking to 14 unique procedures
- Common procedure combinations:
  - Diagnostic codes (D0xxx)
  - Surgical procedures (D7xxx)
  - Consultations (D9xxx)
  - Preventive/Basic procedures (D1xxx, D2xxx)

### Financial Impact
- Most common AdjTypes (474, 188) handle largest total dollar amounts
- Consistent patterns by type:
  - Some types consistently negative (write-offs/adjustments down)
  - Some types consistently positive (additions/adjustments up)
  - Amount ranges are consistent within AdjTypes

### Business Logic Summary
1. AdjType is the primary control field determining:
   - Expected amount ranges
   - Typical number of linked procedures
   - Whether notes are typically required
2. Notes are optional supplementary information
3. Procedures and adjustments have a many-to-many relationship
4. Different adjustment types serve specific business purposes:
   - Bulk processing
   - Routine adjustments
   - Complex case handling
   - Small value corrections 

## Tooth Status Tracking

### ToothInitial Table Status Types (InitialType)

1. **InitialType = 0: Missing Teeth**
   - 57,872 total records
   - 10,682 unique patients
   - Used to mark permanently missing teeth
   - Excludes wisdom teeth in implant analysis
   - Primary indicator for implant candidacy

2. **InitialType = 1: Primary Teeth**
   - 3,595 records
   - 868 unique patients
   - Indicates deciduous/baby teeth
   - Not typically considered for implant planning

3. **InitialType = 2: Standard Status**
   - 120,229 records
   - 27,916 unique patients
   - Most common status
   - Represents normal, present teeth

4. **InitialType = 3: Impacted Teeth**
   - 3,213 records
   - 525 unique patients
   - Indicates teeth that haven't properly erupted
   - May require surgical intervention

5. **InitialType = 4-10**
   - Less common statuses
   - Smaller numbers of records
   - Used for specific clinical situations

### Missing Teeth Analysis

1. **Patient Status Distribution**
   - Active Patients (Status 0):
     - 5,472 patients with missing teeth
     - 468 patients with impacted teeth
     - Primary focus for treatment planning
   - Inactive Patients (Status 1):
     - 11 patients with missing teeth
   - Other Status (Status 2):
     - 5,127 patients with missing teeth
     - Second largest group

2. **Tooth Numbering System**
   - Universal Numbering System (1-32)
   - Upper arch: 1-16 (right to left)
   - Lower arch: 17-32 (left to right)
   - Key positions:
     - Anterior teeth: 7-10, 23-26
     - First molars: 3, 14, 19, 30
     - Wisdom teeth: 1, 16, 17, 32 (typically excluded from analysis)

3. **Implant Candidacy Categories**
   - Single Tooth Implant: 1 missing tooth
   - Anterior Bridge/Implant: 2-3 missing teeth in positions 7-10
   - Multiple Implant: 2-4 missing teeth
   - Full Arch Implant: 5-9 missing teeth
   - All-on-4/6: 10+ missing teeth

### Procedure Relationships

1. **Common Procedure Sequences**
   - Extraction (D7140)
   - Implant placement (D6010)
   - Restorative work (D2xxx series)
   - Status tracking:
     - Most procedures show status "2" (Completed)
     - Multiple procedures may exist for same tooth
     - Treatment sequences visible through procedure history

2. **Clinical Documentation**
   - Missing teeth tracked in toothinitial table
   - Procedures tracked in procedurelog
   - Cross-reference available through:
     - PatNum
     - ToothNum
     - Procedure dates and status

### Key Relationships
- Missing teeth status (InitialType = 0) is primary indicator
- Active patients with missing teeth are primary treatment focus
- Procedure history provides treatment context
- Tooth position influences treatment recommendations
- Multiple status types may exist for comprehensive treatment planning

### Data Quality Considerations
1. Wisdom teeth typically excluded from analysis
2. Multiple procedures may exist for single tooth
3. Patient status affects treatment planning
4. Historical procedures provide context for current status 