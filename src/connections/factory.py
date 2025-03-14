"""
Database Connection Factory Module

Provides a unified interface for creating database connections
of different types with consistent configuration handling.
"""
from typing import Dict, Type, Optional, List
from pathlib import Path
import os
import logging
from dotenv import load_dotenv
import mysql.connector
from mysql.connector import pooling

# Import connection components from modular files
from .base import ConnectionConfig, DatabaseConnection
from .local import LocalMySQLConnection, LocalMariaDBConnection
from .mdc import MDCServerConnection
from .pool import PooledDatabaseConnection

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    force=True
)

# Utility function to find the .env file
def find_env_path() -> Path:
    """Find the .env file from multiple possible locations."""
    # Current file's location
    module_dir = Path(__file__).parent
    
    # Possible locations for .env file
    possible_paths = [
        module_dir / ".env",                    # connections/.env
        module_dir.parent / ".env",             # src/.env
        module_dir.parent.parent / ".env",      # project_root/.env
        Path(".env")                            # current directory/.env
    ]
    
    for path in possible_paths:
        if path.exists():
            return path
    
    # Default to src/.env as fallback
    return module_dir.parent / ".env"

# Load environment variables from the .env file
env_path = find_env_path()
load_dotenv(dotenv_path=env_path)
logging.info(f"Loaded environment variables from: {env_path}")

def get_port(env_var: str, default: int) -> int:
    """Helper function to retrieve a port from the environment, defaulting if necessary."""
    value = os.getenv(env_var)
    return int(value) if value else default

def get_valid_databases(env_var: str) -> List[str]:
    """Helper function to get list of valid databases from environment variable."""
    databases = os.getenv(env_var, '').split(',')
    return [db.strip() for db in databases if db.strip()]

