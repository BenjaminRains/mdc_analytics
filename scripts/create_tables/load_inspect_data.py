import pandas as pd
import os

# Define file paths for raw data
raw_data_dir = "raw_data"

# Load raw data
treatment_plan_data = pd.read_csv(os.path.join(raw_data_dir, "treatplan_data.csv"))
patient_data = pd.read_csv(os.path.join(raw_data_dir, "patient_data.csv"))
procedure_data = pd.read_csv(os.path.join(raw_data_dir, "procedurelog_data.csv"), low_memory=False)
appointment_data = pd.read_csv(os.path.join(raw_data_dir, "appointment_data.csv"))
payment_data = pd.read_csv(os.path.join(raw_data_dir, "payment_data.csv"))
communication_data = pd.read_csv(os.path.join(raw_data_dir, "commlog_data.csv"))
proctp_data = pd.read_csv(os.path.join(raw_data_dir, "proctp_data.csv"))

# Inspect the data
print("Treatment Plan Data:")
print(treatment_plan_data.info())
print(treatment_plan_data.head())

print("\nPatient Data:")
print(patient_data.info())
print(patient_data.head())

print("\nProcedure Data:")
print(procedure_data.info())
print(procedure_data.head())

print("\nAppointment Data:")
print(appointment_data.info())
print(appointment_data.head())

print("\nPayment Data:")
print(payment_data.info())
print(payment_data.head())

print("\nCommunication Data:")
print(communication_data.info())
print(communication_data.head())

print("\nProctp Data:")
print(proctp_data.info())
print(proctp_data.head())

# --- STEP 2: Aggregate proctp Data ---

# Group proctp data by TreatPlanNum to calculate PlanAmt
plan_amt_aggregated = proctp_data.groupby("TreatPlanNum", as_index=False).agg(
    {"FeeAmt": "sum"}
)
plan_amt_aggregated.rename(columns={"FeeAmt": "PlanAmt"}, inplace=True)

# Verify the aggregated PlanAmt data
print("\nAggregated PlanAmt Data:")
print(plan_amt_aggregated.head())

# Group proctp data by TreatPlanNum to calculate AcceptedAmt (use FeeAmt for now as proxy)
accepted_amt_aggregated = proctp_data.groupby("TreatPlanNum", as_index=False).agg(
    {"FeeAmt": "sum"}  # Placeholder logic; refine based on acceptance logic
)
accepted_amt_aggregated.rename(columns={"FeeAmt": "AcceptedAmt"}, inplace=True)

# Verify the aggregated AcceptedAmt data
print("\nAggregated AcceptedAmt Data:")
print(accepted_amt_aggregated.head())

# Merge PlanAmt into treatment plan data
treatment_plan_data = pd.merge(
    treatment_plan_data,
    plan_amt_aggregated,
    on="TreatPlanNum",
    how="left"
)

# Merge AcceptedAmt into treatment plan data
treatment_plan_data = pd.merge(
    treatment_plan_data,
    accepted_amt_aggregated,
    on="TreatPlanNum",
    how="left"
)

# Fill missing PlanAmt and AcceptedAmt with 0
treatment_plan_data["PlanAmt"].fillna(0, inplace=True)
treatment_plan_data["AcceptedAmt"].fillna(0, inplace=True)

# Verify the treatment plan data after merging
print("\nTreatment Plan Data After Merging Aggregations:")
print(treatment_plan_data.head())

# --- STEP 3: Filter Treatment Plans ---

# Filter treatment plans for 2023
treatment_plan_data_2023 = treatment_plan_data[
    (pd.to_datetime(treatment_plan_data["DateTP"]) >= "2023-01-01") &
    (pd.to_datetime(treatment_plan_data["DateTP"]) <= "2023-12-31")
]

print("\nFiltered Treatment Plans (2023):")
print(treatment_plan_data_2023.head())
print(f"Number of treatment plans in 2023: {len(treatment_plan_data_2023)}")

