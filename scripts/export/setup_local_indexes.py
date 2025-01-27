import logging
from src.db_config import connect_to_mariadb
import mysql.connector

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Index configurations for different datasets
index_configurations = {
    "treatment_journey": [
        # Core procedurelog indexes
        "CREATE INDEX idx_proc_date ON procedurelog (ProcDate, ProcStatus)",
        "CREATE INDEX idx_proc_patient ON procedurelog (PatNum, ProcDate)",
        "CREATE INDEX idx_proc_code ON procedurelog (CodeNum)",
        
        # Patient indexes
        "CREATE INDEX idx_pat_guarantor ON patient (Guarantor)",
        "CREATE INDEX idx_pat_birth ON patient (Birthdate)",
        
        # Payment-related indexes
        "CREATE INDEX idx_paysplit_proc_amt ON paysplit (ProcNum, SplitAmt, PayNum)",
        "CREATE INDEX idx_adj_proc_amt ON adjustment (ProcNum, AdjAmt, AdjDate)",
        "CREATE INDEX idx_payment_date ON payment (PayNum, PayDate)",
        
        # Communication indexes
        "CREATE INDEX idx_commlog_patient_date ON commlog (PatNum, CommDate, CommType)",
        "CREATE INDEX idx_commlog_type_note ON commlog (PatNum, CommType, Note(20))",
        
        # Appointment indexes
        "CREATE INDEX idx_appt_datetime ON appointment (AptDateTime, PatNum)",
        "CREATE INDEX idx_appt_patient_status ON appointment (PatNum, AptStatus, AptDateTime)",
        "CREATE INDEX idx_appt_patient_date ON appointment (PatNum, AptDateTime, AptStatus)",
        
        # Procedurelog compound indexes
        "CREATE INDEX idx_proc_patient_date ON procedurelog (PatNum, ProcDate, ProcStatus)",
        "CREATE INDEX idx_proc_guarantor_date ON procedurelog (PatNum, ProcDate, ProcStatus)",
        "CREATE INDEX idx_proc_payment ON procedurelog (ProcNum, ProcFee, ProcStatus)",
        "CREATE INDEX idx_proc_code_fee ON procedurelog (CodeNum, ProcFee, ProcStatus)",
        "CREATE INDEX idx_proc_date_status ON procedurelog (ProcDate, ProcStatus, ProcFee)",
        "CREATE INDEX idx_proc_patient_history ON procedurelog (PatNum, ProcStatus, ProcDate, ProcFee)"
    ],
    # Add more datasets as needed
}

def setup_indexes(database_name: str, dataset_name: str):
    """
    Sets up indexes for a specific dataset in the database.
    """
    logging.info(f"Setting up indexes for {dataset_name} in {database_name}...")
    
    # Connect to database
    try:
        conn = connect_to_mariadb()
        cursor = conn.cursor()
        
        # Select the database
        cursor.execute(f"USE {database_name}")
    except mysql.connector.Error as err:
        logging.error(f"Failed to connect to database: {err}")
        raise
    
    try:
        # Get indexes for the specified dataset
        indexes = index_configurations.get(dataset_name, [])
        
        # Create indexes
        for index in indexes:
            try:
                cursor.execute(index)
                conn.commit()
                logging.info(f"Created index: {index}")
            except mysql.connector.Error as err:
                if err.errno == 1061:  # Error code for duplicate key name
                    logging.info(f"Index already exists: {index}")
                elif err.errno == 1071:  # Error code for specified key was too long
                    logging.warning(f"Index key too long: {index}")
                elif err.errno == 1170:  # Error code for BLOB/TEXT column used in key specification without key length
                    logging.warning(f"BLOB/TEXT column needs length specification: {index}")
                else:
                    logging.warning(f"Error creating index: {err}")
        
        # Log fetched indexes
        tables = ["procedurelog", "patient", "paysplit", "payment", "adjustment", "appointment", "commlog"]
        for table in tables:
            try:
                cursor.execute(f"SHOW INDEX FROM {table}")
                indexes = cursor.fetchall()
                logging.info(f"Indexes for {table}: {indexes}")
            except mysql.connector.Error as err:
                logging.warning(f"Error fetching indexes for table {table}: {err}")
                
    except Exception as e:
        logging.error(f"Error during index setup: {str(e)}")
        raise
        
    finally:
        cursor.close()
        conn.close()
        logging.info("Index setup complete")

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 3:
        print("Usage: python setup_local_indexes.py <local_db_name> <dataset_name>")
        sys.exit(1)
    
    setup_indexes(sys.argv[1], sys.argv[2]) 