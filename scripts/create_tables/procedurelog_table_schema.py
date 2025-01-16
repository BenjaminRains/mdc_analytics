import pandas as pd
import os

# Define the procedurelog table schema information with primary and foreign keys
procedurelog_data = {
    "Column Name": [
        "ProcNum", "PatNum", "AptNum", "OldCode", "ProcDate", "ProcFee", "Surf",
        "ToothNum", "ToothRange", "Priority", "ProcStatus", "ProvNum", "Dx",
        "PlannedAptNum", "PlaceService", "Prosthesis", "DateOriginalProsth",
        "ClaimNote", "DateEntryC", "ClinicNum", "MedicalCode", "DiagnosticCode",
        "IsPrincDiag", "ProcNumLab", "BillingTypeOne", "BillingTypeTwo", "CodeNum",
        "CodeMod1", "CodeMod2", "CodeMod3", "CodeMod4", "RevCode", "UnitQty",
        "BaseUnits", "StartTime", "StopTime", "DateTP", "SiteNum", "HideGraphics",
        "CanadianTypeCodes", "ProcTime", "ProcTimeEnd", "DateTStamp", "Prognosis",
        "DrugUnit", "DrugQty", "UnitQtyType", "StatementNum", "IsLocked",
        "BillingNote", "RepeatChargeNum", "SnomedBodySite", "DiagnosticCode2",
        "DiagnosticCode3", "DiagnosticCode4", "ProvOrderOverride", "Discount",
        "IsDateProsthEst", "IcdVersion", "IsCpoe", "SecUserNumEntry", "SecDateEntry",
        "DateComplete", "OrderingReferralNum", "TaxAmt", "Urgency", "DiscountPlanAmt"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "bigint(20)", "varchar(15)", "date", "double",
        "varchar(10)", "varchar(2)", "varchar(100)", "bigint(20)", 
        "tinyint(3) unsigned", "bigint(20)", "bigint(20)", "bigint(20)",
        "tinyint(3) unsigned", "char(1)", "date", "varchar(80)", "date", "bigint(20)",
        "varchar(15)", "varchar(255)", "tinyint(3) unsigned", "bigint(20)",
        "bigint(20)", "bigint(20)", "bigint(20)", "char(2)", "char(2)", "char(2)",
        "char(2)", "varchar(45)", "int(11)", "int(11)", "int(11)", "int(11)",
        "date", "bigint(20)", "tinyint(4)", "varchar(20)", "time", "time",
        "timestamp", "bigint(20)", "tinyint(4)", "float", "tinyint(4)", "bigint(20)",
        "tinyint(4)", "varchar(255)", "bigint(20)", "varchar(255)", "varchar(255)",
        "varchar(255)", "varchar(255)", "bigint(20)", "double", "tinyint(4)",
        "tinyint(3) unsigned", "tinyint(4)", "bigint(20)", "datetime", "date",
        "bigint(20)", "double", "tinyint(4)", "double"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "NOT NULL", "''", "'0001-01-01'", "'0'", "''",
        "''", "''", "NOT NULL", "'0'", "NOT NULL", "NOT NULL", "NOT NULL", "'0'",
        "''", "'0001-01-01'", "''", "'0001-01-01'", "NOT NULL", "''", "''",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NULL", "NULL",
        "NULL", "NULL", "NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "CURRENT_TIMESTAMP", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "'0001-01-01 00:00:00'", "'0001-01-01'", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "INDEX", "INDEX", "NONE", "INDEX", "INDEX", "NONE", "NONE",
        "NONE", "INDEX", "INDEX", "INDEX", "NONE", "FOREIGN KEY", "NONE", "NONE",
        "NONE", "NONE", "NONE", "FOREIGN KEY", "NONE", "NONE", "NONE",
        "FOREIGN KEY", "FOREIGN KEY", "FOREIGN KEY", "FOREIGN KEY", "NONE", "NONE",
        "NONE", "NONE", "NONE", "INDEX", "INDEX", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE", "INDEX", "FOREIGN KEY", "NONE",
        "NONE", "NONE", "FOREIGN KEY", "NONE", "NONE", "FOREIGN KEY", "NONE",
        "NONE", "NONE", "NONE", "FOREIGN KEY", "NONE", "NONE", "NONE", "NONE",
        "FOREIGN KEY", "NONE", "INDEX", "FOREIGN KEY", "NONE", "NONE", "NONE"
    ],
    "References": [
        "Self", "Patient(PatNum)", "Appointment(AptNum)", "None", "None", "None",
        "None", "None", "None", "Definition(Priority)", "None", "Provider(ProvNum)",
        "None", "Appointment(PlannedAptNum)", "None", "None", "None", "None",
        "None", "Clinic(ClinicNum)", "None", "None", "None",
        "ProcedureLog(ProcNumLab)", "Definition(BillingTypeOne)",
        "Definition(BillingTypeTwo)", "ProcedureCode(CodeNum)", "None", "None",
        "None", "None", "None", "None", "None", "None", "None", "None", "None",
        "None", "None", "None", "None", "None", "Definition(Prognosis)", "None",
        "None", "None", "Statement(StatementNum)", "None", "None",
        "RepeatCharge(RepeatChargeNum)", "None", "None", "None", "None",
        "Provider(ProvOrderOverride)", "None", "None", "None", "None",
        "User(SecUserNumEntry)", "None", "None", "Referral(OrderingReferralNum)",
        "None", "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in procedurelog_data.values())

# Ensure all lists are of equal length by padding with None
for key in procedurelog_data:
    current_length = len(procedurelog_data[key])
    if current_length < max_length:
        procedurelog_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_procedurelog = pd.DataFrame(procedurelog_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_procedurelog = os.path.join(project_root, "docs", "procedurelog_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_procedurelog.to_csv(file_path_procedurelog, index=False) 