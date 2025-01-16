import pandas as pd
import os

# Define the claimproc table schema information with primary and foreign keys
claimproc_data = {
    "Column Name": [
        "ClaimProcNum", "ProcNum", "ClaimNum", "PatNum", "ProvNum", "FeeBilled", 
        "InsPayEst", "DedApplied", "Status", "InsPayAmt", "Remarks", 
        "ClaimPaymentNum", "PlanNum", "DateCP", "WriteOff", "CodeSent", 
        "AllowedOverride", "Percentage", "PercentOverride", "CopayAmt", 
        "NoBillIns", "PaidOtherIns", "BaseEst", "CopayOverride", "ProcDate", 
        "DateEntry", "LineNumber", "DedEst", "DedEstOverride", "InsEstTotal", 
        "InsEstTotalOverride", "PaidOtherInsOverride", "EstimateNote", 
        "WriteOffEst", "WriteOffEstOverride", "ClinicNum", "InsSubNum", 
        "PaymentRow", "PayPlanNum", "ClaimPaymentTracking", "SecUserNumEntry", 
        "SecDateEntry", "SecDateTEdit", "DateSuppReceived", "DateInsFinalized", 
        "IsTransfer", "ClaimAdjReasonCodes", "IsOverpay"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "bigint(20)", "bigint(20)", "bigint(20)", 
        "double", "double", "double", "tinyint(3) unsigned", "double", 
        "varchar(255)", "bigint(20)", "bigint(20)", "date", "double", 
        "varchar(15)", "double", "tinyint(4)", "tinyint(4)", "double", 
        "tinyint(1) unsigned", "double", "double", "double", "date", 
        "date", "tinyint(3) unsigned", "double", "double", "double", 
        "double", "double", "varchar(255)", "double", "double", "bigint(20)", 
        "bigint(20)", "int(11)", "bigint(20)", "bigint(20)", "bigint(20)", 
        "date", "timestamp", "date", "date", "tinyint(4)", "varchar(255)", 
        "tinyint(4)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", 
        "'0'", "'0'", "'0'", "'0'", "'0'", "''", "NOT NULL", "NOT NULL", 
        "'0001-01-01'", "'0'", "''", "NOT NULL", "'-1'", "'-1'", "'-1'", 
        "'0'", "'-1'", "'0'", "'-1'", "'0001-01-01'", "'0001-01-01'", 
        "NOT NULL", "'0'", "'0'", "'0'", "'0'", "'0'", "NOT NULL", "'0'", 
        "'0'", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", 
        "NOT NULL", "'0001-01-01'", "CURRENT_TIMESTAMP", "'0001-01-01'", 
        "'0001-01-01'", "NOT NULL", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "FOREIGN KEY", "FOREIGN KEY", "FOREIGN KEY", 
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "FOREIGN KEY", 
        "FOREIGN KEY", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", 
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", 
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", 
        "FOREIGN KEY", "FOREIGN KEY", "NONE", "FOREIGN KEY", "FOREIGN KEY", 
        "FOREIGN KEY", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE"
    ],
    "References": [
        "Self", "Procedure(ProcNum)", "Claim(ClaimNum)", "Patient(PatNum)", 
        "Provider(ProvNum)", "None", "None", "None", "None", "None", 
        "None", "ClaimPayment(ClaimPaymentNum)", "Plan(PlanNum)", "None", 
        "None", "None", "None", "None", "None", "None", "None", "None", 
        "None", "None", "None", "None", "None", "None", "None", "None", 
        "None", "None", "None", "None", "None", "None", "Clinic(ClinicNum)", 
        "InsuranceSub(InsSubNum)", "None", "PayPlan(PayPlanNum)", 
        "ClaimPaymentTracking(ClaimPaymentTracking)", "User(SecUserNumEntry)", 
        "None", "None", "None", "None", "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in claimproc_data.values())

# Ensure all lists are of equal length by padding with None
for key in claimproc_data:
    current_length = len(claimproc_data[key])
    if current_length < max_length:
        claimproc_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_claimproc = pd.DataFrame(claimproc_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_claimproc = os.path.join(project_root, "docs", "claimproc_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_claimproc.to_csv(file_path_claimproc, index=False)
