# Dental Practice Insurance Processing Flow

This document explains the data flow diagram that illustrates how dental procedures move through insurance processing and payment systems.

## Overview

This documentation explains the dental practice's insurance processing system, focusing on fee schedules, claims processing, and payment patterns. Our analysis reveals a significant disconnect between intended (in-network) and actual (out-of-network) processing patterns.

The diagram shows two main processing paths:
1. Fee Schedule Processing (99.9% out-of-network)
2. Insurance Claim Processing (variable payments)

## System Flow

### 1. Initial Patient Processing
- Patient undergoes dental procedure
- System creates ProcedureLog entry
- ProcedureLog becomes central record for all subsequent processing

### Fee Processing Flow
- System attempts to lookup fee schedule for procedure
- Two possible paths:
  1. **No Fee Schedule Found (99.9% of cases)**
     * Indicates out-of-network processing
     * No contracted rates apply
     * Higher payment variability
  2. **Fee Schedule Found (0.1% of cases)**
     * Only 2 plans have active fee schedules:
       - United Concordia (PlanNum 51)
       - MetLife (PlanNum 14410)
     * Uses contracted in-network rates

### 3. Claims Processing

#### Claim Generation
- ProcedureLog generates Claim record
- Claim details recorded in ClaimProc
- Sent to Insurance Carrier/Plan

#### Processing Paths
1. **Out-of-Network Processing (99.9%)**
   - No contracted rates
   - High payment variability (40-42%)
   - Major carriers affected:
     * Aetna: 42.5% variability
     * Guardian: 42.4% variability
     * Anthem: 42.2% variability
     * MetLife Dental: 41.8% variability

2. **In-Network Processing (0.1%)**
   - Uses contracted fee schedules
   - More consistent but still variable (28-34%)
   - Limited to specific plans with fee schedules

### 4. Payment Processing
- Payments recorded in Payment & PaySplit
- Posts back to ProcedureLog
- Updates fees and balances
- Feeds into financial reporting

## Key Insights

1. **Network Status**
   - Practice predominantly processes out-of-network claims
   - Only 2 out of ~5,000 plans have fee schedules
   - High payment variability indicates lack of contracted rates

2. **Payment Patterns**
   - Out-of-network claims: 40-42% payment variability
   - In-network claims: 28-34% payment variability
   - All claims show significant payment unpredictability

3. **System Configuration**
   - Designed to handle both in/out of network
   - Primarily operating in out-of-network mode
   - Maintains reference data for variance tracking

## Business Impact

### 1. Financial Implications
- Predominantly out-of-network claims
- Unpredictable payment amounts
- High payment variability (40-42%)
- Limited fee schedule controls

### 2. Operational Challenges
- Manual payment reconciliation needed
- No contracted rate validation
- High administrative overhead
- Payment variance tracking required

### 3. Compliance Considerations
- Limited in-network contract obligations
- Out-of-network billing compliance needed
- Patient responsibility implications
- Network status documentation requirements

## System Components

### Core Tables
1. **ProcedureLog**
   - Central record for procedures
   - Links to all related records
   - Maintains fee and payment history

2. **FeeSched & Fee**
   - Stores fee schedule definitions
   - Currently only active for 0.1% of plans
   - Referenced for variance tracking

3. **Claim & ClaimProc**
   - Manages insurance claim details
   - Tracks claim processing status
   - Records carrier responses

4. **Payment & PaySplit**
   - Records payment receipts
   - Manages payment allocations
   - Updates procedure balances

## Monitoring and Analysis

### 1. Payment Patterns
- Track payment variability by carrier
- Monitor in-network vs out-of-network patterns
- Analyze payment timing and consistency

### 2. Fee Schedule Usage
- Track active fee schedules
- Monitor fee schedule assignments
- Validate contracted rates when applicable

### 3. Performance Metrics
- Payment variability tracking
- Claims processing efficiency
- Payment reconciliation accuracy

## Recommendations

### 1. System Updates
- Implement network status tracking
- Add payment source validation
- Create fee schedule controls
- Develop variance monitoring tools

### 2. Process Improvements
- Document network status by carrier
- Track payment patterns systematically
- Monitor fee schedule usage
- Implement automated reconciliation

### 3. Policy Alignment
- Confirm intended network strategy
- Update fee schedule protocols
- Establish monitoring procedures
- Define variance thresholds

## Reference Files
- Data Flow Diagram: `data_flow_diagram.txt`
- Analysis Notebook: `ins_payment_analysis.ipynb`
- Fee Schedule Analysis: `readme_fee_schedule.md`
- Stakeholder Report: `stakeholder_followup.md` 