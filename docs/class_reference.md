# Project Class Reference

## Connection Management

### ConnectionConfig
**Purpose**: Configuration dataclass for database connections
**Location**: `src/connections/base.py`
**Methods**:
- `to_dict() -> Dict[str, Any]`: Convert config to dictionary for mysql-connector

### DatabaseConnection (Abstract)
**Purpose**: Base abstract class for database connections
**Location**: `src/connections/base.py`
**Methods**:
- `connect() -> MySQLConnection`: Abstract method to establish database connection
- `get_connection() -> MySQLConnection`: Get existing connection or create new one
- `close()`: Close the connection if it exists

### ConnectionPool
**Purpose**: Database connection pool manager
**Location**: `src/connections/pool.py`
**Class Methods**:
- `get_pool(name, config, pool_size=5, pool_reset_session=True) -> MySQLConnectionPool`: Get or create a connection pool
- `close_all_pools()`: Close all connection pools

### PooledDatabaseConnection
**Purpose**: Connection wrapper for pooled connections
**Location**: `src/connections/pool.py`
**Methods**:
- `get_connection() -> MySQLConnection`: Get a connection from the pool
- `close()`: Return connection to pool
- `__enter__/__exit__`: Context manager support

### ConnectionFactory
**Purpose**: Factory for creating database connections
**Location**: `src/connections/factory.py`
**Class Methods**:
- `create_connection(connection_type, database=None, use_root=False) -> DatabaseConnection`: Create a database connection
- `create_pooled_connection(connection_type, pool_name, database=None, use_root=False) -> PooledDatabaseConnection`: Create a pooled connection
- `_get_config(connection_type, database, use_root) -> ConnectionConfig`: Get connection configuration

### LocalMySQLConnection
**Purpose**: Handles local MySQL database connections
**Location**: `src/connections/local.py`
**Methods**:
- `connect() -> MySQLConnection`: Establish MySQL connection

### LocalMariaDBConnection
**Purpose**: Handles local MariaDB database connections
**Location**: `src/connections/local.py`
**Methods**:
- `connect() -> MySQLConnection`: Establish MariaDB connection

### ClinicServerConnection
**Purpose**: Base class for clinic server connections with business hours protection
**Location**: `src/connections/clinic_servers.py`
**Methods**:
- `connect() -> MySQLConnection`: Connect with business hours check
- `_is_business_hours() -> bool`: Check if current time is during business hours (8am-6pm)

### MDCServerConnection
**Purpose**: MDC specific server connection implementation
**Location**: `src/connections/clinic_servers.py`
**Inherits**: ClinicServerConnection
**Methods**: Inherits all methods from ClinicServerConnection

## Connection Types
Available connection types for use with ConnectionFactory:
- `'local_mysql'`: Local MySQL server connection
- `'local_mariadb'`: Local MariaDB server connection
- `'mdc'`: MDC clinic server connection with business hours protection

## ETL Framework

### ETLJob (Abstract)
**Purpose**: Base class for ETL jobs
**Location**: `scripts/etl/base/etl_base.py`
**Methods**:
- `setup()`: Abstract method for ETL job setup
- `extract() -> DataFrame`: Abstract method to extract data
- `transform(df: DataFrame) -> DataFrame`: Abstract method to transform data
- `load(df: DataFrame) -> Path`: Load data to destination
- `run() -> Path`: Run the complete ETL job

### TreatmentJourneyETL
**Purpose**: ETL job for generating treatment journey dataset
**Location**: `scripts/etl/treatment_journey_ml/main.py`
**Methods**:
- `setup()`: Setup required indexes for the ETL job
- `extract() -> DataFrame`: Execute main query with chunking support
- `transform(df: DataFrame) -> DataFrame`: Apply transformations using transform module
- `load(df: DataFrame) -> Path`: Save dataset to parquet with timestamp
**Functions**:
- `main(database_name: str) -> Optional[Path]`: Run the treatment journey ETL job

## Database Management

### IndexManager
**Purpose**: Manages database indexes for ETL jobs and base configuration
**Location**: `scripts/base/index_manager.py`
**Methods**:
- `read_index_file(index_path: Path) -> List[str]`: Read index definitions from SQL file
- `drop_custom_indexes(cursor, table: str)`: Drops all indexes that start with 'idx_'
- `setup_indexes(indexes: List[str])`: Sets up provided index statements
- `setup_indexes_from_file(index_path: Path)`: Sets up indexes from SQL file
- `setup_base_indexes()`: Setup comprehensive base indexes
- `setup_treatment_journey_indexes()`: Setup treatment journey specific indexes