class ConnectionFactory:
    """Factory for creating database connections."""
    
    _connection_types: Dict[str, Type[DatabaseConnection]] = {
        'mdc': MDCServerConnection,
        'local_mysql': LocalMySQLConnection,
        'local_mariadb': LocalMariaDBConnection
    }
    
    @classmethod
    def create_connection(
        cls, 
        connection_type: str, 
        database: Optional[str] = None,
        use_root: bool = False
    ) -> DatabaseConnection:
        """
        Create a connection of the specified type.
        
        Args:
            connection_type: Type of connection to create ('mdc', 'local_mysql', 'local_mariadb').
            database: Optional database name.
            use_root: Whether to use root credentials (default: False).
        
        Raises:
            ValueError if the connection type is unknown or if the provided database name is invalid.
            
        Returns:
            DatabaseConnection: A connection object of the requested type.
        """
        if connection_type not in cls._connection_types:
            raise ValueError(f"Unknown connection type: {connection_type}. "
                             f"Available types: {', '.join(cls._connection_types.keys())}")
        
        # Validate database name based on connection type
        if connection_type == 'local_mariadb':
            # Default to the configured database if none is provided
            if not database:
                database = os.getenv('MARIADB_DATABASE')
                if not database:
                    raise ValueError("MARIADB_DATABASE must be set in .env file")
            else:
                # Validate against the list of valid databases
                valid_databases = get_valid_databases('LOCAL_VALID_DATABASES')
                if valid_databases and database not in valid_databases:
                    raise ValueError(f"Invalid database name. Must be in LOCAL_VALID_DATABASES: {', '.join(valid_databases)}")
        elif connection_type == 'mdc':
            # For MDC connections, validate against MDC_VALID_DATABASES env var
            if database:
                valid_databases = get_valid_databases('MDC_VALID_DATABASES')
                if valid_databases and database not in valid_databases:
                    raise ValueError(f"Invalid MDC database name. Must be in MDC_VALID_DATABASES: {', '.join(valid_databases)}")
            # Default to configured database if none is provided
            else:
                configured_db = os.getenv('MDC_DATABASE')
                if not configured_db:
                    raise ValueError("MDC_DATABASE must be set in .env file")
                database = configured_db
        
        connection_class = cls._connection_types[connection_type]
        config = cls._get_config(connection_type, database, use_root)
        return connection_class(config)
    
    @classmethod
    def _get_config(cls, connection_type: str, database: Optional[str], use_root: bool) -> ConnectionConfig:
        """Get connection configuration based on type."""
        if connection_type == 'mdc':
            config = ConnectionConfig(
                host=os.getenv('MDC_DB_HOST'),
                port=get_port('MDC_DB_PORT', 3306),
                user=os.getenv('MDC_DB_USER'),
                password=os.getenv('MDC_DB_PASSWORD'),
                database=database
            )
        elif connection_type == 'local_mysql':
            host_env = 'MYSQL_ROOT_HOST' if use_root else 'MYSQL_HOST'
            port_env = 'MYSQL_ROOT_PORT' if use_root else 'MYSQL_PORT'
            user_env = 'MYSQL_ROOT_USER' if use_root else 'MYSQL_USER'
            password_env = 'MYSQL_ROOT_PASSWORD' if use_root else 'MYSQL_PASSWORD'
            config = ConnectionConfig(
                host=os.getenv(host_env, 'localhost'),
                port=get_port(port_env, 3306),
                user=os.getenv(user_env),
                password=os.getenv(password_env),
                database=database,
                charset='utf8mb4',
                collation='utf8mb4_general_ci'
            )
        elif connection_type == 'local_mariadb':
            host_env = 'MARIADB_ROOT_HOST' if use_root else 'MARIADB_HOST'
            port_env = 'MARIADB_ROOT_PORT' if use_root else 'MARIADB_PORT'
            user_env = 'MARIADB_ROOT_USER' if use_root else 'MARIADB_USER'
            password_env = 'MARIADB_ROOT_PASSWORD' if use_root else 'MARIADB_PASSWORD'
            config = ConnectionConfig(
                host=os.getenv(host_env, 'localhost'),
                port=get_port(port_env, 3307),
                user=os.getenv(user_env),
                password=os.getenv(password_env),
                database=database or os.getenv('MARIADB_DATABASE'),
                charset='utf8mb4',
                collation='utf8mb4_general_ci',
                use_pure=True  # Use pure Python implementation for better compatibility
            )
        else:
            raise ValueError(f"Unknown connection type: {connection_type}")
        
        # Validate required credentials exist and report missing ones.
        if not all([config.host, config.user, config.password]):
            missing = [name for name, val in (("host", config.host), ("user", config.user), ("password", config.password)) if not val]
            raise ValueError(f"Missing required credentials for {connection_type} connection: {', '.join(missing)}")
            
        return config

    @classmethod
    def create_pooled_connection(
        cls,
        connection_type: str,
        pool_name: str,
        database: Optional[str] = None,
        use_root: bool = False,
        pool_size: int = 5
    ) -> PooledDatabaseConnection:
        """
        Create a pooled connection for improved performance with multiple queries.
        
        Args:
            connection_type: Type of connection to create.
            pool_name: Name for the connection pool.
            database: Optional database name.
            use_root: Whether to use root credentials (default: False).
            pool_size: Size of the connection pool (default: 5).
            
        Returns:
            PooledDatabaseConnection: A pooled connection object.
        """
        config = cls._get_config(connection_type, database, use_root)
        return PooledDatabaseConnection(pool_name, config, pool_size)

# Utility functions for direct connection (legacy support)
def connect_to_mysql(database: Optional[str] = None) -> mysql.connector.MySQLConnection:
    """Legacy support function for direct MySQL connections."""
    connection = ConnectionFactory.create_connection("local_mysql", database)
    return connection.connect()

def connect_to_mariadb(database: Optional[str] = None) -> mysql.connector.MySQLConnection:
    """Legacy support function for direct MariaDB connections."""
    connection = ConnectionFactory.create_connection("local_mariadb", database)
    return connection.connect()
