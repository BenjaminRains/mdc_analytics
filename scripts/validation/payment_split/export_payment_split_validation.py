#!/usr/bin/env python3
"""
Export Payment Split Validation Data

This script connects to the specified database, loads a set of common table expressions (CTEs) 
from a separate file, and executes a series of SQL queries for payment split validation. 
The results for each query are exported to separate CSV files. The files are then analyzed 
in notebooks to identify and diagnose issues.

Usage:
    python export_payment_split_validation.py --start-date <YYYY-MM-DD> --end-date <YYYY-MM-DD>
                                                [--output-dir <path>] [--log-dir <path>]
                                                [--database <dbname>] [--queries <names>]
                                                [--connection-type <type>]
                                                [--parallel]

NOTE: The --start-date and --end-date parameters are REQUIRED. All data will be filtered 
to this date range, ensuring consistent results across all validation queries.

The list of queries and the common CTE definitions are stored as separate .sql files in
the 'queries' directory. The CTE file is prepended to each query before execution.
"""

from datetime import datetime, date, timedelta
import os
import logging
import pandas as pd
import re
import sys
from pathlib import Path
import argparse
import csv
import traceback
from dataclasses import dataclass
from typing import Optional, List, Dict, Any, Set, Tuple, NamedTuple
from dotenv import load_dotenv

# Configure basic logging until we can set up proper logging
logging.basicConfig(level=logging.INFO, 
                   format='%(asctime)s - %(levelname)s - %(message)s')

# Add base directory to path for relative imports if needed
script_dir = os.path.dirname(os.path.abspath(__file__))
base_dir = os.path.abspath(os.path.join(script_dir, '../..'))
if base_dir not in sys.path:
    sys.path.insert(0, base_dir)

# Add the src directory to the path to import project modules
src_path = Path(__file__).resolve().parents[3]
sys.path.append(str(src_path))

# Load environment variables from src/.env
env_path = src_path / "src" / ".env"
load_dotenv(dotenv_path=env_path)

# Import the ConnectionFactory from the src module
from src.connections.factory import ConnectionFactory, get_valid_databases

# Import DateRange from utils module
from scripts.validation.payment_split.utils.sql_export_utils import DateRange, apply_date_parameters

# Define regex pattern for include directives
INCLUDE_PATTERN = re.compile(r'<<include:([^>]+)>>')

# Utility functions
def read_sql_file(file_path: str) -> str:
    """Read the contents of a SQL file."""
    try:
        with open(file_path, 'r') as f:
            return f.read()
    except Exception as e:
        logging.error(f"Error reading SQL file {file_path}: {str(e)}")
        return ""

def process_includes(sql_content: str, base_dir: Optional[str] = None, processed_files: Optional[set] = None, processed_ctes: Optional[dict] = None) -> str:
    """
    Process include directives in SQL content by replacing <<include:filename.sql>> with 
    the content of the referenced file.
    
    Args:
        sql_content: SQL content to process
        base_dir: The base directory to look for included files (defaults to queries/ctes)
        processed_files: Set of already processed files to prevent infinite recursion
        processed_ctes: Dictionary of already processed CTE names and their contents to prevent duplicates
        
    Returns:
        SQL content with includes replaced and properly formatted
    """
    if processed_files is None:
        processed_files = set()
    
    if processed_ctes is None:
        processed_ctes = {}
    
    if base_dir is None:
        base_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'queries', 'ctes')
    
    # Convert base_dir to Path object for easier path manipulation
    base_dir_path = Path(base_dir)
    queries_dir = base_dir_path.parent if base_dir_path.name == 'ctes' else base_dir_path
    
    # Find all include directives in the content
    include_pattern = r'<<include:([^>]+)>>'
    includes = re.findall(include_pattern, sql_content)
    
    if not includes:
        return sql_content
        
    logging.info(f"Found include directives in SQL, processing...")
    
    # Process each include directive
    for include_path in includes:
        # Determine the correct path to the include file
        if include_path.startswith('ctes/'):
            include_file = queries_dir / include_path
        else:
            include_file = base_dir_path / include_path
            if not include_file.exists() and base_dir_path.name != 'ctes':
                include_file = base_dir_path / 'ctes' / include_path
        
        include_path_str = str(include_file)
        
        # Check if file exists
        if not include_file.exists():
            logging.warning(f"Could not find included file: {include_file}")
            sql_content = sql_content.replace(f'<<include:{include_path}>>', '')
            continue
            
        # Skip if we've already processed this file to avoid circular inclusion
        # but don't log a warning, as our CTE topological sorting will handle dependencies
        if include_path_str in processed_files:
            sql_content = sql_content.replace(f'<<include:{include_path}>>', '')
            continue
            
        # Add file to processed files to prevent circular recursion
        processed_files.add(include_path_str)
        
        # Read the include file content
        included_content = read_sql_file(include_path_str)
        
        # Process includes in the included file recursively
        if included_content:
            processed_included_content = process_includes(
                included_content,
                os.path.dirname(include_path_str),
                processed_files.copy(),  # Use a copy to prevent cross-contamination between branches
                processed_ctes
            )
            
            # Replace the include directive with the processed content
            sql_content = sql_content.replace(f'<<include:{include_path}>>', processed_included_content)
    
    logging.info(f"Successfully processed includes in SQL")
    return sql_content

