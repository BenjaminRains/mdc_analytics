"""
Simple Payment Split Validation Export Script

This script exports data for payment split validation by running SQL queries and exporting
results to CSV files. It uses Jinja2 templates for SQL file handling, supporting both
variable substitution and file includes.

Usage:
    python simple_export_validation.py --start-date <YYYY-MM-DD> --end-date <YYYY-MM-DD>
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
from datetime import datetime, date
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any, NamedTuple

# Add project root to path to ensure imports work correctly
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, '..', '..', '..'))
sys.path.insert(0, project_root)

# Add Jinja2 for template handling
from jinja2 import Environment, FileSystemLoader, select_autoescape

# Import database connection functionality from the correct location
try:
    from src.connections.factory import ConnectionFactory
    logging.info("Successfully imported ConnectionFactory from src.connections.factory")
except ImportError as e:
    logging.warning(f"Could not import ConnectionFactory: {e}")
    
    # Fallback ConnectionFactory implementation
    logging.warning("Using fallback ConnectionFactory implementation")
    class ConnectionFactory:
        @staticmethod
        def create_connection(connection_type, database):
            if connection_type == 'local_mariadb':
                import mysql.connector
                return mysql.connector.connect(
                    host='localhost',
                    user=os.environ.get('DB_USER', 'root'),
                    password=os.environ.get('DB_PASSWORD', ''),
                    database=database
                )
            elif connection_type == 'remote_mariadb':
                import mysql.connector
                return mysql.connector.connect(
                    host=os.environ.get('REMOTE_DB_HOST', 'localhost'),
                    user=os.environ.get('REMOTE_DB_USER', 'root'),
                    password=os.environ.get('REMOTE_DB_PASSWORD', ''),
                    database=database
                )
            else:
                raise ValueError(f"Unsupported connection type: {connection_type}")

class DateRange(NamedTuple):
    """Simple class to store start and end dates."""
    start_date: str
    end_date: str
    
    @classmethod
    def from_strings(cls, start_date_str: str, end_date_str: str) -> 'DateRange':
        """Create a DateRange from string dates."""
        return cls(start_date=start_date_str, end_date=end_date_str)

def setup_logging(log_dir='logs'):
    """Set up logging to file and console."""
    # Ensure log directory exists
    os.makedirs(log_dir, exist_ok=True)
    
    # Create log filename with timestamp
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    log_file = os.path.join(log_dir, f'export_validation_{timestamp}.log')
    
    # Configure logging
    handlers = [
        logging.FileHandler(log_file),
        logging.StreamHandler(sys.stdout)
    ]
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=handlers
    )
    
    return log_file

def read_sql_file(file_path: str) -> str:
    """Read an SQL file and return its contents."""
    try:
        with open(file_path, 'r') as f:
            return f.read()
    except Exception as e:
        logging.error(f"Error reading SQL file {file_path}: {str(e)}")
        return ""

def get_query_file_path(query_name: str) -> str:
    """Get the full path to a query file."""
    # Add .sql extension if missing
    if not query_name.endswith('.sql'):
        query_name += '.sql'
        
    # Get the query directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    query_dir = os.path.join(script_dir, 'queries')
    
    # Return the full path
    return os.path.join(query_dir, query_name)

def get_template_env() -> Environment:
    """
    Create and configure a Jinja2 environment for SQL templates.
    
    Uses the 'queries' directory as the template root.
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    queries_dir = os.path.join(script_dir, 'queries')
    
    # Create Jinja2 environment
    env = Environment(
        loader=FileSystemLoader(queries_dir),
        autoescape=select_autoescape([]),
        keep_trailing_newline=True
    )
    
    # Optional: Add custom filters or globals if needed
    # env.filters['some_filter'] = some_filter_function
    
    return env

def render_sql_template(template_name: str, date_range: DateRange) -> Tuple[bool, str]:
    """
    Render an SQL template with parameters.
    
    Args:
        template_name: Name of the template file (with or without .sql extension)
        date_range: Date range for parameterization
        
    Returns:
        Tuple of (success, rendered_sql)
    """
    # Ensure template name has .sql extension
    if not template_name.endswith('.sql'):
        template_name += '.sql'
    
    try:
        # Get Jinja2 environment
        env = get_template_env()
        
        # Prepare parameters for template rendering
        params = {
            'start_date': date_range.start_date,
            'end_date': date_range.end_date,
        }
        
        # Try to load template from the main query directory
        try:
            template = env.get_template(template_name)
            rendered_sql = template.render(**params)
            return True, rendered_sql
        except Exception as e:
            logging.error(f"Error rendering template {template_name}: {str(e)}")
            return False, ""
        
    except Exception as e:
        logging.error(f"Error in template processing for {template_name}: {str(e)}")
        return False, ""

def prepare_query(query_name: str, date_range: DateRange) -> Tuple[bool, str]:
    """
    Prepare a query for execution using Jinja2 templates.
    
    Args:
        query_name: Name of the query file
        date_range: Start and end dates
        
    Returns:
        Tuple of (success, sql_content)
    """
    # Remove .sql extension if present for consistent handling
    if query_name.endswith('.sql'):
        query_name = query_name[:-4]
    
    # Render the query template
    success, sql_content = render_sql_template(query_name, date_range)
    
    if not success:
        return False, ""
    
    # Look for a matching CTE file
    script_dir = os.path.dirname(os.path.abspath(__file__))
    cte_dir = os.path.join(script_dir, 'queries', 'ctes')
    cte_file = f"{query_name}.sql"
    
    # If there's a CTE file in the ctes directory, render it too
    if os.path.exists(os.path.join(cte_dir, cte_file)):
        # Create a custom environment for the CTE directory
        cte_env = Environment(
            loader=FileSystemLoader(cte_dir),
            autoescape=select_autoescape([]),
            keep_trailing_newline=True
        )
        
        try:
            cte_template = cte_env.get_template(cte_file)
            
            # Render CTE template with same parameters
            params = {
                'start_date': date_range.start_date,
                'end_date': date_range.end_date,
            }
            
            cte_sql = cte_template.render(**params)
            
            # Combine CTE and main query
            combined_sql = combine_ctes_with_query(sql_content, cte_sql)
            return True, combined_sql
        except Exception as e:
            logging.error(f"Error rendering CTE template for {query_name}: {str(e)}")
            return False, ""
    
    return True, sql_content

