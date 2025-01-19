# Treatment Journey Dataset

## Table Relationships

### Core Tables
```
procedurelog
- ProcNum (PK)      -- Unique identifier for each procedure instance
- CodeNum (FK)      -- Links to procedurecode table
- ProcFee           -- The planned fee
- ProcStatus        -- Status of procedure (1,2,5,6)
- ProcDate          -- When procedure was performed
- PatNum (FK)       -- Links to patient table

procedurecode
- CodeNum (PK)      -- Unique identifier for procedure type
- ProcCode          -- Standard procedure code (like D0120)
- Descript          -- Description of the procedure
- ProcCat           -- Category ID from definition table
- IsHygiene         -- Flag for hygiene procedures
- TreatArea         -- Treatment area code
- IsMultiVisit      -- Flag for multi-visit procedures

patient
- PatNum (PK)       -- Unique identifier for patient
- Birthdate         -- Patient birthdate (watch for '0001-01-01')
- Gender            -- Patient gender
- HasIns            -- Insurance status
- Guarantor         -- Links family members
```

### Financial Tables
```
paysplit
- SplitAmt          -- Payment amount
- ProcNum (FK)      -- Links to procedurelog
- PayNum (FK)       -- Links to payment

payment
- PayNum (PK)       -- Unique identifier for payment
- PayDate           -- Date of payment

claimproc
- InsPayAmt         -- Insurance payment amount
- ProcNum (FK)      -- Links to procedurelog
- Status            -- Status of insurance claim

adjustment
- AdjAmt            -- Adjustment amount
- ProcNum (FK)      -- Links to procedurelog
```

### Lookup Tables
```
definition
- Category          -- Type of definition (e.g., 'ProcCats')
- ItemOrder         -- Links to ProcCat
- Description       -- Human readable description
```

## Key Filters
- Date Range: 2023-01-01 to 2023-12-31
- ProcStatus IN (1, 2, 5, 6)

## Target Variables
1. target_accepted: ProcStatus = 2
2. target_paid_30d: Payment received within 30 days

## Feature Groups
1. Patient Demographics
2. Financial Status
3. Family History
4. Procedure Details
5. Payment Outcomes

