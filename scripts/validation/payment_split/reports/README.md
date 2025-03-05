# Unassigned Provider Transactions Remediation Guide

## Overview

This document provides guidance for addressing the **1,498 unassigned provider transactions** identified in our OpenDental system. Unassigned provider transactions represent payments or adjustments that have been entered into the system but not properly attributed to a specific provider. These unassigned transactions impact:

- **Provider Production Reports**: Leading to inaccurate performance metrics
- **Revenue Attribution**: Causing discrepancies in department and provider revenue tracking
- **Accounting Reconciliation**: Creating difficulties in monthly financial close processes

The accompanying Excel file contains all unassigned transactions that require immediate attention. This structured approach will help systematically correct these issues while preventing future occurrences.

## Quick Start Guide

1. Open the Excel file named `unassigned_provider_transactions_YYYY-MM-DD.xlsx` in this folder
2. Sort transactions based on prioritization criteria (see below)
3. For each transaction, follow the provider assignment workflow
4. Update the Status column as you progress
5. Save the file regularly to track completion

## Understanding the Excel File

The Excel file contains the following key columns:

| Column | Description |
|--------|-------------|
| SplitNum | Unique identifier for the payment split |
| PayNum | Identifier for the payment |
| PatNum | Patient identifier |
| PatientName | Patient name |
| SplitAmt | Transaction amount |
| PaymentDate | Date the payment was recorded |
| PayTypeName | Type of payment (Check, Credit Card, etc.) |
| UserName | User who entered the transaction |
| UserGroupName | Department or group of the user |
| DateTCreated | Date the transaction was created |

## Prioritization Guidelines

Use these criteria to prioritize which transactions to fix first:

1. **Critical Priority**:
   - Transaction amount > $5,000
   - Transaction older than 30 days
   - VIP patient accounts

2. **High Priority**:
   - Transaction amount $1,000-$5,000
   - Transaction 15-30 days old
   - Patients with treatment plan in progress

3. **Medium Priority**:
   - Transaction amount $200-$999
   - Transaction 7-14 days old

4. **Low Priority**:
   - Transaction amount < $200
   - Transaction < 7 days old

## Provider Assignment Workflow

For each transaction, follow these steps in OpenDental:

1. **Open OpenDental** and navigate to the Payments module
2. **Locate the payment** using the PayNum from the Excel file
3. **Review patient history**:
   - Check appointment history within 30 days of payment
   - Review procedures completed around payment date
   - Identify the patient's primary provider

4. **Determine correct provider** using this logic:
   - If payment corresponds with a specific procedure date, assign to that procedure's provider
   - If patient had an appointment within 30 days, assign to that provider
   - If neither applies, assign to patient's primary provider

5. **Edit the payment split**:
   - Right-click on the payment and select "Edit"
   - Navigate to the splits section
   - Find the unassigned split (identified by SplitNum)
   - Select the appropriate provider from the dropdown
   - Save the changes

6. **Update the Excel file**:
   - Mark the Status column as "Completed"
   - Add notes about which provider was assigned and why

## Tracking Progress

To effectively track progress, add these columns to the Excel file:

- **Priority**: Critical, High, Medium, or Low
- **Status**: Open, In Review, Completed
- **AssignedProvider**: Provider to whom the transaction was assigned
- **AssignmentDate**: Date when the assignment was completed
- **AssignedBy**: Your name/username
- **Notes**: Any relevant information about the assignment decision

## Weekly Progress Targets

The following schedule is recommended for completing the assignments:

| Week | Target | Cumulative Completion |
|------|--------|----------------------|
| Week 1 | All Critical priority (est. 150) | ~10% |
| Week 2 | All High priority (est. 350) | ~33% |
| Weeks 3-4 | All Medium priority (est. 500) | ~67% |
| Weeks 5-6 | All Low priority (est. 498) | 100% |

## Prevention Strategies

While fixing the existing issues, implement these prevention strategies:

1. **Staff Training**: Ensure all staff understand the requirement to assign providers
2. **Daily Review**: Implement daily review of unassigned transactions
3. **System Validation**: Request that IT add a warning when saving transactions without providers
4. **User Accountability**: Share weekly reports of unassigned transactions by user

## Support

If you encounter any issues or have questions during this process, please contact:

- **Technical Issues**: IT Support at extension 1234
- **Workflow Questions**: Finance Department at extension 5678
- **Data Analysis**: Analytics Team at analytics@example.com

## Completion Reporting

When you've completed a significant batch of assignments (or weekly), please send a progress update to your supervisor including:

1. Number of transactions completed
2. Any patterns identified
3. Challenges encountered
4. Suggestions for process improvement

Thank you for your help in resolving these important data quality issues!

---

*Generated by MDC Analytics Platform* 