# Get the list of valid databases from environment
try:
    # Use get_valid_databases from factory
    valid_databases = get_valid_databases('LOCAL_VALID_DATABASES')
except Exception as e:
    logging.warning(f"Could not get valid databases: {str(e)}")
    valid_databases = []

# Get default database from environment (use ODDB_NAME as fallback)
default_database = os.getenv('MARIADB_DATABASE') or os.getenv('ODDB_NAME')
if not default_database and valid_databases:
    default_database = valid_databases[0]  # Use first valid database as default if available

# Query descriptions to provide context on what each query analyzes
QUERY_DESCRIPTIONS = {
    'summary': 'High-level summary of payment splits and associated metrics',
    'base_counts': 'Basic count statistics of payments and procedures',
    'source_counts': 'Analysis of payment sources and their distribution',
    'filter_summary': 'Summary of how filters affect the dataset',
    'diagnostic': 'Detailed diagnostic information for troubleshooting',
    'verification': 'Verification of data integrity and consistency',
    'problems': 'Identification of potential issues in payment splits',
    'duplicate_joins': 'Analysis of duplicate join conditions',
    'join_stages': 'Progression of join operations and their effects',
    'daily_patterns': 'Day-by-day analysis of payment patterns',
    'payment_details': 'Detailed information about individual payments',
    'containment': 'Analysis of payment containment relationships',
}

def setup_logging(log_dir='scripts/validation/payment_split/logs'):
    """Set up logging to file and console."""
    # Ensure log directory exists
    os.makedirs(log_dir, exist_ok=True)
    
    # Set up timestamp for log filename
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"payment_validation_{timestamp}.log")
    
    # Reset logging configuration
    for handler in logging.root.handlers[:]:
        logging.root.removeHandler(handler)
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,  # Root logger level set to INFO
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            # File handler with DEBUG level for detailed troubleshooting
            logging.FileHandler(log_file),
            # Console handler with INFO level
            logging.StreamHandler()
        ]
    )
    
    # Set file handler to DEBUG level to capture detailed logs
    logging.getLogger().handlers[0].setLevel(logging.DEBUG)
    # Set console handler to INFO level for cleaner output
    logging.getLogger().handlers[1].setLevel(logging.INFO)
    
    logging.info(f"Logging configured - writing detailed logs to {log_file}")
    return log_file

def ensure_directory_exists(directory):
    """Create directory if it doesn't exist."""
    Path(directory).mkdir(parents=True, exist_ok=True)
    logging.info(f"Ensured directory exists: {directory}")

def load_query_file(query_name: str) -> str:
    """Load a query from the queries directory using pathlib."""
    query_path = Path(__file__).parent / 'queries' / f'{query_name}.sql'
    return read_sql_file(query_path)

