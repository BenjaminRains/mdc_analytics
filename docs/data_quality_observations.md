# Data Quality Observations

This document tracks notable data patterns, inconsistencies, and outliers discovered during analysis. These observations help understand the data quality and potential edge cases.

## Appointments

### Broken Appointments with Completed Procedures

**Context:**
- Total broken appointments (AptStatus = 5): 8,041
- Broken appointments with completed procedures: 3 (0.037%)

**Observations:**
1. Clinical Procedure Case:
   - 1 case of a resin-based composite procedure
   - Appointment date: 2018-11-30
   - Completed date: 2021-04-26 (878 days later)
   - Likely represents a patient who missed the original appointment but returned much later

2. Administrative Procedure Cases:
   - 2 cases of "Delivery" procedures
   - Completed 35-135 days after the broken appointments
   - Notes suggest these are paperwork/documentation related
   - Example notes: "EMAILED UPDATED PAPERWORK"

**Assessment:**
These cases appear to be legitimate outliers rather than data quality issues:
- The clinical case likely represents a rescheduled procedure
- The administrative cases appear to be documentation tasks completed despite missed appointments
- The extremely low percentage (0.037%) suggests these are exceptional cases rather than systematic issues

## Appointment Status Distribution

Status counts across all appointments:
1. Status 1 (Scheduled): 1,666
2. Status 2 (Completed): 63,961
3. Status 3 (Unspecified): 2,623
4. Status 4 (ASAP): 4,325
5. Status 5 (Broken/Missed): 3,695
6. Status 6 (Unscheduled): 1

## Missing Teeth Analysis

### Data Quality and Distribution

**Context:**
- Total patients with missing teeth: 3,957
- Patients with anterior teeth missing: 1,185 (29.9%)
- Patients with first molars missing: Not directly reported

**Treatment Categories Distribution:**
1. Multiple Implant Candidate: 1,279 (32.3%)
2. Single Tooth Implant Candidate: 953 (24.1%)
3. Full Arch Implant Candidate: 867 (21.9%)
4. All-on-4/6 Candidate: 765 (19.3%)
5. Anterior Bridge/Implant Candidate: 93 (2.4%)

**Data Quality Observations:**
1. Tooth Number Format Issues:
   - Found instances of OCR-like errors in tooth numbers
   - Common substitutions: 'O'/'o' for '0', 'l'/'I'/'i' for '1'
   - Required data cleaning to standardize numeric format
   - Example: "O8" → "08", "l4" → "14"

2. Validation Rules:
   - Excluded wisdom teeth (1,16,17,32) from analysis
   - Filtered out invalid tooth numbers
   - Required numeric values between 2-15 and 18-31

3. Pattern Analysis:
   - Most common: 2-4 missing teeth (32.3%)
   - Significant number of full arch cases (41.2% combined Full Arch and All-on-4/6)
   - Relatively low number of anterior-only cases (2.4%)

**Assessment:**
- Data quality issues appear to be primarily input/OCR related
- After cleaning, the distribution of cases aligns with clinical expectations
- High percentage of multiple tooth cases suggests focus needed on comprehensive treatment planning 

## Fee Schedule Analysis

### Active Fee Schedule Distribution

**Context:**
- Total active fee schedules (IsHidden = 0): 5
- Only 1 fee schedule actively used (FeeSchedNum = 55)

**Fee Schedule Details:**
1. Standard Fee Schedule (55):
   - 2 patients assigned
   - All office staff assigned (including providers, hygienists, and administrative staff)
   - 10 procedures in 2023
   - Marked as type "Other" despite "Standard" description

2. Inactive but Visible Fee Schedules:
   - Cleveland Cliffs (United Concordia) (8286)
   - Werner Enterprises Inc. (United Concordia) (8287)
   - Tri-Care (United Concordia) (8289)
   - Liberty (8291)
   - All marked as type "Other"
   - No patients, providers, or procedures assigned
   - Not hidden despite inactivity

