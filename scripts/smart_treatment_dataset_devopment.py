import pandas as pd
import os

# Define file paths for raw data
raw_data_dir = "raw_data"
output_file = "processed_data/smart_treatment_dataset_development.csv"

# Load raw data
treatment_plan_data = pd.read_csv(os.path.join(raw_data_dir, "treatplan_data.csv"))
patient_data = pd.read_csv(os.path.join(raw_data_dir, "patient_data.csv"))
procedure_data = pd.read_csv(
    os.path.join(raw_data_dir, "procedurelog_data.csv"),
    low_memory=False
)
appointment_data = pd.read_csv(os.path.join(raw_data_dir, "appointment_data.csv"))
payment_data = pd.read_csv(os.path.join(raw_data_dir, "payment_data.csv"))
communication_data = pd.read_csv(os.path.join(raw_data_dir, "commlog_data.csv"))
proctp_data = pd.read_csv(os.path.join(raw_data_dir, "proctp_data.csv"))

# --- STEP 1: Aggregate proctp Data ---
# Group proctp data by TreatPlanNum and calculate PlanAmt and AcceptedAmt. Logic must be distinct for presented amount and
# accepted amount. 
plan_amt_aggregated = proctp_data.groupby("TreatPlanNum", as_index=False).agg({"FeeAmt": "sum"})
plan_amt_aggregated.rename(columns={"FeeAmt": "PlanAmt"}, inplace=True)

# Merge PlanAmt and AcceptedAmt into treatment plan data
treatment_plan_data = treatment_plan_data.merge(plan_amt_aggregated, on="TreatPlanNum", how="left")
treatment_plan_data = treatment_plan_data.merge(accepted_amt_aggregated, on="TreatPlanNum", how="left")

# display the df after the merge to inspect. 

# check and display missing row count. 
# Fill missing PlanAmt and AcceptedAmt with 0
treatment_plan_data["PlanAmt"].fillna(0, inplace=True)
treatment_plan_data["AcceptedAmt"].fillna(0, inplace=True)

# --- STEP 2: Filter Treatment Plans ---
# Filter treatment plans created in 2024
treatment_plan_data = treatment_plan_data[
    (pd.to_datetime(treatment_plan_data["DateTP"]) >= "2024-01-01") &
    (pd.to_datetime(treatment_plan_data["DateTP"]) <= "2024-12-31")
]

# --- STEP 3: Merge Tables ---
# Merge treatment plan data with other data sources
# Verify and inspect df after each merge
dataset = treatment_plan_data.merge(patient_data, on="PatNum", how="left")
dataset = dataset.merge(procedure_data, on="PatNum", how="left")
dataset = dataset.merge(appointment_data, on="PatNum", how="left")
dataset = dataset.merge(payment_data, on="PatNum", how="left")
dataset = dataset.merge(communication_data, on="PatNum", how="left")



# --- STEP 4: Feature Engineering ---
# 1. Treatment Plan Acceptance Rate
dataset["tx_acceptance_rate"] = dataset["AcceptedAmt"] / dataset["PlanAmt"]
dataset["tx_acceptance_rate"].fillna(0, inplace=True)

# 2. Communication Counts
communication_counts = communication_data.groupby("PatNum").size().reset_index(name="total_communications")
dataset = dataset.merge(communication_counts, on="PatNum", how="left")
dataset["total_communications"].fillna(0, inplace=True)

# 3. Total Payments
payment_totals = payment_data.groupby("PatNum")["PayAmt"].sum().reset_index(name="total_payments")
dataset = dataset.merge(payment_totals, on="PatNum", how="left")
dataset["total_payments"].fillna(0, inplace=True)

# 4. Remaining Balance
dataset["remaining_balance"] = dataset["PlanAmt"] - dataset["total_payments"]

# 5. Appointment Metrics
# Count total appointments and missed appointments
appointment_counts = appointment_data.groupby("PatNum").size().reset_index(name="total_appointments")
dataset = dataset.merge(appointment_counts, on="PatNum", how="left")
dataset["total_appointments"].fillna(0, inplace=True)

if "AptStatus" in appointment_data.columns:
    missed_counts = appointment_data[appointment_data["AptStatus"] == 3].groupby("PatNum").size().reset_index(
        name="missed_appointments"
    )
    dataset = dataset.merge(missed_counts, on="PatNum", how="left")
    dataset["missed_appointments"].fillna(0, inplace=True)
else:
    dataset["missed_appointments"] = 0

# --- STEP 5: Add Target Variable ---
# Binary target variable: Accepted if AcceptedAmt > 0
dataset["accepted"] = (dataset["AcceptedAmt"] > 0).astype(int)

# --- STEP 6: Save Final Dataset ---
# comment definition of each field or identify source data (ie. PatNum comes from patients.PatNum)
final_dataset = dataset[
    [
        "PatNum",
        "TreatPlanNum",
        "DateTP",
        "PlanAmt",
        "AcceptedAmt",
        "tx_acceptance_rate",
        "total_communications",
        "total_payments",
        "remaining_balance",
        "total_appointments",
        "missed_appointments",
        "accepted",
    ]
]

os.makedirs("processed_data", exist_ok=True)
final_dataset.to_csv(output_file, index=False)
print(f"Dataset saved to {output_file}")
