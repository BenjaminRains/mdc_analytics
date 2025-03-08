#!/usr/bin/env python3
"""
Payment Split Validation Export Script with Jinja2 Templates

This script exports data for payment split validation by running SQL queries and exporting
results to CSV files. It uses Jinja2 templates for SQL file handling, supporting both
variable substitution and file includes.

Usage:
    python updated_export_validation.py --start-date <YYYY-MM-DD> --end-date <YYYY-MM-DD>
                                       --database <dbname> 
                                       [--output-dir <path>]
                                       [--queries <query1> <query2>]
                                       [--connection-type <local_mariadb|remote_mariadb>]
"""

import os
import sys
import csv
import logging
import argparse
from datetime import datetime
from pathlib import Path
from typing import List, Optional, NamedTuple

# Add project root to path to ensure imports work correctly
script_dir = Path(__file__).parent
project_root = script_dir.parent.parent.parent
sys.path.insert(0, str(project_root))

# Add Jinja2 for template handling
from jinja2 import Environment, FileSystemLoader, select_autoescape

# Import database connection functionality
from src.connections.factory import ConnectionFactory

class DateRange(NamedTuple):
    """Simple class to store start and end dates."""
    start_date: str
    end_date: str
    
    @classmethod
    def from_strings(cls, start_date_str: str, end_date_str: str) -> 'DateRange':
        """Create a DateRange from string dates."""
        return cls(start_date=start_date_str, end_date=end_date_str)

def setup_logging():
    """Set up logging to file and console."""
    # Reset any existing logging configuration
    for handler in logging.root.handlers[:]:
        logging.root.removeHandler(handler)
    
    # Create logs directory if it doesn't exist
    script_dir = Path(__file__).parent
    log_dir = script_dir / 'logs' / 'split_validation'
    os.makedirs(log_dir, exist_ok=True)
    
    # Create a timestamp for the log filename
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    log_file = log_dir / f'log_payment_split_validation_{timestamp}.log'
    
    # Create file handler that logs all messages
    file_handler = logging.FileHandler(str(log_file))
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
    
    # Create console handler with a higher log level
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
    
    # Get the root logger and set its level to DEBUG
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)
    
    # Add the handlers to the logger
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    # Test log message
    logging.debug("Logging initialized successfully")
    
    return log_file

def setup_jinja_environment():
    """
    Set up and return the Jinja2 environment with the appropriate template folders.
    """
    # Set up path to query and CTE directories
    query_dir = script_dir / 'queries' / 'payment_split' / 'queries'
    cte_dir = script_dir / 'queries' / 'payment_split' / 'ctes'
    
    # Ensure directories exist
    query_dir.mkdir(parents=True, exist_ok=True)
    cte_dir.mkdir(parents=True, exist_ok=True)
    
    # Create loader that can load from both directories
    loader = FileSystemLoader([
        str(query_dir),
        str(cte_dir)
    ])
    
    # Create environment
    env = Environment(
        loader=loader,
        autoescape=select_autoescape([]),
        keep_trailing_newline=True
    )
    
    logging.info(f"Set up Jinja2 environment with template directories: {query_dir}, {cte_dir}")
    return env

def render_template(env, template_name, date_range):
    """
    Render a Jinja2 template with date parameters.
    
    Args:
        env: Jinja2 Environment
        template_name: Name of the template to render
        date_range: DateRange with start and end dates
        
    Returns:
        Tuple of (success, rendered_template or error_message)
    """
    try:
        # Get template by name
        template = env.get_template(f"{template_name}.sql")
        
        # Render template with variables
        rendered = template.render(
            start_date=date_range.start_date,
            end_date=date_range.end_date
        )
        
        return True, rendered
    except Exception as e:
        logging.error(f"Error rendering template {template_name}: {str(e)}")
        return False, str(e)

def export_query_results(connection_type: str, database: str, query_name: str, 
                        date_range: DateRange, output_dir: str) -> bool:
    """
    Execute a query and export the results to a CSV file.
    
    Args:
        connection_type: Type of database connection
        database: Name of the database
        query_name: Name of the query template
        date_range: Start and end dates
        output_dir: Directory to save CSV file
        
    Returns:
        True if successful, False otherwise
    """
    logging.info(f"Processing query: {query_name}")
    logging.debug(f"Query parameters - connection: {connection_type}, database: {database}")
    logging.debug(f"Date range: {date_range.start_date} to {date_range.end_date}")
    
    # Set up Jinja2 environment
    logging.debug("Setting up Jinja2 environment")
    env = setup_jinja_environment()
    
    # Render the query template
    logging.debug(f"Rendering query template: {query_name}")
    success, sql_content = render_template(env, query_name, date_range)
    if not success:
        logging.error(f"Failed to render query template {query_name}: {sql_content}")
        return False
    
    # Add WITH clause if not already present
    if "WITH" not in sql_content.upper().split(None, 1)[0]:
        sql_content = f"WITH {sql_content}"
    
    logging.debug(f"SQL query rendered successfully:")
    logging.debug("----- SQL QUERY -----")
    logging.debug(sql_content)
    logging.debug("--------------------")
    
    try:
        # Create database connection
        logging.debug(f"Creating {connection_type} connection for database: {database}")
        connection = ConnectionFactory.create_connection(connection_type, database)
        conn = connection.connect()
        logging.info(f"Connected to {connection_type} database: {database}")
        
        # Execute query
        logging.debug("Beginning query execution...")
        with conn.cursor() as cursor:
            # Set date parameters
            logging.debug("Setting date parameters for query")
            cursor.execute(f"SET @start_date = '{date_range.start_date}';")
            cursor.execute(f"SET @end_date = '{date_range.end_date}';")
            logging.debug("Date parameters set successfully")
            
            # Execute the query
            logging.info(f"Executing query: {query_name}")
            cursor.execute(sql_content)
            logging.debug("Query executed successfully")
            
            # Get column names and results
            columns = [column[0] for column in cursor.description]
            logging.debug(f"Columns found: {', '.join(columns)}")
            
            results = cursor.fetchall()
            logging.info(f"Query returned {len(results)} rows")
            
            # Ensure output directory exists
            os.makedirs(output_dir, exist_ok=True)
            logging.debug(f"Output directory confirmed: {output_dir}")
            
            # Write results to CSV file
            output_file = os.path.join(output_dir, f"{query_name}_{date_range.start_date}_{date_range.end_date}.csv")
            logging.debug(f"Writing results to {output_file}")
            
            with open(output_file, 'w', newline='') as csvfile:
                writer = csv.writer(csvfile)
                writer.writerow(columns)  # Write header
                writer.writerows(results)  # Write data rows
            
            logging.info(f"Exported {len(results)} rows to {output_file}")
        
        # Close connection
        connection.disconnect()
        logging.debug("Database connection closed")
        
        return True
        
    except Exception as e:
        logging.error(f"Error executing query {query_name}: {str(e)}", exc_info=True)
        return False