def combine_ctes_with_query(query_sql: str, ctes_sql: Optional[str] = None) -> str:
    """
    Combine CTEs with the main query.
    
    Args:
        query_sql: The main query SQL
        ctes_sql: SQL containing common table expressions
        
    Returns:
        Combined SQL
    """
    if not ctes_sql:
        return query_sql
        
    # Check if the query already has WITH clause
    if query_sql.strip().upper().startswith('WITH '):
        # Query already has WITH, combine cautiously
        query_with_stripped = query_sql.strip()[5:].strip()
        
        # Check if ctes_sql has WITH clause
        if ctes_sql.strip().upper().startswith('WITH '):
            ctes_content = ctes_sql.strip()[5:].strip()
            return f"WITH {ctes_content},\n{query_with_stripped}"
        else:
            return f"WITH {ctes_sql.strip()},\n{query_with_stripped}"
    else:
        # Query doesn't have WITH clause
        if ctes_sql.strip().upper().startswith('WITH '):
            # CTEs already have WITH
            return f"{ctes_sql}\n{query_sql}"
        else:
            # Add WITH to CTEs
            return f"WITH {ctes_sql}\n{query_sql}"

def export_query_results(connection_type: str, database: str, query_name: str, 
                        date_range: DateRange, output_dir: str) -> bool:
    """
    Execute a query and export the results to a CSV file.
    
    Args:
        connection_type: Type of database connection
        database: Name of the database
        query_name: Name of the query file
        date_range: Start and end dates
        output_dir: Directory to save CSV file
        
    Returns:
        True if successful, False otherwise
    """
    # Remove .sql extension if present
    if query_name.endswith('.sql'):
        query_name = query_name[:-4]
    
    logging.info(f"Processing query: {query_name}")
    
    # Prepare the query
    success, sql_content = prepare_query(query_name, date_range)
    if not success:
        logging.error(f"Failed to prepare query: {query_name}")
        return False
    
    try:
        # Create database connection
        conn = ConnectionFactory.create_connection(connection_type, database)
        logging.info(f"Connected to {connection_type} database: {database}")
        
        # Execute the query
        cursor = conn.cursor()
        logging.info(f"Executing query: {query_name}")
        cursor.execute(sql_content)
        
        # Get column names and results
        columns = [column[0] for column in cursor.description]
        results = cursor.fetchall()
        
        # Ensure output directory exists
        os.makedirs(output_dir, exist_ok=True)
        
        # Write results to CSV file
        output_file = os.path.join(output_dir, f"{query_name}.csv")
        with open(output_file, 'w', newline='') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(columns)  # Write header
            writer.writerows(results)  # Write data rows
        
        logging.info(f"Exported {len(results)} rows to {output_file}")
        
        # Close the cursor and connection
        cursor.close()
        conn.close()
        logging.info("Database connection closed")
        
        return True
        
    except Exception as e:
        logging.error(f"Error executing query {query_name}: {str(e)}", exc_info=True)
        return False

def get_available_queries() -> List[str]:
    """Get a list of available query files (without .sql extension)."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    query_dir = os.path.join(script_dir, 'queries')
    
    query_files = [f[:-4] for f in os.listdir(query_dir) 
                  if f.endswith('.sql') and os.path.isfile(os.path.join(query_dir, f))]
    return query_files

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
        script_dir = os.path.dirname(os.path.abspath(__file__))
        output_dir = os.path.join(script_dir, 'output')
    
    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)
    
    # Get list of queries to process
    if queries is None:
        queries_to_process = get_available_queries()
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
    
    logging.info(f"Export completed: {successful_exports}/{len(queries_to_process)} successful")

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Export payment validation data')
    
    # Add arguments
    parser.add_argument('--start-date', 
                        required=True,
                        help='Start date (YYYY-MM-DD)')
    
    parser.add_argument('--end-date', 
                        required=True,
                        help='End date (YYYY-MM-DD)')
    
    parser.add_argument('--database', 
                        required=True,
                        help='Database name')
    
    parser.add_argument('--connection-type', 
                        default='local_mariadb',
                        choices=['local_mariadb', 'remote_mariadb'],
                        help='Connection type')
    
    parser.add_argument('--output-dir', 
                        help='Output directory for CSV files')
    
    parser.add_argument('--queries', 
                        nargs='+',
                        help='Specific queries to run (space-separated)')
    
    parser.add_argument('--log-level',
                        default='INFO',
                        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
                        help='Logging level')
    
    return parser.parse_args()

def main():
    """Main entry point for the script."""
    args = parse_args()
    
    # Set up logging
    log_file = setup_logging()
    
    # Set log level
    log_level = getattr(logging, args.log_level)
    logging.getLogger().setLevel(log_level)
    
    # Log script start
    logging.info("=" * 80)
    logging.info("STARTING PAYMENT VALIDATION EXPORT PROCESS")
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