# Unscheduled Patients Analysis

## Overview
Analysis of patients seen in January 2025 who require follow-up scheduling or treatment planning.

## Key Findings

### Patient Distribution
Total January 2025 patients analyzed: 48
- Scheduled future appointments: 37 patients (77%)
- Needs scheduling: 1 patient (2%)
- Needs treatment plan: 10 patients (21%)

### Patient Categories

1. **Needs Scheduling** (1 patient)
   - Has treatment planned procedures but no scheduled appointment
   - All procedures are properly documented in procedurelog
   - Patient has active recall status
   - Average of 3 planned procedures

2. **Needs Treatment Plan** (10 patients)
   - No future appointments
   - No planned procedures
   - All have active recall status
   - All have at least one form of contact information
   - Most recent appointments were between Jan 2-3, 2025

### Data Quality Observations
1. No anomalies in appointment statuses
2. All patients maintain active recall status
3. Contact information is well-maintained:
   - Email addresses present
   - Multiple phone numbers available
   - No patients with missing contact details

## Business Process Implications

### Follow-up Priorities
1. High Priority:
   - Single patient with planned procedures needing scheduling
   - Already diagnosed and treatment planned
   - Ready for immediate scheduling

2. Medium Priority:
   - Ten patients requiring treatment plan review
   - All are active patients with recent visits
   - May need clinical review before scheduling

### Scheduling Patterns
- Most patients (77%) successfully schedule future appointments
- Small percentage (23%) require follow-up
- All patients categorized as needing follow-up were seen in early January

## Recommendations
1. Immediate follow-up with the patient who has planned procedures
2. Review treatment planning process to identify why 10 patients left without future plans
3. Consider automated alerts for:
   - Patients leaving without future appointments
   - Planned procedures without scheduled appointments
4. Monitor this metric monthly to identify scheduling pattern changes

## Report Usage
The unscheduled_patients_report.sql provides:
- Patient identification and contact details
- Clear categorization of follow-up needs
- Prioritization by treatment plan status
- Verification of recall status 