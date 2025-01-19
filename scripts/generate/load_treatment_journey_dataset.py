import pandas as pd
import os
from sqlalchemy import create_engine, text
from src.db_config import validate_backup_schema
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def load_treatment_journey_data(backup_date="opendentalbackup_01_03_2025", limit=None):
    """
    Loads treatment journey data from the specified backup database into a pandas DataFrame
    """
    # Validate the backup database
    if not validate_backup_schema(backup_date):
        raise ValueError(f"Invalid backup database: {backup_date}")
    
    # Read the SQL query from file
    with open('scripts/treatment_journey_ml.sql', 'r') as file:
        query = file.read()
    
    # Remove the USE statement and handle database in connection
    query = query.split(';', 1)[1].strip()
    
    # Add LIMIT clause if specified
    if limit:
        query = query.replace('LIMIT 1000', f'LIMIT {limit}')
    
    # Create SQLAlchemy engine with timeout settings
    db_password = os.getenv('MDC_DB_PASSWORD')
    connection_url = (
        f"mysql+mysqlconnector://bpr:{db_password}@192.168.2.10:3306/{backup_date}"
        "?connect_timeout=300"
    )
    
    engine = create_engine(
        connection_url,
        pool_recycle=3600,
        pool_pre_ping=True
    )
    
    try:
        print(f"Loading data from {backup_date}...")
        print("This may take several minutes...")
        
        # Execute query with chunking
        chunks = []
        with engine.connect() as connection:
            result = connection.execute(text(query))
            while True:
                chunk = result.fetchmany(10000)
                if not chunk:
                    break
                df_chunk = pd.DataFrame(chunk, columns=result.keys())
                chunks.append(df_chunk)
                print(f"Loaded {len(chunks) * 10000:,} rows...", end='\r')
        
        df = pd.concat(chunks, ignore_index=True)
        
        # Convert date columns to datetime
        date_columns = ['ProcDate', 'PlanDate']
        for col in date_columns:
            df[col] = pd.to_datetime(df[col])
            
        # Convert boolean columns
        bool_columns = ['IsHygiene', 'IsMultiVisit', 'target_accepted', 'target_paid_30d']
        for col in bool_columns:
            if col in df.columns:
                df[col] = df[col].astype(bool)
                
        # Convert numeric columns
        numeric_columns = {
            'int': ['PatNum', 'ProcNum', 'PatientAge', 'FamilyMemberCount', 
                   'PastProcedures', 'PastCompletedProcedures', 'DayOfWeek', 'Month'],
            'float': ['PlannedFee', 'TotalPaid', 'InsurancePaid', 'Adjustments',
                     'Balance_0_30_Days', 'Balance_31_60_Days', 'Balance_61_90_Days',
                     'Balance_Over_90_Days', 'TotalBalance', 'InsuranceEstimate',
                     'Family_Total_Balance']
        }
        
        for dtype, cols in numeric_columns.items():
            for col in cols:
                if col in df.columns:
                    df[col] = pd.to_numeric(df[col], errors='coerce').astype(dtype)
        
        print(f"\nSuccessfully loaded {len(df):,} records with {len(df.columns)} features")
        
        return df
        
    except Exception as e:
        print(f"Error loading data: {str(e)}")
        raise
        
    finally:
        engine.dispose()

if __name__ == "__main__":
    try:
        df = load_treatment_journey_data()
        
        # Display first few rows and basic info
        print("\nFirst few rows:")
        print(df.head())
        
        print("\nDataFrame Info:")
        print(df.info())
        
        # Display some basic statistics
        print("\nBasic Statistics:")
        print(f"Total procedures: {len(df):,}")
        print(f"Acceptance rate: {df['target_accepted'].mean():.1%}")
        print(f"30-day payment rate: {df['target_paid_30d'].mean():.1%}")
        
        # Memory usage
        memory_usage = df.memory_usage(deep=True).sum() / 1024**2  # Convert to MB
        print(f"\nMemory Usage: {memory_usage:.2f} MB")
        
    except Exception as e:
        print(f"Error in main: {str(e)}") 