def check_sql_syntax(sql_content: str) -> tuple:
    """
    Check SQL syntax for common issues after processing includes.
    
    Args:
        sql_content: SQL content to check
        
    Returns:
        Tuple of (is_valid, issues_found)
    """
    is_valid = True
    issues = []
    
    # Check for unprocessed include directives
    include_matches = INCLUDE_PATTERN.findall(sql_content)
    if include_matches:
        is_valid = False
        issues.append(f"Unprocessed include directives found: {include_matches}")
    
    # Check for multiple WITH statements (MariaDB only supports one)
    with_matches = re.findall(r'^\s*WITH\s+', sql_content, re.MULTILINE | re.IGNORECASE)
    if len(with_matches) > 1:
        is_valid = False
        issues.append(f"Multiple WITH statements found: {len(with_matches)}. MariaDB only supports one WITH clause.")
    
    # Check for missing commas between CTEs
    if re.search(r'\)\s+([A-Za-z][A-Za-z0-9_]*)\s+AS\s*\(', sql_content) and not re.search(r'\),\s+[A-Za-z][A-Za-z0-9_]*\s+AS\s*\(', sql_content):
        is_valid = False
        issues.append("Missing commas between CTE definitions")
    
    # Check for missing semicolons at the end of statements
    if not sql_content.strip().endswith(';'):
        # If this is a SELECT statement and doesn't end with a semicolon, suggest adding one
        if re.search(r'^\s*(?:WITH\s+)?.*SELECT\s', sql_content, re.IGNORECASE | re.DOTALL):
            issues.append("Query does not end with a semicolon, which is recommended for MariaDB statements")
    
    # Very basic checks for common syntax errors
    common_errors = [
        (r'FROM\s+FROM', "Duplicate FROM keyword found"),
        (r'WHERE\s+WHERE', "Duplicate WHERE keyword found"),
        (r'SELECT\s+SELECT', "Duplicate SELECT keyword found"),
        (r'GROUP\s+GROUP', "Duplicate GROUP keyword found"),
        (r'ORDER\s+ORDER', "Duplicate ORDER keyword found"),
        (r'BY\s+BY', "Duplicate BY keyword found"),
        (r'HAVING\s+HAVING', "Duplicate HAVING keyword found"),
        (r'JOIN\s+JOIN', "Duplicate JOIN keyword found"),
        (r'FROM\s+WHERE', "Missing table specification in FROM clause"),
        (r'WHERE\s+ORDER', "Missing condition in WHERE clause"),
        (r'GROUP\s+HAVING', "Missing columns in GROUP BY clause"),
        (r'SELECT\s+FROM', "Missing columns in SELECT clause")
    ]
    
    for pattern, message in common_errors:
        if re.search(pattern, sql_content, re.IGNORECASE):
            is_valid = False
            issues.append(message)
    
    return is_valid, issues

