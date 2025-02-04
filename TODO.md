# Treatment Journey Analysis TODO

## Data Validation Tasks

### Fee Schedule Analysis
- [ ] Validate relationship between ProcFee and FeeSchedule amounts
  - [ ] Compare f.Amount with proc.ProcFee
  - [ ] Analyze distribution of FeeRatio
  - [ ] Investigate cases where FeeRatio ≠ 1
  - [ ] Check for NULL values in f.Amount and understand why they occur

### Age Data Quality
- [ ] Investigate missing patient ages
  - [ ] Analyze patterns in records with NULL ages
  - [ ] Check if missing ages correlate with specific time periods
  - [ ] Propose strategy for handling missing ages

### Insurance Data
- [ ] Validate insurance payment accuracy
  - [ ] Compare EstimatedInsurancePayment vs ActualInsurancePayment
  - [ ] Analyze InsurancePaymentAccuracy distribution
  - [ ] Identify patterns in payment discrepancies

## ETL Infrastructure Tasks
- [ ] Fix SQL file dependencies
  - [ ] Move query.sql to scripts/sql/treatment_journey_ml/
  - [ ] Update ETL to use Python-based index configs
  - [ ] Validate all index columns exist in tables
  - [ ] Fix InsCarrier index error in patient table

## Feature Engineering Ideas
- [ ] Create age brackets/groups
- [ ] Develop composite insurance reliability score
- [ ] Calculate historical payment behavior metrics

## Model Development
- [ ] Define baseline models for each target variable
- [ ] Create cross-validation strategy
- [ ] Plan feature selection approach

## Documentation Needs
- [ ] Document fee calculation logic
- [ ] Update data dictionary
- [ ] Document target variable definitions 