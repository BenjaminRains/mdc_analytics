import logging
from src.db_config import connect_to_mysql_localhost
import mysql.connector

def setup_indexes(database_name: str):
    """
    Sets up indexes on the local database for better query performance.
    These indexes are specifically optimized for treatment journey queries.
    """
    logging.info(f"Setting up indexes for {database_name}...")
    
    # Connect to database
    try:
        conn = connect_to_mysql_localhost(database=database_name)
        cursor = conn.cursor()
    except mysql.connector.Error as err:
        logging.error(f"Failed to connect to database: {err}")
        raise
    
    try:
        # Define indexes for treatment journey analysis
        indexes = [
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
        ]
        
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
        
        # Analyze tables for query optimization
        tables = [
            "procedurelog", 
            "patient", 
            "paysplit", 
            "payment",
            "adjustment", 
            "appointment",
            "commlog"
        ]
        for table in tables:
            try:
                cursor.execute(f"ANALYZE TABLE {table}")
                results = cursor.fetchall()
                logging.info(f"Analyzed table: {table}")
            except mysql.connector.Error as err:
                logging.warning(f"Error analyzing table {table}: {err}")
                
    except Exception as e:
        logging.error(f"Error during index setup: {str(e)}")
        raise
        
    finally:
        cursor.close()
        conn.close()
        logging.info("Index setup complete")

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("Usage: python setup_local_indexes.py <local_db_name>")
        sys.exit(1)
    
    setup_indexes(sys.argv[1]) 