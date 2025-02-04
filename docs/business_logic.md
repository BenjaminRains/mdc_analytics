## Procedure Status (procedurelog.ProcStatus)

### Status Values and Meanings

1. **ProcStatus = 1: Treatment Planned**
   - Represents planned/scheduled procedures
   - No completion dates (DateComplete = '0001-01-01')
   - Can be linked to appointments with various statuses:
     - No appointment yet (NULL AptStatus)
     - Scheduled appointments (AptStatus = 1)
     - Completed appointments (AptStatus = 2)
     - Broken/missed appointments (AptStatus = 5)

2. **ProcStatus = 2: Completed**
   - Represents completed procedures
   - Always has valid completion dates
   - Majority are linked to completed appointments (AptStatus = 2)
   - Some may have no appointment link
   - Makes up ~75% of all procedures

3. **ProcStatus = 3: Administrative/Documentation** (4.31%)
   - Almost exclusively used for "Group Note" entries (>99%)
   - Zero-fee procedures
   - Has treatment plan dates
   - No appointment links
   - Used for administrative documentation rather than actual procedures

4. **ProcStatus = 4** (5.05%)
   - Higher average fees ($739.78)
   - Has treatment plan dates
   - No appointment links
   - Multiple procedure types (15 unique codes)
   - Purpose needs further investigation

5. **ProcStatus = 5** (0.33%)
   - Rarely used
   - Purpose needs further investigation
   - No appointment links

6. **ProcStatus = 6: Ordered/Planned** (7.23%)
   - Common procedure types:
     - Preventive care (fluoride, cleanings, evaluations)
     - Diagnostic procedures (various X-rays)
     - Major treatments (core buildups, crowns, implants)
   - Lower average fees ($208.30)
   - Most have treatment plan dates (97%)
   - No appointment links yet
   - Includes tracking codes (Post Op, Tooth Watch)
   - Actively managed procedures awaiting scheduling

7. **ProcStatus = 7: Not Accepted** (1.03%)
   - No completion dates
   - No appointment links
   - Likely represents declined treatment plans

8. **ProcStatus = 8: Unknown** (0.06%)
   - Very rarely used
   - No completion dates
   - No appointment links

### Distribution
Based on analysis of procedurelog table:
- Status 1: 6.55%
- Status 2: 75.44%
- Status 3: 4.31%
- Status 4: 5.05%
- Status 5: 0.33%
- Status 6: 7.23%
- Status 7: 1.03%
- Status 8: 0.06%

### Key Relationships
- Completed procedures (Status 2) almost always have:
  - Valid completion dates
  - Links to completed appointments (AptStatus = 2)
  - Also used for completed administrative tasks (85% of missed/cancelled appointments)
- Planned procedures (Status 1) always have:
  - No completion date ('0001-01-01')
  - May or may not have appointment links
  - Can be associated with various appointment statuses
- Missed and Cancelled Appointments:
  - Primarily recorded with ProcStatus = 2 (~85%)
  - Sometimes recorded with ProcStatus = 6 (~15%)
  - Choice of status might depend on when the miss/cancellation occurred 

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
   - 145 appointments (2.77% of all appointments)
   - 142 unique patients
   - Used to mark broken appointments in the appointment table
   - Represents immediate no-shows or same-day breaks

2. **Procedure Codes**
   - D9986/626 (Missed Appointments):
     - 891 occurrences (795 ProcStatus=2, 96 ProcStatus=6)
     - 806 unique patients
   - D9987/627 (Cancelled Appointments):
     - 3,208 occurrences (2,726 ProcStatus=2, 481 ProcStatus=6, 1 ProcStatus=7)
     - 2,294 unique patients
   - Primarily recorded with ProcStatus = 2 (~85%)
   - Remainder mostly recorded with ProcStatus = 6 (~15%)

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

## Fee Schedule System

### Fee Schedule Usage (2024 Analysis)

1. **Primary Fee Schedules**
   - Standard (#55):
     * 18,633 procedures
     * 2,868 patients
     * Average fee: $181.46
   - StandardServices (#54):
     * 17,498 procedures
     * 2,862 patients
     * Average fee: $191.08

2. **Employer/Organization Fee Schedules**
   - US STEEL (#8278):
     * 14,590 procedures
     * 2,417 patients
     * Average fee: $162.02
   - Methodist Hosp OON (#8274):
     * 14,433 procedures
     * 2,379 patients
     * Average fee: $193.04
   - Community Healthcare System (#1642):
     * 14,259 procedures
     * 2,385 patients
     * Average fee: $191.77

3. **Insurance Carrier Fee Schedules**
   - Cleveland Cliffs (#8286):
     * 13,451 procedures
     * 2,416 patients
     * Average fee: $151.78
   - Liberty (#8291):
     * 13,240 procedures
     * 2,377 patients
     * Average fee: $184.32

### Fee Schedule Patterns

1. **Usage Characteristics**
   - Consistent monthly distribution
   - ~15-17% patient-to-procedure ratio
   - Limited price differentiation ($151-$193 range)
   - All major schedules actively used

2. **Fee Structure**
   - Standard schedule (#55) used as default
   - Organization-specific pricing shows moderate variation
   - Base fees cluster tightly ($150-$200 range)
   - Maximum fees vary significantly ($1,950-$17,500)
   - Zero minimum fees across all schedules

3. **Business Rules**
   - Each procedure requires fee schedule assignment
   - Fee schedules should link to:
     * Insurance carriers
     * Employers
     * Organizations
     * Standard pricing
   - Multiple fee schedules possible per organization

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
   - Standard schedules handle highest volume:
     * #55: 18,633 procedures/year
     * #54: 17,498 procedures/year
   - Organization schedules: 14,200-14,600 procedures/year
   - Insurance schedules: ~13,300 procedures/year
   - Consistent monthly distribution 