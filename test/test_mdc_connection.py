import os
import logging
from pathlib import Path
from dotenv import load_dotenv
import mysql.connector

# Load environment variables
load_dotenv()

def setup_logging():
    """Configure logging"""
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_dir / "test_connection.log"),
            logging.StreamHandler()
        ]
    )

def test_mdc_connection():
    """Test connection to MDC server and list databases"""
    try:
        # Basic connection config
        config = {
            'host': '192.168.2.10',
            'user': 'bpr',
            'password': os.getenv('MDC_DB_PASSWORD'),
            'port': int(os.getenv('MDC_DB_PORT', '3306'))
        }
        
        logging.info("Attempting to connect to MDC server...")
        conn = mysql.connector.connect(**config)
        
        if conn.is_connected():
            db_info = conn.get_server_info()
            logging.info(f"Connected to MySQL Server version {db_info}")
            
            cursor = conn.cursor()
            
            # Get current user and privileges
            cursor.execute("SELECT CURRENT_USER()")
            current_user = cursor.fetchone()[0]
            logging.info(f"Connected as user: {current_user}")
            
            # Show grants for current user
            cursor.execute("SHOW GRANTS")
            grants = cursor.fetchall()
            logging.info("User privileges:")
            for grant in grants:
                logging.info(f"  {grant[0]}")
            
            # Use SQL to get all databases
            logging.info("\nFetching list of databases...")
            cursor.execute("SHOW DATABASES")
            databases = cursor.fetchall()
            
            logging.info("\nAll Databases Found:")
            backup_count = 0
            for (db_name,) in databases:
                logging.info(f"Found: {db_name}")
                if isinstance(db_name, str) and db_name.startswith('opendentalbackup_'):
                    backup_count += 1
            
            logging.info(f"\nTotal databases found: {len(databases)}")
            logging.info(f"Total backup databases found: {backup_count}")
            
            cursor.close()
            conn.close()
            logging.info("\nConnection closed")
            
    except mysql.connector.Error as err:
        logging.error(f"MySQL Error: {err}")
        raise
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
        raise

if __name__ == "__main__":
    setup_logging()
    test_mdc_connection() 