
SELECT * 
INTO OUTFILE "C:\Users\rains\mdc_analytics\raw_data/temp_patients.csv"
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
FROM temp_patients;

-- export patient data for use in modeling workflow
