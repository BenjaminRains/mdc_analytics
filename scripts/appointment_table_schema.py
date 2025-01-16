import pandas as pd
import os

# Define the appointment table schema information with primary and foreign keys
appointment_data = {
    "Column Name": [
        "AptNum", "PatNum", "AptStatus", "Pattern", "Confirmed", "TimeLocked", 
        "Op", "Note", "ProvNum", "ProvHyg", "AptDateTime", "NextAptNum", 
        "UnschedStatus", "IsNewPatient", "ProcDescript", "Assistant", "ClinicNum", 
        "IsHygiene", "DateTStamp", "DateTimeArrived", "DateTimeSeated", 
        "DateTimeDismissed", "InsPlan1", "InsPlan2", "DateTimeAskedToArrive", 
        "ProcsColored", "ColorOverride", "AppointmentTypeNum", "SecUserNumEntry", 
        "SecDateTEntry", "Priority", "ProvBarText", "PatternSecondary", 
        "SecurityHash"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "tinyint(3) unsigned", "varchar(255)", 
        "bigint(20)", "tinyint(1)", "bigint(20)", "text", "bigint(20)", 
        "bigint(20)", "datetime", "bigint(20)", "bigint(20)", "tinyint(1) unsigned", 
        "varchar(255)", "bigint(20)", "bigint(20)", "tinyint(3) unsigned", 
        "timestamp", "datetime", "datetime", "datetime", "bigint(20)", 
        "bigint(20)", "datetime", "text", "int(11)", "bigint(20)", "bigint(20)", 
        "datetime", "tinyint(4)", "varchar(60)", "varchar(255)", "varchar(255)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "'0'", "''", "NOT NULL", "NOT NULL", 
        "NOT NULL", "NULL", "NOT NULL", "NOT NULL", "'0001-01-01 00:00:00'", 
        "NOT NULL", "NOT NULL", "'0'", "''", "NOT NULL", "NOT NULL", "NOT NULL", 
        "CURRENT_TIMESTAMP", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", 
        "NOT NULL", "'0001-01-01 00:00:00'", "NOT NULL", "NOT NULL", "NOT NULL", 
        "'0001-01-01 00:00:00'", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "NONE", "NONE", "FOREIGN KEY", "NONE", 
        "FOREIGN KEY", "NONE", "FOREIGN KEY", "FOREIGN KEY", "NONE", "FOREIGN KEY", 
        "FOREIGN KEY", "NONE", "NONE", "FOREIGN KEY", "FOREIGN KEY", "NONE", 
        "NONE", "NONE", "NONE", "NONE", "FOREIGN KEY", "FOREIGN KEY", "NONE", 
        "NONE", "NONE", "FOREIGN KEY", "FOREIGN KEY", "NONE", "NONE", "NONE", 
        "NONE"
    ],
    "References": [
        "Self", "Patient(PatNum)", "None", "None", "Confirmation(Confirmed)", 
        "None", "Operator(Op)", "None", "Provider(ProvNum)", "Provider(ProvHyg)", 
        "None", "Appointment(NextAptNum)", "UnschedStatus(UnschedStatus)", 
        "None", "None", "Assistant(Assistant)", "Clinic(ClinicNum)", "None", 
        "None", "None", "None", "None", "Insurance(InsPlan1)", "Insurance(InsPlan2)", 
        "None", "None", "None", "AppointmentType(AppointmentTypeNum)", 
        "User(SecUserNumEntry)", "None", "None", "None", "None"
    ]
}

# Correct the mismatch by checking the lengths of all lists
max_length = max(len(lst) for lst in appointment_data.values())

# Ensure all lists are of equal length by padding with 'None' or an appropriate placeholder
for key in appointment_data:
    current_length = len(appointment_data[key])
    if current_length < max_length:
        appointment_data[key].extend([None] * (max_length - current_length))

# Create DataFrame and save to CSV
df_appointment = pd.DataFrame(appointment_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_appointment = os.path.join(project_root, "docs", "appointment_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_appointment.to_csv(file_path_appointment, index=False)
