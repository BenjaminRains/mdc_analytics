import pandas as pd
import os

# Define the patient table schema information with primary and foreign keys
patient_data = {
    "Column Name": [
        "PatNum", "LName", "FName", "MiddleI", "Preferred", "PatStatus", "Gender", 
        "Position", "Birthdate", "SSN", "Address", "Address2", "City", "State", "Zip",
        "HmPhone", "WkPhone", "WirelessPhone", "Guarantor", "CreditType", "Email",
        "Salutation", "EstBalance", "PriProv", "SecProv", "FeeSched", "BillingType",
        "ImageFolder", "AddrNote", "FamFinUrgNote", "MedUrgNote", "ApptModNote",
        "StudentStatus", "SchoolName", "ChartNumber", "MedicaidID", "Bal_0_30",
        "Bal_31_60", "Bal_61_90", "BalOver90", "InsEst", "BalTotal", "EmployerNum",
        "EmploymentNote", "County", "GradeLevel", "Urgency", "DateFirstVisit",
        "ClinicNum", "HasIns", "TrophyFolder", "PlannedIsDone", "Premed", "Ward",
        "PreferConfirmMethod", "PreferContactMethod", "PreferRecallMethod",
        "SchedBeforeTime", "SchedAfterTime", "SchedDayOfWeek", "Language",
        "AdmitDate", "Title", "PayPlanDue", "SiteNum", "DateTStamp", "ResponsParty",
        "CanadianEligibilityCode", "AskToArriveEarly", "PreferContactConfidential",
        "SuperFamily", "TxtMsgOk", "SmokingSnoMed", "Country", "DateTimeDeceased",
        "BillingCycleDay", "SecUserNumEntry", "SecDateEntry", "HasSuperBilling",
        "PatNumCloneFrom", "DiscountPlanNum", "HasSignedTil", "ShortCodeOptIn",
        "SecurityHash"
    ],
    "Data Type": [
        "bigint(20)", "varchar(100)", "varchar(100)", "varchar(100)", "varchar(100)",
        "tinyint(3) unsigned", "tinyint(3) unsigned", "tinyint(3) unsigned", "date",
        "varchar(100)", "varchar(100)", "varchar(100)", "varchar(100)", "varchar(100)",
        "varchar(100)", "varchar(30)", "varchar(30)", "varchar(30)", "bigint(20)",
        "char(1)", "varchar(100)", "varchar(100)", "double", "bigint(20)", "bigint(20)",
        "bigint(20)", "bigint(20)", "varchar(100)", "text", "text", "varchar(255)",
        "varchar(255)", "char(1)", "varchar(255)", "varchar(20)", "varchar(20)",
        "double", "double", "double", "double", "double", "double", "bigint(20)",
        "varchar(255)", "varchar(255)", "tinyint(4)", "tinyint(4)", "date",
        "bigint(20)", "varchar(255)", "varchar(255)", "tinyint(3) unsigned",
        "tinyint(3) unsigned", "varchar(255)", "tinyint(3) unsigned",
        "tinyint(3) unsigned", "tinyint(3) unsigned", "time", "time",
        "tinyint(3) unsigned", "varchar(100)", "date", "varchar(15)", "double",
        "bigint(20)", "timestamp", "bigint(20)", "tinyint(4)", "int(11)",
        "tinyint(4)", "bigint(20)", "tinyint(4)", "varchar(32)", "varchar(255)",
        "datetime", "int(11)", "bigint(20)", "date", "tinyint(4)", "bigint(20)",
        "bigint(20)", "tinyint(4)", "tinyint(4)", "varchar(255)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "''", "''", "''", "''", "'0'", "'0'", "'0'",
        "'0001-01-01'", "''", "''", "''", "''", "''", "''", "''", "''", "''",
        "NOT NULL", "''", "''", "''", "'0'", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "''", "NULL", "NULL", "''", "''", "''", "NOT NULL", "''", "''",
        "'0'", "'0'", "'0'", "'0'", "'0'", "'0'", "NOT NULL", "''", "''", "'0'",
        "'0'", "'0001-01-01'", "NOT NULL", "''", "''", "NOT NULL", "NOT NULL", "''",
        "NOT NULL", "NOT NULL", "NOT NULL", "NULL", "NULL", "NOT NULL", "''",
        "'0001-01-01'", "NULL", "NOT NULL", "NOT NULL", "CURRENT_TIMESTAMP",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "'0001-01-01 00:00:00'", "'1'", "NOT NULL",
        "'0001-01-01'", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "INDEX", "INDEX", "NONE", "NONE", "INDEX", "NONE", "NONE",
        "INDEX", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "INDEX", "INDEX",
        "INDEX", "FOREIGN KEY", "NONE", "INDEX", "NONE", "NONE", "FOREIGN KEY",
        "FOREIGN KEY", "FOREIGN KEY", "NONE", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "INDEX", "NONE", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "FOREIGN KEY", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "FOREIGN KEY", "NONE", "FOREIGN KEY", "NONE", "NONE", "NONE",
        "FOREIGN KEY", "NONE", "NONE", "NONE", "NONE", "NONE", "FOREIGN KEY",
        "INDEX", "NONE", "FOREIGN KEY", "FOREIGN KEY", "NONE", "NONE", "NONE"
    ],
    "References": [
        "Self", "None", "None", "None", "None", "None", "None", "None", "None",
        "None", "None", "None", "None", "None", "None", "None", "None", "None",
        "Patient(Guarantor)", "None", "None", "None", "None", "Provider(PriProv)",
        "Provider(SecProv)", "FeeSched(FeeSched)", "None", "None", "None", "None",
        "None", "None", "None", "None", "None", "None", "None", "None", "None",
        "None", "None", "None", "None", "None", "None", "None", "None", "None",
        "Clinic(ClinicNum)", "None", "None", "None", "None", "None", "None",
        "None", "None", "None", "None", "None", "None", "None", "None", "None",
        "None", "Site(SiteNum)", "None", "ResponsibleParty(ResponsParty)", "None",
        "None", "None", "SuperFamily(SuperFamily)", "None", "None", "None", "None",
        "None", "User(SecUserNumEntry)", "None", "None", "Patient(PatNumCloneFrom)",
        "DiscountPlan(DiscountPlanNum)", "None", "None", "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in patient_data.values())

# Ensure all lists are of equal length by padding with None
for key in patient_data:
    current_length = len(patient_data[key])
    if current_length < max_length:
        patient_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_patient = pd.DataFrame(patient_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_patient = os.path.join(project_root, "docs", "patient_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_patient.to_csv(file_path_patient, index=False) 