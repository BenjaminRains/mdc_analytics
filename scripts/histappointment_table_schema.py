import pandas as pd
import os

# Define the histappointment table schema information with primary and foreign keys
histappointment_data = {
    "Column Name": [
        "HistApptNum", "HistUserNum", "HistDateTStamp", "HistApptAction", "ApptSource",
        "AptNum", "PatNum", "AptStatus", "Pattern", "Confirmed", "TimeLocked", "Op",
        "Note", "ProvNum", "ProvHyg", "AptDateTime", "NextAptNum", "UnschedStatus",
        "IsNewPatient", "ProcDescript", "Assistant", "ClinicNum", "IsHygiene",
        "DateTStamp", "DateTimeArrived", "DateTimeSeated", "DateTimeDismissed",
        "InsPlan1", "InsPlan2", "DateTimeAskedToArrive", "ProcsColored",
        "ColorOverride", "AppointmentTypeNum", "SecUserNumEntry", "SecDateTEntry",
        "Priority", "ProvBarText", "PatternSecondary", "SecurityHash"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "datetime", "tinyint(4)", "tinyint(4)",
        "bigint(20)", "bigint(20)", "tinyint(4)", "varchar(255)", "bigint(20)",
        "tinyint(4)", "bigint(20)", "text", "bigint(20)", "bigint(20)", "datetime",
        "bigint(20)", "bigint(20)", "tinyint(4)", "varchar(255)", "bigint(20)",
        "bigint(20)", "tinyint(4)", "timestamp", "datetime", "datetime", "datetime",
        "bigint(20)", "bigint(20)", "datetime", "text", "int(11)", "bigint(20)",
        "bigint(20)", "datetime", "tinyint(4)", "varchar(60)", "varchar(255)",
        "varchar(255)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "'0001-01-01 00:00:00'", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "'0001-01-01 00:00:00'",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "CURRENT_TIMESTAMP", "'0001-01-01 00:00:00'",
        "'0001-01-01 00:00:00'", "'0001-01-01 00:00:00'", "NOT NULL", "NOT NULL",
        "'0001-01-01 00:00:00'", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "'0001-01-01 00:00:00'", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "NONE", "NONE", "NONE",
        "FOREIGN KEY", "FOREIGN KEY", "NONE", "NONE", "FOREIGN KEY",
        "NONE", "FOREIGN KEY", "NONE", "FOREIGN KEY", "FOREIGN KEY",
        "NONE", "FOREIGN KEY", "FOREIGN KEY", "NONE", "NONE",
        "FOREIGN KEY", "FOREIGN KEY", "NONE", "NONE", "NONE",
        "NONE", "NONE", "FOREIGN KEY", "FOREIGN KEY", "NONE",
        "NONE", "NONE", "FOREIGN KEY", "FOREIGN KEY", "NONE",
        "NONE", "NONE", "NONE", "NONE"
    ],
    "References": [
        "Self", "User(HistUserNum)", "None", "None", "None",
        "Appointment(AptNum)", "Patient(PatNum)", "None", "None", "Definition(Confirmed)",
        "None", "Provider(Op)", "None", "Provider(ProvNum)", "Provider(ProvHyg)",
        "None", "Appointment(NextAptNum)", "Definition(UnschedStatus)", "None", "None",
        "Provider(Assistant)", "Clinic(ClinicNum)", "None", "None", "None",
        "None", "None", "InsPlan(InsPlan1)", "InsPlan(InsPlan2)", "None",
        "None", "None", "AppointmentType(AppointmentTypeNum)", "User(SecUserNumEntry)", "None",
        "None", "None", "None", "None"
    ]
}

# Create DataFrame
df_histappointment = pd.DataFrame(histappointment_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_histappointment = os.path.join(project_root, "docs", "histappointment_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_histappointment.to_csv(file_path_histappointment, index=False) 