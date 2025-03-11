# Medical/Dental Clinic Process Flow Diagram

## Overview
This diagram illustrates the comprehensive workflow of a medical/dental clinic's operations, spanning from patient interactions to financial processing. The system is divided into seven interconnected subsystems (A-G), each handling specific aspects of clinic operations.

## Core Systems

### System A: Fee Processing & Verification
- Manages procedure fee calculations and validations
- Handles fee schedule lookups and contracted rates
- Validates and updates procedure fees

### System B: Insurance Processing
- Manages the complete claims lifecycle
- Includes batch processing and claim status tracking
- Handles insurance carrier interactions and payment estimates
- Features robust error handling and resolution pathways

### System C: Payment Allocation & Reconciliation
- Processes both insurance and patient payments
- Manages payment splits and classifications
- Handles three types of payments:
  - Regular splits (direct application)
  - Prepayments (unearned revenue)
  - Treatment Plan deposits
- Includes daily reconciliation and validation rules

### System D: AR Analysis
- Categorizes aging receivables into buckets:
  - Current AR
  - 30-60 days
  - 60-90 days
  - 90+ days
- Monitors AR metrics and generates alerts

### System E: Collection Process
- Manages the collection workflow
- Features a three-tier notice system:
  1. First Notice
  2. Second Notice
  3. Final Notice
- Includes payment plan options and escalation paths

### System F: Patient-Clinic Communications
- Centralizes all patient communications
- Manages multiple communication channels:
  - Phone
  - SMS
  - Email
  - Portal
- Tracks communication history and responses
- Handles automated reminders and notifications

### System G: Scheduling & Referrals
- Manages appointment creation and tracking
- Handles no-show notifications
- Processes both inbound and outbound referrals
- Coordinates with insurance pre-authorization

## Critical Paths
The diagram highlights three critical paths (marked in red):
1. Final Notice (FR) in collections
2. Escalation Options (ESC) for unresolved collections
3. Claim Closure/Tagging (CT) for unresolvable insurance claims

## Data Stores
Key data repositories in the system:
- ProcedureLog
- Contracted Rates
- Claim Records
- ClaimProc Records
- Payment Records
- PaySplit Records
- AR Buckets
- CommLog
- Appointment Table
- Referral Records

## External Entities
The system interacts with:
- Patients
- Insurance Carriers/Plans
- External Providers (for referrals)

## Success Criteria
The process flow concludes with either:
- Successful payment collection and journey closure
- Escalation resolution and documentation

## Legend
The diagram uses consistent styling to differentiate:
- Processes (rounded rectangles)
- Data Stores (cylinders)
- External Entities (rectangles)
- System Boundaries (subgraphs)
- Critical Paths (red borders)

Each system is color-coded for easy identification and visual separation of concerns.