def get_ctes(date_range: DateRange = None) -> str:
    """
    Load and combine all CTE definitions.
    
    Args:
        date_range: Optional date range to apply to queries
        
    Returns:
        Combined CTE SQL content
    """
    # Find all CTE files
    cte_dir = Path(os.path.dirname(os.path.abspath(__file__))) / 'queries' / 'ctes'
    if not cte_dir.exists():
        logging.error(f"CTE directory not found: {cte_dir}")
        return ""
    
    # Get all SQL files
    cte_files = list(cte_dir.glob('*.sql'))
    if not cte_files:
        logging.warning(f"No CTE files found in {cte_dir}")
        return ""
    
    logging.info(f"Found {len(cte_files)} CTE definition files")
    
    # Track processed dependencies to avoid duplicates
    dependencies_processed = set()
    all_ctes = []
    processed_cte_names = set()
    
    # Dictionary to store CTE definitions with their name as key
    cte_definitions = {}
    
    # Dictionary to track dependencies between CTEs
    cte_dependencies = {}
    
    # First pass: load all CTE definitions and extract their names
    for cte_file in cte_files:
        try:
            logging.debug(f"Loading CTE file: {cte_file}")
            
            # Skip if already processed
            if str(cte_file) in dependencies_processed:
                logging.debug(f"Already processed CTE file: {cte_file}")
                continue
            
            # Read the file content
            cte_content = read_sql_file(str(cte_file))
            if not cte_content:
                logging.warning(f"Empty or invalid CTE file: {cte_file}")
                continue
                
            # Process includes within the CTE
            cte_content = process_includes(cte_content)
            
            # Add to processed dependencies
            dependencies_processed.add(str(cte_file))
            
            # Check for SQL syntax issues
            is_valid, issues = check_sql_syntax(cte_content)
            if not is_valid:
                logging.warning(f"SQL syntax issues in {cte_file} after processing includes:")
                for issue in issues:
                    logging.warning(f"  - {issue}")
            
            # Apply date parameters
            if cte_content:
                cte_content = apply_date_parameters(cte_content, date_range)
                
                # Extract just the CTE definition (strip out any WITH keywords)
                # Look for pattern like "WITH CTE_Name AS (" or just "CTE_Name AS ("
                cte_content = cte_content.strip()
                cte_match = re.search(r'(?:WITH\s+)?(\w+\s+AS\s*\(.*)', cte_content, re.DOTALL | re.IGNORECASE)
                if cte_match:
                    cte_definition = cte_match.group(1).strip()
                    
                    # Extract CTE name
                    cte_name_match = re.match(r'^(\w+)\s+AS\s*\(', cte_definition)
                    if cte_name_match:
                        cte_name = cte_name_match.group(1)
                        
                        # Store the CTE definition with its name
                        cte_with_comment = f"""
-- From {cte_file.name}
{cte_definition}"""
                        cte_definitions[cte_name] = cte_with_comment
                        
                        # Initialize empty dependency list for this CTE
                        cte_dependencies[cte_name] = set()
                        
                        logging.debug(f"Identified CTE: {cte_name} from {cte_file.name}")
                    else:
                        logging.warning(f"Could not extract CTE name from {cte_file.name}")
                else:
                    logging.warning(f"Could not extract CTE definition from {cte_file.name}")
        except Exception as e:
            logging.error(f"Error loading CTE file {cte_file}: {str(e)}", exc_info=True)
    
    # Second pass: analyze dependencies between CTEs
    for cte_name, cte_definition in cte_definitions.items():
        # Look for references to other CTEs in this definition
        for other_cte_name in cte_definitions.keys():
            if other_cte_name != cte_name and re.search(r'\b' + re.escape(other_cte_name) + r'\b', cte_definition):
                # This CTE depends on other_cte_name
                cte_dependencies[cte_name].add(other_cte_name)
                logging.debug(f"CTE {cte_name} depends on {other_cte_name}")
    
    # Function to perform topological sort
    def topological_sort():
        # Track visited nodes and detect cycles
        visited = set()
        temp_visited = set()
        result = []
        
        def visit(node):
            if node in temp_visited:
                # This is a cycle, but we'll still include the node
                logging.warning(f"Circular dependency detected involving CTE: {node}")
                return
            
            if node in visited:
                return
                
            temp_visited.add(node)
            
            # Visit dependencies first
            for dependency in cte_dependencies.get(node, set()):
                visit(dependency)
                
            temp_visited.remove(node)
            visited.add(node)
            result.append(node)
            
        # Visit each node
        for node in list(cte_dependencies.keys()):
            if node not in visited:
                visit(node)
                
        return result
    
    # Get sorted CTEs
    sorted_ctes = topological_sort()
    logging.info(f"Ordered {len(sorted_ctes)} CTEs based on dependencies")
    
    # Build the combined CTEs in the sorted order
    all_ctes = [cte_definitions[cte_name] for cte_name in sorted_ctes]
    
    # Join all CTEs with appropriate separators
    if not all_ctes:
        logging.warning("No CTEs were loaded successfully")
        return ""
    
    combined_ctes = "WITH "
    for i, cte in enumerate(all_ctes):
        if i > 0:
            # If not the first CTE, add a comma and newline before it
            combined_ctes += ",\n"
        combined_ctes += cte.strip()
    
    logging.info(f"Combined {len(all_ctes)} CTEs into query structure")
    
    # Final check on combined CTEs
    is_valid, issues = check_sql_syntax(combined_ctes)
    if not is_valid:
        logging.warning("SQL syntax issues in combined CTEs:")
        for issue in issues:
            logging.warning(f"  - {issue}")
    
    return combined_ctes