**Assessment:**
- Potential configuration issues with fee schedule types (all marked as "Other")
- Insurance-related fee schedules exist but are unused
- All staff members using single fee schedule (#55)
- Very low patient assignment rate (2 patients total)
- Recommend reviewing if unused fee schedules should be hidden or properly assigned

## Fee and Payment Issues (2023)

### Large Negative Adjustments

**Context:**
- Total negative adjustments analyzed: 69 cases
- Total amount: $137,191.85
- Date range: January 2023 - December 2023

**Key Findings:**
1. Decimal Point Errors:
   - Most severe case: -$27,680 on $330 procedure (83.9x fee)
   - Common pattern: 100x multiplier suggests decimal shift
   - Example: -$14,340 on $0 fee procedure needs review

2. Adjustment Size Distribution:
   - >10x procedure fee: 7 cases
   - 5x-10x procedure fee: 18 cases
   - 2x-5x procedure fee: 31 cases
   - 1x-2x procedure fee: 13 cases

### Duplicate Procedure Entries

**Context:**
- Total possible duplicates: 15,151 procedures
- Total amount: $2,888,140.60
- Primary affected fee tiers: $1,950 and $1,288

**Notable Patterns:**
1. Batch Entry Cases:
   - 2023-06-21: 13 identical $1,950 procedures ($25,350)
   - 2023-03-01: 11 identical $1,950 procedures ($21,450)
   - 2023-03-22: 14 identical $1,288 procedures ($18,032)

2. Entry Patterns:
   - Sequential ProcNums indicate batch entry
   - Same-day, same-fee entries without sequential ProcNums suggest manual duplicates
   - Most common dates show 8-14 duplicate entries

### Fee Schedule Analysis

**Context:**
- Standard fee tiers identified:
  - $1,950 tier: 197 procedures across 72 dates
  - $1,288 tier: 661 procedures across 214 dates
  - Other procedures: 16,368 procedures averaging $135.37

**Data Quality Issues:**
1. Fee Schedule Assignment:
   - Only 1 active fee schedule (FeeSchedNum = 55)
   - Only 2 patients assigned to fee schedules
   - All staff using single fee schedule

2. Large Fee Outliers:
   - 18 procedures with fees averaging $8,067.06
   - 13 procedures with large unpaid balances totaling $110,969

## Payment Processing Issues

### Split Payment Patterns

**Context:**
- Normal splits (1-3): 76% of payments
- Complex splits (4-15): Requires insurance
- Problematic splits (>15): 16 cases need review

**Data Quality Concerns:**
1. Split Amount Issues:
   - Small split amounts (<$1) requiring review
   - Multiple splits on zero-fee procedures
   - Complex split patterns without active insurance

2. Payment Validation:
   - Payment-to-fee ratios outside 0.95-1.05 range
   - Split differences exceeding 0.01 tolerance
   - Overpayment cases requiring investigation

## Recommendations

1. Immediate Actions:
   - Review and correct decimal point errors in adjustments
   - Investigate duplicate procedure entries
   - Validate large fee procedures
   - Review complex split payment cases

2. Process Improvements:
   - Implement decimal point validation for adjustments
   - Add duplicate entry detection
   - Enhance fee schedule assignment
   - Strengthen payment split validation

3. Monitoring:
   - Track adjustment size distributions
   - Monitor duplicate entry patterns
   - Review payment split complexity
   - Validate fee schedule usage

## Assessment
The 2023 data quality issues appear concentrated in three main areas:
1. Adjustment entry errors (especially decimal points)
2. Duplicate procedure entries (both batch and manual)
3. Complex payment splits requiring validation

These issues suggest the need for enhanced validation controls and regular monitoring procedures.

there are two records with ProcDate = '1902-XX-XX'. These records need to be updated or ProcDate needs to be NULL

investigate adjustment.Note = [empty]. There are 1000+ records with this value. 