import pandas as pd
import os

# Define the paysplit table schema information with primary and foreign keys
paysplit_data = {
    "Column Name": [
        "SplitNum", "SplitAmt", "PatNum", "ProcDate", "PayNum", "IsDiscount",
        "DiscountType", "ProvNum", "PayPlanNum", "DatePay", "ProcNum", "DateEntry",
        "UnearnedType", "ClinicNum", "SecUserNumEntry", "SecDateTEdit", "FSplitNum",
        "AdjNum", "PayPlanChargeNum", "PayPlanDebitType", "SecurityHash"
    ],
    "Data Type": [
        "bigint(20)", "double", "bigint(20)", "date", "bigint(20)", 
        "tinyint(1) unsigned", "tinyint(3) unsigned", "bigint(20)", "bigint(20)",
        "date", "bigint(20)", "date", "bigint(20)", "bigint(20)", "bigint(20)",
        "timestamp", "bigint(20)", "bigint(20)", "bigint(20)", "tinyint(4)",
        "varchar(255)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "'0'", "NOT NULL", "'0001-01-01'", "NOT NULL",
        "'0'", "'0'", "NOT NULL", "NOT NULL", "'0001-01-01'", "NOT NULL",
        "'0001-01-01'", "NOT NULL", "NOT NULL", "NOT NULL", "CURRENT_TIMESTAMP",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "INDEX", "FOREIGN KEY", "NONE", "FOREIGN KEY",
        "NONE", "NONE", "FOREIGN KEY", "FOREIGN KEY", "INDEX",
        "FOREIGN KEY", "NONE", "FOREIGN KEY", "FOREIGN KEY", "FOREIGN KEY",
        "INDEX", "FOREIGN KEY", "FOREIGN KEY", "FOREIGN KEY", "NONE",
        "NONE"
    ],
    "References": [
        "Self", "None", "Patient(PatNum)", "None", "Payment(PayNum)",
        "None", "None", "Provider(ProvNum)", "PayPlan(PayPlanNum)", "None",
        "Procedure(ProcNum)", "None", "Definition(UnearnedType)", "Clinic(ClinicNum)", 
        "User(SecUserNumEntry)", "None", "PaySplit(FSplitNum)", "Adjustment(AdjNum)",
        "PayPlanCharge(PayPlanChargeNum)", "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in paysplit_data.values())

# Ensure all lists are of equal length by padding with None
for key in paysplit_data:
    current_length = len(paysplit_data[key])
    if current_length < max_length:
        paysplit_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_paysplit = pd.DataFrame(paysplit_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_paysplit = os.path.join(project_root, "docs", "paysplit_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_paysplit.to_csv(file_path_paysplit, index=False) 