def extract_ctes_and_query(sql_content):
    """
    Extract all CTE definitions and the main query from SQL content.
    Handles multiple CTEs and properly separates them from the main query.
    
    Args:
        sql_content: The SQL content to parse
        
    Returns:
        tuple: (list of CTE definitions, main query string)
    """
    # Split the SQL content into lines for easier processing
    lines = sql_content.split('\n')
    
    # Keep track of CTEs and the main query
    cte_lines = []
    current_cte_lines = []
    main_query_lines = []
    in_cte = False
    open_parens = 0
    
    for line in lines:
        stripped = line.strip()
        
        # Check if this line starts a new CTE
        cte_match = re.match(r'^([A-Za-z][A-Za-z0-9_]*)\s+AS\s*\(', stripped)
        
        if cte_match and not in_cte:
            # This is the start of a new CTE
            cte_name = cte_match.group(1)
            in_cte = True
            current_cte_lines = [line]
            open_parens = line.count('(') - line.count(')')
            continue
        
        if in_cte:
            # We're inside a CTE definition
            current_cte_lines.append(line)
            open_parens += line.count('(') - line.count(')')
            
            # Check if this is the end of the CTE
            if open_parens <= 0:
                # We've found the end of the CTE
                cte_lines.append('\n'.join(current_cte_lines))
                current_cte_lines = []
                in_cte = False
                open_parens = 0
            continue
        
        # If not in a CTE and line is not empty, it's part of the main query
        if stripped and not stripped.startswith('--'):
            main_query_lines.append(line)
    
    # If we still have an open CTE, add it to the list
    if current_cte_lines:
        cte_lines.append('\n'.join(current_cte_lines))
    
    # Combine the main query lines
    main_query = '\n'.join(main_query_lines).strip()
    
    # If no main query but we have CTEs, check if the main query is embedded in the last CTE
    if not main_query and cte_lines:
        # Look for a SELECT statement after the last CTE
        select_match = re.search(r'\)\s*(SELECT\s.*)', cte_lines[-1], re.DOTALL)
        if select_match:
            main_query = select_match.group(1).strip()
            # Remove the main query part from the last CTE
            cte_lines[-1] = cte_lines[-1][:select_match.start(1)].rstrip()
    
    return cte_lines, main_query

def balance_parentheses(sql_content: str) -> str:
    """
    Ensure that parentheses are balanced in the SQL content.
    If there are more opening parentheses than closing ones, add the missing closing parentheses.
    
    Args:
        sql_content: SQL content to check
        
    Returns:
        SQL content with balanced parentheses
    """
    # Count parentheses excluding those in string literals and comments
    open_count = 0
    close_count = 0
    in_string = False
    string_char = None
    in_comment = False
    in_line_comment = False
    
    for i, char in enumerate(sql_content):
        # Check for string boundaries
        if char in ("'", '"') and not in_comment and not in_line_comment:
            if not in_string:
                in_string = True
                string_char = char
            elif char == string_char:
                # Check for escaped quotes
                if i > 0 and sql_content[i-1] == '\\':
                    # This is an escaped quote
                    pass
                else:
                    in_string = False
                    string_char = None
        
        # Check for comment boundaries
        elif char == '-' and i+1 < len(sql_content) and sql_content[i+1] == '-' and not in_string and not in_comment:
            in_line_comment = True
        elif char == '\n' and in_line_comment:
            in_line_comment = False
        elif char == '/' and i+1 < len(sql_content) and sql_content[i+1] == '*' and not in_string and not in_line_comment:
            in_comment = True
        elif char == '*' and i+1 < len(sql_content) and sql_content[i+1] == '/' and in_comment:
            in_comment = False
        
        # Count parentheses only outside of strings and comments
        elif not in_string and not in_comment and not in_line_comment:
            if char == '(':
                open_count += 1
            elif char == ')':
                close_count += 1
    
    # Add missing parentheses
    if open_count > close_count:
        # Add missing closing parentheses at the end
        sql_content = sql_content.rstrip() + ')' * (open_count - close_count)
        logging.info(f"Added {open_count - close_count} closing parentheses to balance the SQL")
    elif close_count > open_count:
        # Add missing opening parentheses at the beginning
        sql_content = '(' * (close_count - open_count) + sql_content.lstrip()
        logging.info(f"Added {close_count - open_count} opening parentheses to balance the SQL")
    
    return sql_content

