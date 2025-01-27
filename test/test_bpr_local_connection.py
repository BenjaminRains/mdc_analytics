import logging
from src.db_config import connect_to_mysql_localhost
import mysql.connector
from dotenv import load_dotenv
import os

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def test_connection(db_type: str = 'mysql', host: str = 'localhost', user: str = 'bpr'):
    """
    Test connection to local MySQL/MariaDB server
    
    Args:
        db_type: Type of database to connect to ('mysql' or 'mariadb')
        host: Hostname to connect to ('localhost' or '127.0.0.1')
        user: Username to connect with ('bpr', 'root', etc.)
    """
    # Set appropriate port based on database type
    port = 3307 if db_type.lower() == 'mariadb' else 3306
    
    # Temporarily override environment variables
    os.environ['DB_PORT'] = str(port)
    os.environ['DB_HOST'] = host
    os.environ['DB_USER'] = user
    
    try:
        # Try connection without database first
        conn = connect_to_mysql_localhost(db_type=db_type)
        logging.info(f"Successfully connected to {db_type} on {host}:{port} as {user}")
        
        # Get server info
        cursor = conn.cursor()
        cursor.execute("SELECT VERSION()")
        version = cursor.fetchone()
        logging.info(f"Server Version: {version[0]}")
        
        # List all databases
        cursor.execute("SHOW DATABASES")
        databases = cursor.fetchall()
        logging.info("Available databases:")
        for db in databases:
            logging.info(f"  - {db[0]}")
            
    except mysql.connector.Error as err:
        logging.error(f"Error connecting to {db_type} on {host}:{port} as {user}: {err}")
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals() and conn.is_connected():
            conn.close()
            logging.info("Database connection closed")
        
def test_all_connections():
    """Test all known database connections"""
    # MySQL Connections (port 3306)
    connections = [
        {'db_type': 'mysql', 'host': 'localhost', 'user': 'bpr'},
        {'db_type': 'mysql', 'host': '127.0.0.1', 'user': 'bpr'},
        {'db_type': 'mysql', 'host': 'localhost', 'user': 'root'},
    ]
    
    # MariaDB Connections (port 3307)
    mariadb_connections = [
        {'db_type': 'mariadb', 'host': 'localhost', 'user': 'root'},
        {'db_type': 'mariadb', 'host': '127.0.0.1', 'user': 'root'},
        {'db_type': 'mariadb', 'host': 'localhost', 'user': 'bpr'},  # New user we just created
        {'db_type': 'mariadb', 'host': '127.0.0.1', 'user': 'bpr'},  # New user we just created
    ]
    
    connections.extend(mariadb_connections)
    
    for conn in connections:
        logging.info(f"\nTesting {conn['db_type']} connection to {conn['host']} as {conn['user']}...")
        test_connection(**conn)

if __name__ == "__main__":
    # Load environment variables
    load_dotenv()
    
    # Test all connections
    test_all_connections()