import pandas as pd
from datetime import datetime
import os
from src.db_config import connect_to_mariadb
import mysql.connector
from mysql.connector import Error
import re

def clean_tooth_number(tooth_str):
    """Clean tooth number string to valid integer"""
    # Replace common OCR errors and typos
    replacements = {
        'O': '0',
        'o': '0',
        'K': '0',
        'k': '0',
        'l': '1',
        'I': '1',
        'i': '1'
    }
    
    # Apply replacements
    cleaned = str(tooth_str)
    for old, new in replacements.items():
        cleaned = cleaned.replace(old, new)
    
    # Extract only digits
    digits = re.sub(r'[^0-9]', '', cleaned)
    
    # Return None if no valid digits found
    if not digits:
        return None
        
    return int(digits)

def get_tooth_description(tooth_num):
    """Get anatomical description for a tooth number"""
    # Clean the tooth number
    cleaned_num = clean_tooth_number(tooth_num)
    if cleaned_num is None:
        return f"{tooth_num} (Invalid)"
    
    tooth_num = cleaned_num
    arch = "Upper" if tooth_num <= 16 else "Lower"
    
    if tooth_num in (6,11,22,27):
        position = "Canine"
    elif tooth_num in (7,8,9,10,23,24,25,26):
        position = "Front"
    elif tooth_num in (3,14,19,30):
        position = "First Molar"
    elif tooth_num in (4,5,12,13,20,21,28,29):
        position = "Premolar"
    elif tooth_num in (2,15,18,31):
        position = "Second Molar"
    else:
        position = "Other"
    
    return f"{tooth_num} ({arch} {position})"

def export_missing_teeth_followup(database_name=None):
    """Export missing teeth analysis data to CSV and Parquet"""
    try:
        # Create connection using existing function
        conn = connect_to_mariadb(database_name)
        cursor = conn.cursor(buffered=True)
        
        # First query: Get list of patients with missing teeth
        patient_query = """
        SELECT DISTINCT
            p.PatNum,
            CONCAT(
                COALESCE(NULLIF(TRIM(p.LName), ''), ''),
                CASE WHEN TRIM(p.LName) > '' AND TRIM(p.FName) > '' THEN ', ' ELSE '' END,
                COALESCE(NULLIF(TRIM(p.FName), ''), '')
            ) AS PatientName
        FROM patient p
        INNER JOIN toothinitial ti ON p.PatNum = ti.PatNum
        WHERE ti.InitialType = 0
            AND p.PatStatus = 0
        """
        cursor.execute(patient_query)
        
        # Convert to list of dicts
        columns = [col[0] for col in cursor.description]
        patients = [dict(zip(columns, row)) for row in cursor.fetchall()]
        
        if not patients:
            print("No patients found")
            return
            
        # Second query: Get missing teeth for each patient
        teeth_query = """
        SELECT 
            PatNum,
            ToothNum
        FROM toothinitial
        WHERE InitialType = 0
            AND PatNum = %s
        """
        
        # Process each patient
        all_data = []
        for patient in patients:
            cursor.execute(teeth_query, (patient['PatNum'],))
            
            # Convert to list of dicts
            teeth_columns = [col[0] for col in cursor.description]
            teeth = [dict(zip(teeth_columns, row)) for row in cursor.fetchall()]
            
            # Clean and filter tooth numbers
            valid_teeth = []
            for tooth in teeth:
                cleaned_num = clean_tooth_number(tooth['ToothNum'])
                if cleaned_num and cleaned_num not in (1,16,17,32):
                    valid_teeth.append(str(cleaned_num))
            
            if not valid_teeth:
                continue
                
            # Get list of missing teeth
            tooth_nums = valid_teeth
            missing_teeth_str = ','.join(tooth_nums)
            
            # Calculate counts
            tooth_count = len(tooth_nums)
            anterior_count = sum(1 for t in tooth_nums if t in ('7','8','9','10','23','24','25','26'))
            molar_count = sum(1 for t in tooth_nums if t in ('3','14','19','30'))
            
            # Determine recommendations
            if tooth_count == 1:
                recommendation = 'Single Tooth Implant Candidate'
            elif 2 <= tooth_count <= 3 and any(t in ('7','8','9','10') for t in tooth_nums):
                recommendation = 'Anterior Bridge/Implant Candidate'
            elif 2 <= tooth_count <= 4:
                recommendation = 'Multiple Implant Candidate'
            elif 4 < tooth_count < 10:
                recommendation = 'Full Arch Implant Candidate'
            elif tooth_count >= 10:
                recommendation = 'All-on-4/6 Candidate'
            else:
                recommendation = 'Review Needed'
            
            # Add to results
            all_data.append({
                'PatNum': patient['PatNum'],
                'PatientName': patient['PatientName'],
                'MissingTeeth': missing_teeth_str,
                'MissingTeethCount': tooth_count,
                'MissingTeethDescriptions': ', '.join(get_tooth_description(t) for t in tooth_nums),
                'HasMissingAnteriorTeeth': 'Yes' if anterior_count > 0 else 'No',
                'HasMissingFirstMolars': 'Yes' if molar_count > 0 else 'No',
                'ImplantRecommendation': recommendation
            })
        
        # Convert to final DataFrame
        df = pd.DataFrame(all_data)
        
        # Create exports directory if it doesn't exist
        export_dir = "data/processed"
        os.makedirs(export_dir, exist_ok=True)
        
        # Generate timestamp for file names
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Export to Parquet
        parquet_path = f"{export_dir}/missing_teeth_followup_{timestamp}.parquet"
        df.to_parquet(parquet_path, index=False)
        print(f"Parquet exported to: {parquet_path}")
        
        # Export to CSV
        csv_path = f"{export_dir}/missing_teeth_followup_{timestamp}.csv"
        df.to_csv(csv_path, index=False)
        print(f"CSV exported to: {csv_path}")
        
        # Print summary
        print("\nExport Summary:")
        print(f"Database: {database_name if database_name else 'Default DB in db_config'}")
        print(f"Total records: {len(df)}")
        print(f"Columns: {', '.join(df.columns)}")
        print("\nImplant Candidate Summary:")
        print(df['ImplantRecommendation'].value_counts())
        print("\nAnterior Teeth Missing:")
        print(df['HasMissingAnteriorTeeth'].value_counts())
        
    except Error as e:
        print(f"Error: {str(e)}")
        raise
    
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    export_missing_teeth_followup()