def get_query(query_name: str, date_range: DateRange = None) -> dict:
    """
    Get a query file, process its includes, substitute parameters, and return
    the configured query with proper CTEs and date parameters.
    
    Args:
        query_name: Name of the query file (without extension)
        date_range: Optional date range to set parameters
        
    Returns:
        Dictionary with query configuration including processed SQL
    """
    if not query_name.endswith('.sql'):
        query_name = f"{query_name}.sql"
    
    query_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'queries', query_name)
    
    if not os.path.exists(query_path):
        logging.error(f"Query file not found: {query_path}")
        return None
    
    # Read the raw SQL content
    sql_content = read_sql_file(query_path)
    
    # Process includes in the query file
    if re.search(r'<<\s*include\s*:', sql_content):
        logging.info(f"Found include directives in {query_name}, processing...")
        base_dir = os.path.dirname(query_path)
        sql_content = process_includes(sql_content, base_dir)
        logging.info(f"Successfully processed includes in {query_name}")
    
    # Apply date parameters if provided
    if date_range:
        logging.info(f"Applying date parameters to {query_name}: {date_range}")
        sql_content = apply_date_parameters(sql_content, date_range)
    
    # Extract all CTEs and the main query
    cte_definitions, main_query = extract_ctes_and_query(sql_content)
    
    # Process each CTE to ensure parentheses are balanced
    balanced_cte_definitions = []
    for cte_def in cte_definitions:
        balanced_cte_def = balance_parentheses(cte_def)
        balanced_cte_definitions.append(balanced_cte_def)
    
    # Build the query with a proper WITH statement
    if balanced_cte_definitions:
        final_sql = "WITH " + ",\n".join(balanced_cte_definitions)
        if main_query:
            final_sql += "\n" + main_query
    else:
        final_sql = main_query
    
    # Ensure the final SQL has balanced parentheses
    final_sql = balance_parentheses(final_sql)
    
    # Check for syntax issues
    is_valid, issues = check_sql_syntax(final_sql)
    if not is_valid:
        for issue in issues:
            logging.warning(f"SQL syntax issue in {query_name}: {issue}")
    
    # Return the query configuration
    return {
        'name': os.path.splitext(query_name)[0],
        'query': query_name,
        'description': QUERY_DESCRIPTIONS.get(os.path.splitext(query_name)[0], "Validation query"),
        'final_query': final_sql
    }

def get_exports(date_range: DateRange = None) -> list:
    """
    Get the list of export queries to run.
    
    Args:
        date_range: DateRange object with start and end dates
        
    Returns:
        List of export configurations
    """
    # Require a DateRange to be provided
    if date_range is None:
        raise ValueError("Date range must be provided")
    
    # List of allowed queries to process
    allowed_queries = [
        "base_counts.sql",
        "containment.sql",
        "daily_patterns.sql",
        "diagnostic.sql",
        "duplicate_joins.sql",
        "filter_summary.sql",
        "join_stages.sql",
        "payment_details.sql",
        "problems.sql",
        "source_counts.sql",
        "summary.sql",
        "verification.sql"
    ]
    
    # Get available export queries
    query_exports = []
    queries_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'queries')
    
    if os.path.isdir(queries_dir):
        # Process only the allowed query files
        for query_file in allowed_queries:
            query_path = os.path.join(queries_dir, query_file)
            if os.path.exists(query_path):
                query_name = os.path.splitext(query_file)[0]
                query_exports.append(query_name)
                logging.info(f"Found query file: {query_file}")
            else:
                logging.warning(f"Query file not found: {query_file}")
    
    if not query_exports:
        # Raise an error when no queries are found
        error_msg = "No query files found in the queries directory or none of the allowed queries exist"
        logging.error(error_msg)
        raise ValueError(error_msg)
    
    # Create the export configurations
    exports = []
    for query_name in query_exports:
        query_config = get_query(query_name, date_range=date_range)
        if query_config:  # Only add if we got a valid config
            exports.append(query_config)
            logging.info(f"Prepared export configuration for: {query_name}")
    
    return exports

