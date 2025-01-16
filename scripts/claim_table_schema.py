import pandas as pd
import os

# Define the claim table schema information with primary and foreign keys
claim_data = {
    "Column Name": [
        "ClaimNum", "PatNum", "DateService", "DateSent", "ClaimStatus", "DateReceived",
        "PlanNum", "ProvTreat", "ClaimFee", "InsPayEst", "InsPayAmt", "DedApplied",
        "PreAuthString", "IsProsthesis", "PriorDate", "ReasonUnderPaid", "ClaimNote",
        "ClaimType", "ProvBill", "ReferringProv", "RefNumString", "PlaceService",
        "AccidentRelated", "AccidentDate", "AccidentST", "EmployRelated", "IsOrtho",
        "OrthoRemainM", "OrthoDate", "PatRelat", "PlanNum2", "PatRelat2", "WriteOff",
        "Radiographs", "ClinicNum", "ClaimForm", "AttachedImages", "AttachedModels",
        "AttachedFlags", "AttachmentID", "CanadianMaterialsForwarded",
        "CanadianReferralProviderNum", "CanadianReferralReason", "CanadianIsInitialLower",
        "CanadianDateInitialLower", "CanadianMandProsthMaterial", "CanadianIsInitialUpper",
        "CanadianDateInitialUpper", "CanadianMaxProsthMaterial", "InsSubNum", "InsSubNum2",
        "CanadaTransRefNum", "CanadaEstTreatStartDate", "CanadaInitialPayment",
        "CanadaPaymentMode", "CanadaTreatDuration", "CanadaNumAnticipatedPayments",
        "CanadaAnticipatedPayAmount", "PriorAuthorizationNumber", "SpecialProgramCode",
        "UniformBillType", "MedType", "AdmissionTypeCode", "AdmissionSourceCode",
        "PatientStatusCode", "CustomTracking", "DateResent", "CorrectionType",
        "ClaimIdentifier", "OrigRefNum", "ProvOrderOverride", "OrthoTotalM", "ShareOfCost",
        "SecUserNumEntry", "SecDateEntry", "SecDateTEdit", "OrderingReferralNum",
        "DateSentOrig", "DateIllnessInjuryPreg", "DateIllnessInjuryPregQualifier",
        "DateOther", "DateOtherQualifier", "IsOutsideLab"
    ],
    "Data Type": [
        "bigint(20)", "bigint(20)", "date", "date", "char(1)", "date", "bigint(20)",
        "bigint(20)", "double", "double", "double", "double", "varchar(40)", "char(1)",
        "date", "varchar(255)", "varchar(400)", "varchar(255)", "bigint(20)", "bigint(20)",
        "varchar(40)", "tinyint(3) unsigned", "char(1)", "date", "varchar(2)",
        "tinyint(3) unsigned", "tinyint(1) unsigned", "tinyint(3) unsigned", "date",
        "tinyint(3) unsigned", "bigint(20)", "tinyint(3) unsigned", "double",
        "tinyint(3) unsigned", "bigint(20)", "bigint(20)", "int(11)", "int(11)", "varchar(255)",
        "varchar(255)", "varchar(10)", "varchar(20)", "tinyint(4)", "varchar(5)",
        "date", "tinyint(4)", "varchar(5)", "date", "tinyint(4)", "bigint(20)",
        "bigint(20)", "varchar(255)", "date", "double", "tinyint(3) unsigned",
        "tinyint(3) unsigned", "tinyint(3) unsigned", "double", "varchar(255)", "tinyint(4)",
        "varchar(255)", "tinyint(4)", "varchar(255)", "varchar(255)", "varchar(255)",
        "bigint(20)", "date", "tinyint(4)", "varchar(255)", "varchar(255)", "bigint(20)",
        "tinyint(3) unsigned", "double", "bigint(20)", "date", "timestamp", "bigint(20)",
        "date", "date", "smallint(6)", "date", "smallint(6)", "tinyint(4)"
    ],
    "Default Value": [
        "AUTO_INCREMENT", "NOT NULL", "'0001-01-01'", "'0001-01-01'", "''",
        "'0001-01-01'", "NOT NULL", "NOT NULL", "'0'", "'0'", "'0'", "'0'", "''", "''",
        "'0001-01-01'", "''", "NULL", "''", "NOT NULL", "NOT NULL", "''", "'0'", "''",
        "'0001-01-01'", "''", "'0'", "'0'", "'0'", "'0001-01-01'", "'0'", "NOT NULL",
        "'0'", "'0'", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NULL", "NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "'0001-01-01'", "NOT NULL",
        "NOT NULL", "'0001-01-01'", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "'0001-01-01'", "'0'", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL",
        "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "NOT NULL", "'0001-01-01'",
        "'0001-01-01'", "NULL", "'0001-01-01'", "NULL", "'0'"
    ],
    "Key Type": [
        "PRIMARY KEY", "FOREIGN KEY", "NONE", "NONE", "NONE", "NONE", "FOREIGN KEY",
        "FOREIGN KEY", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "FOREIGN KEY", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "FOREIGN KEY", "NONE", "NONE", "NONE", "NONE",
        "FOREIGN KEY", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE",
        "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE", "NONE"
    ],
    "References": [
        "Self", "Patient(PatNum)", "None", "None", "None", "None", "Plan(PlanNum)",
        "Provider(ProvTreat)", "None", "None", "None", "None", "None", "None", "None",
        "None", "None", "None", "Provider(ProvBill)", "None", "None", "None", "None",
        "None", "None", "None", "None", "None", "None", "Plan(PlanNum2)", "None",
        "None", "None", "None", "Clinic(ClinicNum)", "None", "None", "None", "None",
        "None", "None", "None", "None", "None", "None", "None", "None", "None", "None",
        "None", "None", "None", "None", "None", "None", "None", "None", "None", "None",
        "None", "None", "None", "None", "None", "None", "None", "None", "None", "None",
        "None"
    ]
}

# Find the maximum length of lists in the dictionary
max_length = max(len(lst) for lst in claim_data.values())

# Ensure all lists are of equal length by padding with None
for key in claim_data:
    current_length = len(claim_data[key])
    if current_length < max_length:
        claim_data[key].extend([None] * (max_length - current_length))

# Create DataFrame
df_claim = pd.DataFrame(claim_data)

# Get project root and set output path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
file_path_claim = os.path.join(project_root, "docs", "claim_table_schema_with_keys.csv")

# Save the DataFrame to CSV
df_claim.to_csv(file_path_claim, index=False)
