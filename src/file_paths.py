# file_paths.py

# Dictionary of file paths for exports
file_paths = {
    "proceduretp": r"C:\Users\rains\mdc_analytics\raw_data\temp_proceduretp_data.csv",
    "procedure_measure": r"C:\Users\rains\mdc_analytics\raw_data\temp_procedure_measure_data.csv",
    "procedurelog": r"C:\Users\rains\mdc_analytics\raw_data\temp_procedurelog_data.csv",
    "procedurecode": r"C:\Users\rains\mdc_analytics\raw_data\temp_procedurecode_data.csv",
    "paysplit": r"C:\Users\rains\mdc_analytics\raw_data\temp_paysplit_data.csv",
    "payment": r"C:\Users\rains\mdc_analytics\raw_data\temp_payment_data.csv",
    "perioexam": r"C:\Users\rains\mdc_analytics\raw_data\temp_perioexam_data.csv",
    "commlog": r"C:\Users\rains\mdc_analytics\raw_data\temp_commlog_data.csv",
    "claim": r"C:\Users\rains\mdc_analytics\raw_data\temp_claim_data.csv",
    "appointment": r"C:\Users\rains\mdc_analytics\raw_data\temp_appointment_data.csv",
    "adjustment": r"C:\Users\rains\mdc_analytics\raw_data\temp_adjustment_data.csv"
}

# Retrieve paths by key
def get_file_path(key):
    return file_paths.get(key, None)
