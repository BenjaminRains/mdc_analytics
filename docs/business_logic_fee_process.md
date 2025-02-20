# Fee Processing Business Logic

## Overview
This document outlines the core business logic for procedure fees and insurance processing in OpenDental.

## Core Components

### 1. Procedure Fees
- **Base Fee (`procedurelog.ProcFee`)**
  - Two primary standard tiers identified:
    - $1,950 tier (197 procedures, 72 distinct dates)
    - $1,288 tier (661 procedures, 214 distinct dates)
  - Other procedures (16,368 procedures) average $135.37
  - Large fee procedures (18 cases) average $8,067.06

- **Fee Schedule System (`fee`)**
  - Multiple fee schedules can exist for same procedure
  - Each fee entry has unique `FeeNum`
  - Links:
    - `procedurelog.CodeNum` → `fee.CodeNum`
    - `fee.OldCode` tracks CDT codes

### 2. Insurance Claims
- **Claim Status Distribution (`claimproc.Status`)**
  [... existing claim status details ...]

## Validation Rules
1. **Fee Validation**
   - Flag fees outside standard tiers
   - Monitor frequency of large fee procedures
   - Check for decimal point errors in adjustments

2. **Payment Validation**
   - Maximum 15 splits per payment
   - Split difference tolerance: 0.01
   - Payment-to-fee ratio: 0.95-1.05
   - Review all zero-fee procedures with payments