def process_single_export(connection_type, database, export, output_dir, date_range):
    """
    Process a single export configuration and save results to CSV.
    
    Args:
        connection_type: Type of database connection to use
        database: Database name to connect to
        export: Export configuration dictionary
        output_dir: Directory to write CSV output files
        date_range: DateRange object with start/end dates
        
    Returns:
        Boolean indicating success or failure
    """
    logging.info(f"Processing export: {export['name']}")
    
    # Initialize connection to None
    connection = None
    
    # Build the query by combining CTEs and main query
    try:
        query_details = get_query(export['query'], date_range=date_range)
        if not query_details:
            logging.error(f"Could not generate query for {export['name']}")
            return False
            
        query = query_details['final_query']
        
        # Get a database connection from the factory
        try:
            connection = ConnectionFactory.create_connection(connection_type, database)
            if not connection:
                logging.error(f"Could not get database connection for {connection_type}")
                return False
        except Exception as e:
            logging.error(f"Connection error: {str(e)}")
            return False
            
        # Execute main query
        logging.info(f"Executing main query for {export['name']}")
        
        try:
            # Execute the query directly with pandas
            result_df = pd.read_sql(query, connection)
            
            # Write to CSV
            output_file = os.path.join(output_dir, f"{export['name']}.csv")
            
            if not result_df.empty:
                result_df.to_csv(output_file, index=False)
                logging.info(f"Exported {len(result_df)} rows to {output_file}")
                return True
            else:
                logging.warning(f"No results returned for {export['name']}")
                # Write an empty file with headers
                with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
                    # Use the column names from the DataFrame if available
                    if not result_df.empty and len(result_df.columns) > 0:
                        writer = csv.writer(csvfile)
                        writer.writerow(result_df.columns)
                        logging.info(f"Created empty results file with headers: {output_file}")
                    else:
                        # No columns available, write a comment
                        csvfile.write("# No results returned\n")
                        logging.info(f"Created empty results file: {output_file}")
                return True
        except Exception as e:
            logging.error(f"Error during query execution for {export['name']}: {str(e)}")
            return False
            
    except Exception as e:
        logging.error(f"Error processing export {export['name']}: {str(e)}")
        return False
    finally:
        if connection and hasattr(connection, 'close'):
            connection.close()
            logging.info("Database connection closed")
    
    return True

def export_validation_results(connection_type, database, start_date, end_date,
                         queries=None, output_dir=None):
    """
    Export validation results to CSV files based on configured queries.
    
    Args:
        connection_type: Type of database connection to use
        database: Database name to connect to
        start_date: Start date for data range (string in YYYY-MM-DD format)
        end_date: End date for data range (string in YYYY-MM-DD format)
        queries: List of specific queries to run (defaults to all)
        output_dir: Directory to write CSV output files
    """
    # Create date range using from_strings class method for proper conversion
    date_range = DateRange.from_strings(start_date, end_date)
    
    # Log basic configuration information
    logging.info(f"Starting export with database: {database}")
    logging.info(f"Date range: {date_range.start_date} to {date_range.end_date}")
    
    # Set up output directory
    if output_dir is None:
        output_dir = f"scripts/validation/payment_split/output/{date_range.start_date.strftime('%Y%m%d')}_to_{date_range.end_date.strftime('%Y%m%d')}"
    
    # Make sure output directory exists
    ensure_directory_exists(output_dir)
    logging.info(f"Output directory: {output_dir}")
    
    # Get all available exports
    try:
        all_exports = get_exports(date_range)
        
        # Filter exports based on user selection if provided
        exports = []
        if queries:
            # Convert queries to set for faster lookups
            query_set = {q.lower().replace('.sql', '') for q in queries}
            exports = [e for e in all_exports if e['name'].lower() in query_set]
            logging.info(f"Filtered to {len(exports)}/{len(all_exports)} queries")
        else:
            exports = all_exports
            logging.info(f"Processing all {len(exports)} available queries")
        
        if not exports:
            logging.error("No matching queries found")
            return
        
        # Process each export sequentially
        success_count = 0
        for export in exports:
            if process_single_export(connection_type, database, export, output_dir, date_range):
                success_count += 1
        
        # Log summary
        logging.info(f"Export completed: {success_count}/{len(exports)} successful")
        
    except Exception as e:
        logging.error(f"Error during export: {str(e)}")
        raise

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
    """Main entry point for script."""
    # Parse command line arguments
    args = parse_args()
    
    # Setup logging
    setup_logging()
    
    # Print startup info
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
    
    # Run the export
    try:
        export_validation_results(
            args.connection_type,
            args.database,
            args.start_date,
            args.end_date,
            args.queries,
            args.output_dir
        )
    except Exception as e:
        logging.critical(f"Unhandled exception: {str(e)}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
