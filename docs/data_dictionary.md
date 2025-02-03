# Data Dictionary

## Overview
This document provides detailed descriptions of data structures, fields, and relationships across the MDC Analytics Project.

## Database Tables

### Patient Data
| Field Name | Type | Description | Source Table | Notes |
|------------|------|-------------|--------------|-------|
| PatNum | INT | Unique patient identifier | patient | Primary key |
| LName | VARCHAR(100) | Last name | patient | |
| FName | VARCHAR(100) | First name | patient | |
| Birthdate | DATE | Patient birthdate | patient | |
| Gender | CHAR(1) | Patient gender | patient | M/F/O |

### Procedure Data
| Field Name | Type | Description | Source Table | Notes |
|------------|------|-------------|--------------|-------|
| ProcNum | INT | Unique procedure identifier | procedurelog | Primary key |
| PatNum | INT | Patient identifier | procedurelog | Foreign key |
| ProcCode | VARCHAR(15) | CDT procedure code | procedurelog | |
| ProcStatus | TINYINT | Status of procedure | procedurelog | 0=Treatment Planned, 1=Complete |
| ProcDate | DATE | Date of procedure | procedurelog | |
| ProcFee | DECIMAL(11,2) | Fee amount | procedurelog | |

### Treatment Journey
| Field Name | Type | Description | Source Table | Notes |
|------------|------|-------------|--------------|-------|
| JourneyID | INT | Unique journey identifier | treatment_journey | Primary key |
| PatNum | INT | Patient identifier | treatment_journey | Foreign key |
| StartDate | DATE | Journey start date | treatment_journey | First procedure date |
| EndDate | DATE | Journey end date | treatment_journey | Last procedure date |
| TotalFee | DECIMAL(11,2) | Total treatment cost | treatment_journey | |

## Derived Features

### Patient Scoring
| Feature Name | Type | Description | Calculation | Notes |
|--------------|------|-------------|-------------|-------|
| AppointmentReliability | FLOAT | Appointment keeping score | Kept / Total appointments | Range 0-1 |
| TreatmentAcceptance | FLOAT | Treatment plan acceptance rate | Completed / Planned procedures | Range 0-1 |
| PaymentCompliance | FLOAT | Payment reliability score | Timely payments / Total payments | Range 0-1 |

### Treatment Analysis
| Metric Name | Type | Description | Calculation | Notes |
|-------------|------|-------------|-------------|-------|
| CompletionRate | FLOAT | Treatment completion rate | Completed / Total procedures | By procedure type |
| TimeToComplete | INT | Days to complete treatment | EndDate - StartDate | In days |
| RevenuePotential | DECIMAL | Potential revenue | Sum of planned treatment fees | |

## Validation Rules

### Data Quality Checks
1. Patient Demographics
   - No future birthdates
   - Valid gender values
   - Required fields: PatNum, LName, FName

2. Procedure Logs
   - Valid procedure codes
   - ProcFee >= 0
   - ProcDate <= Current date

3. Treatment Journey
   - StartDate <= EndDate
   - Valid PatNum references
   - No gaps > 180 days

## Notes
- All monetary values in USD
- Dates in YYYY-MM-DD format
- Status codes follow OpenDental conventions 