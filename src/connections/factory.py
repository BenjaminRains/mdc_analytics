from typing import Dict, Type, Optional
from pathlib import Path
import os
from dotenv import load_dotenv
from .base import ConnectionConfig, DatabaseConnection
from .clinic_servers import MDCServerConnection
from .local import LocalMySQLConnection, LocalMariaDBConnection
from .pool import PooledDatabaseConnection

# Load environment variables from the .env file
load_dotenv(dotenv_path=Path(".env"))

# Import valid database names from db_config.py
from db_config import LOCAL_VALID_DATABASES, MDC_VALID_DATABASES

# These variables are already lists (populated by get_valid_databases in db_config.py)
VALID_DATABASES_LOCAL = LOCAL_VALID_DATABASES
VALID_DATABASES_MDC = MDC_VALID_DATABASES

def get_port(env_var: str, default: int) -> int:
    """Helper function to retrieve a port from the environment, defaulting if necessary."""
    value = os.getenv(env_var)
    return int(value) if value else default

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
            connection_type: Type of connection to create.
            database: Optional database name.
            use_root: Whether to use root credentials (default: False).
        
        Raises:
            ValueError if the connection type is unknown or if the provided database name is invalid.
        """
        if connection_type not in cls._connection_types:
            raise ValueError(f"Unknown connection type: {connection_type}")
        
        # Validate database name based on connection type.
        if connection_type == 'mdc':
            if database and database not in VALID_DATABASES_MDC:
                raise ValueError(f"Invalid MDC database name. Must be one of: {', '.join(VALID_DATABASES_MDC)}")
        elif connection_type in ('local_mysql', 'local_mariadb'):
            if database and database not in VALID_DATABASES_LOCAL:
                raise ValueError(f"Invalid local database name. Must be one of: {', '.join(VALID_DATABASES_LOCAL)}")
        
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
                collation='utf8mb4_general_ci'
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
        use_root: bool = False
    ) -> PooledDatabaseConnection:
        """Create a pooled connection."""
        config = cls._get_config(connection_type, database, use_root)
        return PooledDatabaseConnection(pool_name, config)
