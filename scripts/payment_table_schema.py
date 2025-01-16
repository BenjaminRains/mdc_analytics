import pandas as pd
import os

# Define the payment table schema information with primary and foreign keys
payment_data = {
    "Column Name": [
        "PayNum", "PayType", "PayDate", "PayAmt", "CheckNum", "BankBranch", 
        "PayNote", "IsSplit", "PatNum", "ClinicNum", "DateEntry", "DepositNum",
        "Receipt", "IsRecurringCC", "SecUserNumEntry", "SecDateTEdit", 
        "PaymentSource", "ProcessStatus", "RecurringChargeDate", "ExternalId",
        "PaymentStatus", "IsCcCompleted", "MerchantFee"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "date", "double", "varchar(25)", "varchar(25)",
        "text", "tinyint(1) unsigned", "bigint(20)", "bigint(20)", "date", "bigint(20)",
        "text", "tinyint(4)", "bigint(20)", "timestamp", "tinyint(4)", "tinyint(4)",
        "date", "varchar(255)", "tinyint(4)", "tinyint(4)", "double"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "'0001-01-01'", "'0'", "''", "''",
        "NOT NULL", "'0'", "NOT NULL", "NOT NULL", "'0001-01-01'", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "CURRENT_TIMESTAMP", "NOT NULL", "NOT NULL",
        "'0001-01-01'", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "FOREIGN KEY", "FOREIGN KEY", "NONE", "FOREIGN KEY",
        "NONE", "NONE", "FOREIGN KEY", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE"
    ],
    "References": [
        "Self", "Definition(PayType)", "None", "None", "None", "None",
        "None", "None", "Patient(PatNum)", "Clinic(ClinicNum)", "None", "Deposit(DepositNum)",
        "None", "None", "User(SecUserNumEntry)", "None", "None", "None",
        "None", "None", "None", "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in payment_data.values())

# Ensure all lists are of equal length by padding with None
for key in payment_data:
    current_length = len(payment_data[key])
    if current_length < max_length:
        payment_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_payment = pd.DataFrame(payment_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_payment = os.path.join(project_root, "docs", "payment_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_payment.to_csv(file_path_payment, index=False) 