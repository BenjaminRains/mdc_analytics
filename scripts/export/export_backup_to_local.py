import os
import subprocess
import logging
import mysql.connector
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv
from src.db_config import get_available_backups, connect_to_mysql_localhost
from src.utils.connection_test import test_mysql_connection
from .setup_local_indexes import setup_indexes

# Load environment variables
load_dotenv()

def test_connections():
    """
    Test both MDC and local MySQL connections before starting operations
    Returns tuple of (mdc_conn, local_conn) if successful
    Raises exception if either connection fails
    """
    mdc_conn = None
    local_conn = None
    
    try:
        # Test MDC connection
        logging.info("Testing MDC server connection...")
        mdc_conn = connect_to_mysql_localhost()
        mdc_conn.ping(reconnect=True)
        logging.info("MDC server connection successful")
        
        # Test local connection with bpr user
        logging.info("Testing local MySQL connection...")
        local_conn = connect_to_mysql_localhost()  # Uses bpr user from db_config
        local_conn.ping(reconnect=True)
        logging.info("Local MySQL connection successful")
        
        return mdc_conn, local_conn
        
    except mysql.connector.Error as err:
        if err.errno == mysql.connector.errorcode.ER_ACCESS_DENIED_ERROR:
            logging.error("Access denied: Check your username and password")
        elif err.errno == mysql.connector.errorcode.ER_BAD_DB_ERROR:
            logging.error("Database does not exist")
        else:
            logging.error(f"MySQL Error: {err}")
            
        # Clean up connections if error occurs
        if mdc_conn and mdc_conn.is_connected():
            mdc_conn.close()
        if local_conn and local_conn.is_connected():
            local_conn.close()
        raise
        
    except Exception as e:
        logging.error(f"Connection test failed: {str(e)}")
        # Clean up connections if error occurs
        if mdc_conn and mdc_conn.is_connected():
            mdc_conn.close()
        if local_conn and local_conn.is_connected():
            local_conn.close()
        raise

def export_backup_to_local():
    """
    Exports the latest backup from MDC server to local MySQL database
    Uses bpr user for all operations
    """
    try:
        # Create data directories if they don't exist
        data_dir = Path("data")
        (data_dir / "raw").mkdir(parents=True, exist_ok=True)
        (data_dir / "processed").mkdir(parents=True, exist_ok=True)
        
        # Validate required environment variables
        required_vars = ['MDC_DB_PASSWORD', 'DB_PASSWORD']
        missing_vars = [var for var in required_vars if not os.getenv(var)]
        if missing_vars:
            raise EnvironmentError(f"Missing required environment variables: {', '.join(missing_vars)}")
        
        # Get latest backup name
        backups = get_available_backups()
        latest_backup = max(backups.items(), key=lambda x: x[1])[0]
        
        # Create local database name
        local_db_name = f"opendental_analytics_{latest_backup}"
        
        # Create temp directory for backup file
        temp_dir = Path("temp")
        temp_dir.mkdir(exist_ok=True)
        backup_file = temp_dir / "temp_backup.sql"
        
        try:
            # Step 1: Export from MDC server
            logging.info(f"Exporting {latest_backup} from MDC server...")
            dump_cmd = [
                "mysqldump",
                "-h", "192.168.2.10",
                "-u", "bpr",
                f"-p{os.getenv('MDC_DB_PASSWORD')}",
                "--no-tablespaces",
                "--skip-lock-tables",
                "--set-gtid-purged=OFF",
                "--result-file", str(backup_file),
                latest_backup
            ]
            
            result = subprocess.run(
                dump_cmd,
                capture_output=True,
                text=True,
                check=True
            )
            
            # Step 2: Create local database using bpr user
            logging.info(f"Creating local database {local_db_name}...")
            create_cmd = [
                "mysql",
                "-u", "bpr",
                f"-p{os.getenv('DB_PASSWORD')}",
                "-e", f"CREATE DATABASE IF NOT EXISTS {local_db_name}"
            ]
            
            subprocess.run(
                create_cmd,
                capture_output=True,
                text=True,
                check=True
            )
            
            # Step 3: Import to local database
            logging.info("Importing to local database...")
            with open(backup_file, 'r') as infile:
                import_cmd = [
                    "mysql",
                    "-u", "bpr",
                    f"-p{os.getenv('DB_PASSWORD')}",
                    local_db_name
                ]
                
                subprocess.run(
                    import_cmd,
                    stdin=infile,
                    capture_output=True,
                    text=True,
                    check=True
                )
            
            logging.info(f"Successfully created and populated {local_db_name}")
            
            # Set up indexes after successful import
            setup_indexes(local_db_name)
            
            return local_db_name
            
        except subprocess.CalledProcessError as e:
            logging.error(f"Command failed: {' '.join(e.cmd)}")
            logging.error(f"Error output: {e.stderr}")
            raise
            
        except Exception as e:
            logging.error(f"Unexpected error: {str(e)}")
            raise
            
        finally:
            # Cleanup
            if backup_file.exists():
                backup_file.unlink()
            if temp_dir.exists():
                temp_dir.rmdir()
                
    except Exception as e:
        logging.error(f"Error during backup transfer: {str(e)}")
        raise

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    export_backup_to_local() 