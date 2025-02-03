# database configuration file template
## db_config.template.py

from typing import Dict, Optional, List
from datetime import datetime
import os
from dotenv import load_dotenv
import mysql.connector
import logging

# Load environment variables
load_dotenv()

def get_valid_databases(env_var: str) -> List[str]:
    """
    Get list of valid databases from environment variable
    
    Args:
        env_var: Name of environment variable containing comma-separated database names
    
    Returns:
        List of database names
    """
    databases = os.getenv(env_var, '').split(',')
    return [db.strip() for db in databases if db.strip()]

# Load valid databases from environment
LOCAL_VALID_DATABASES = get_valid_databases('LOCAL_VALID_DATABASES')
MDC_VALID_DATABASES = get_valid_databases('MDC_VALID_DATABASES')

def connect_to_mysql(database: Optional[str] = None) -> mysql.connector.MySQLConnection:
    """
    Connect to a local MySQL database using environment variables for credentials.
    """
    if database and database not in LOCAL_VALID_DATABASES:
        raise ValueError(f"Invalid database name. Must be in LOCAL_VALID_DATABASES")
    
    config = {
        'host': os.getenv('MYSQL_HOST', 'localhost'),
        'user': os.getenv('MYSQL_USER'),
        'password': os.getenv('MYSQL_PASSWORD'),
        'port': int(os.getenv('MYSQL_PORT', 3306)),
        'raise_on_warnings': True,
        'allow_local_infile': True
    }
    
    if database:
        config['database'] = database
    
    try:
        conn = mysql.connector.connect(**config)
        logging.info(f"Connected to MySQL")
        return conn
    except mysql.connector.Error as err:
        logging.error(f"Failed to connect to MySQL: {err}")
        raise

def connect_to_mariadb(database: Optional[str] = None) -> mysql.connector.MySQLConnection:
    """
    Connect to a local MariaDB database using environment variables for credentials.
    """
    if database and database not in LOCAL_VALID_DATABASES:
        raise ValueError(f"Invalid database name. Must be in LOCAL_VALID_DATABASES")

    config = {
        'host': os.getenv('MARIADB_HOST', 'localhost'),
        'user': os.getenv('MARIADB_USER'),
        'password': os.getenv('MARIADB_PASSWORD'),
        'port': int(os.getenv('MARIADB_PORT', 3307)),
        'raise_on_warnings': True,
        'allow_local_infile': True,
        'charset': 'utf8mb4',
        'collation': 'utf8mb4_general_ci'
    }
    
    if database:
        config['database'] = database
    
    try:
        conn = mysql.connector.connect(**config)
        logging.info(f"Connected to MariaDB")
        return conn
    except mysql.connector.Error as err:
        logging.error(f"Failed to connect to MariaDB: {err}")
        raise 