def get_available_queries() -> List[str]:
    """Get a list of available query templates (without .sql extension)."""
    query_dir = script_dir / 'queries' / 'payment_split' / 'queries'
    
    if query_dir.exists():
        query_files = [f.stem for f in query_dir.glob('*.sql')]
        return query_files
    else:
        logging.warning(f"Query directory not found: {query_dir}")
        return []

def export_all_queries(connection_type: str, database: str, date_range: DateRange,
                     queries: Optional[List[str]] = None, output_dir: Optional[str] = None) -> None:
    """
    Export results for all specified queries.
    
    Args:
        connection_type: Type of database connection
        database: Name of the database
        date_range: Start and end dates
        queries: List of query names to execute (defaults to all available queries)
        output_dir: Directory to save CSV files (defaults to 'output')
    """
    # Set default output directory if not specified
    if output_dir is None:
        output_dir = script_dir / 'output'
    
    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)
    
    # Get list of queries to process
    if queries is None:
        queries_to_process = get_available_queries()
        if not queries_to_process:
            logging.error("No query templates found to process")
            return
        logging.info(f"Processing all {len(queries_to_process)} available queries")
    else:
        queries_to_process = queries
        logging.info(f"Processing {len(queries_to_process)} specified queries")
    
    # Process each query
    successful_exports = 0
    for query_name in queries_to_process:
        try:
            if export_query_results(connection_type, database, query_name, date_range, output_dir):
                successful_exports += 1
        except Exception as e:
            logging.error(f"Error processing query {query_name}: {str(e)}", exc_info=True)
    
    logging.info(f"Completed {successful_exports} of {len(queries_to_process)} exports")

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Export payment validation data.')
    
    # Required arguments
    parser.add_argument('--start-date', required=True, help='Start date (YYYY-MM-DD)')
    parser.add_argument('--end-date', required=True, help='End date (YYYY-MM-DD)')
    parser.add_argument('--database', required=True, help='Database name')
    
    # Optional arguments
    parser.add_argument('--connection-type', default='local_mariadb',
                        choices=['local_mariadb', 'local_mysql', 'remote_mariadb'],
                        help='Database connection type (default: local_mariadb)')
    parser.add_argument('--output-dir', help='Output directory (default: script_dir/output)')
    parser.add_argument('--queries', nargs='+', help='Specific queries to run')
    parser.add_argument('--log-level', default='INFO',
                        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
                        help='Logging level (default: INFO)')
    
    return parser.parse_args()

def main():
    """Main entry point for the script."""
    # Parse arguments first
    args = parse_args()
    
    # Set up logging
    log_file = setup_logging()
    logging.debug(f"Log file created at: {log_file}")
    
    # Set log level based on arguments
    log_level = getattr(logging, args.log_level)
    logging.getLogger().setLevel(log_level)
    logging.debug(f"Log level set to: {args.log_level}")
    
    # Log script start with important details
    logging.info("=" * 80)
    logging.info("STARTING PAYMENT SPLIT EXPORT PROCESS")
    logging.debug("Script initialized")
    logging.info(f"Date range: {args.start_date} to {args.end_date}")
    logging.info(f"Database: {args.database}")
    logging.info(f"Connection type: {args.connection_type}")
    if args.output_dir:
        logging.info(f"Output directory: {args.output_dir}")
    if args.queries:
        logging.info(f"Queries: {', '.join(args.queries)}")
    else:
        logging.info(f"Running all available queries")
    logging.info("=" * 80)
    
    try:
        # Create date range object
        date_range = DateRange(
            start_date=args.start_date,
            end_date=args.end_date
        )
        logging.debug(f"Date range object created: {date_range}")
        
        # Export validation results
        export_all_queries(
            args.connection_type,
            args.database,
            date_range,
            args.queries,
            args.output_dir
        )
        
        logging.info("Export process completed successfully")
        
    except Exception as e:
        logging.error(f"Error in export process: {str(e)}", exc_info=True)
        sys.exit(1)
    
if __name__ == "__main__":
    main() 