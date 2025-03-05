"""
SQL Export Utilities

This module provides shared utility functions for SQL extraction, date handling, 
and CSV export operations used by the payment validation scripts.

The functions in this module support:
- Date range handling for SQL parameters
- SQL file reading and query extraction
- CSV export with consistent naming

Use these utilities to standardize processes across different export scripts.
"""

import os
import re
import logging
from datetime import date, datetime
from pathlib import Path
from typing import Dict, NamedTuple, Any, List, Optional, Union

import pandas as pd

# =====================================================================
# Date Handling Utilities
# =====================================================================

class DateRange(NamedTuple):
    """Represents a date range for filtering data in queries."""
    start_date: date
    end_date: date
    
    @classmethod
    def from_strings(cls, start: str, end: str) -> 'DateRange':
        """
        Create a DateRange from string dates in YYYY-MM-DD format
        
        Args:
            start: Start date string (YYYY-MM-DD)
            end: End date string (YYYY-MM-DD)
            
        Returns:
            DateRange object
        """
        try:
            start_date = datetime.strptime(start, "%Y-%m-%d").date()
            end_date = datetime.strptime(end, "%Y-%m-%d").date()
            return cls(start_date, end_date)
        except ValueError as e:
            raise ValueError(f"Invalid date format. Use YYYY-MM-DD: {e}")


def apply_date_parameters(sql: str, date_range: DateRange) -> str:
    """
    Apply date parameters to SQL query, replacing placeholders with actual dates
    
    This function replaces date placeholders in SQL queries with actual date values.
    It handles various formats including standardized @start_date and @end_date variables.
    
    Args:
        sql: SQL query string
        date_range: DateRange object
        
    Returns:
        SQL query with date parameters applied
    """
    # Convert date range to strings
    from_date_str = date_range.start_date.strftime("%Y-%m-%d")
    to_date_str = date_range.end_date.strftime("%Y-%m-%d")
    
    logging.debug(f"Applying date parameters: {from_date_str} to {to_date_str}")
    
    # Replace date placeholders in the SQL
    modified_sql = sql
    
    # First, handle template-style placeholders (these take priority)
    modified_sql = modified_sql.replace('{{START_DATE}}', from_date_str)
    modified_sql = modified_sql.replace('{{END_DATE}}', to_date_str)
    
    # Replace specific date literals used as standard placeholders
    date_patterns = [
        # Standard variables in SQL scripts - prioritize these replacements
        (r"SET @start_date = '[^']+';", f"SET @start_date = '{from_date_str}';"),
        (r"SET @end_date = '[^']+';", f"SET @end_date = '{to_date_str}';"),
        
        # Support legacy variable formats for backward compatibility
        (r"SET @FromDate = '[^']+';", f"SET @FromDate = '{from_date_str}';"),
        (r"SET @ToDate = '[^']+';", f"SET @ToDate = '{to_date_str}';"),
        (r"SET @@start_date = '[^']+';", f"SET @start_date = '{from_date_str}';"),
        (r"SET @@end_date = '[^']+';", f"SET @end_date = '{to_date_str}';"),
        
        # Standard hardcoded date replacements for backward compatibility
        (r"'2024-01-01'", f"'{from_date_str}'"),
        (r"'2025-01-01'", f"'{from_date_str}'"),
        (r"'2025-02-28'", f"'{to_date_str}'"),
        (r"'2025-03-15'", f"'{to_date_str}'"),
        
        # Date function replacements
        (r"DATE_SUB\(CURDATE\(\), INTERVAL \d+ DAY\)", f"'{from_date_str}'"),
        (r"DATE_SUB\(NOW\(\), INTERVAL \d+ DAY\)", f"'{from_date_str}'"),
        (r"CURDATE\(\)", f"'{to_date_str}'"),
        (r"NOW\(\)", f"'{to_date_str}'"),
        
        # Date range with year filter
        (r"YEAR\(DatePay\) = 2025", f"DatePay BETWEEN '{from_date_str}' AND '{to_date_str}'"),
        
        # Generic date range replacements
        (r"BETWEEN '2025-01-01' AND '2025-02-28'", 
         f"BETWEEN '{from_date_str}' AND '{to_date_str}'"),
        
        # Handle specific start date only conditions
        (r"DatePay > '2025-01-01'", f"DatePay > '{from_date_str}'")
    ]
    
    # Apply all date replacements
    for pattern, replacement in date_patterns:
        modified_sql = re.sub(pattern, replacement, modified_sql)
    
    return modified_sql


# =====================================================================
# SQL File Reading and Query Extraction
# =====================================================================

def read_sql_file(file_path: Path) -> str:
    """
    Read SQL file contents
    
    Args:
        file_path: Path to SQL file
        
    Returns:
        String containing SQL file contents
    """
    with open(file_path, 'r') as f:
        return f.read()


def sanitize_table_name(name: str) -> str:
    """
    Sanitize a name for use as a file name by removing special characters
    
    Args:
        name: Raw name to sanitize
        
    Returns:
        Sanitized name suitable for file naming
    """
    # Remove any non-alphanumeric characters except underscores
    sanitized = re.sub(r'[^\w\d_]', '_', name)
    # Replace multiple consecutive underscores with a single one
    sanitized = re.sub(r'_+', '_', sanitized)
    # Remove leading and trailing underscores
    sanitized = sanitized.strip('_')
    return sanitized


def extract_queries_with_markers(full_sql: str, date_range: DateRange) -> Dict[str, str]:
    """
    Extract queries from SQL file that uses QUERY_NAME markers
    
    Args:
        full_sql: String containing all SQL queries
        date_range: DateRange object for date parameter substitution
        
    Returns:
        Dictionary mapping query names to query strings
    """
    queries = {}
    query_mappings = []
    
    # Split the SQL file by query name markers
    query_sections = re.split(r'--\s*QUERY_NAME:', full_sql)
    
    # Skip the first section (file header)
    if len(query_sections) > 1:
        query_sections = query_sections[1:]
    
    for i, section in enumerate(query_sections):
        # Extract the query name from the first line
        name_match = re.match(r'^([^\n\r]+)', section)
        if not name_match:
            logging.warning(f"Could not extract query name from section {i+1}")
            continue
            
        query_name = name_match.group(1).strip()
        
        # Find the actual SQL query (after the comment block)
        # We look for the first SELECT statement and everything until the next query marker or end of section
        sql_match = re.search(r'(SELECT[\s\S]+?)((?=--\s*QUERY_NAME:)|$)', section, re.IGNORECASE)
        
        if sql_match:
            # Get just the SQL part
            sql_text = sql_match.group(1).strip()
            
            # Remove trailing comments if present (before the next query)
            sql_text = re.sub(r'/\*[\s\S]*?$', '', sql_text)
            
            # Make sure the query ends with a semicolon
            if not sql_text.rstrip().endswith(';'):
                sql_text = sql_text.rstrip() + ';'
                
            # Apply date parameters to the query
            parameterized_query = apply_date_parameters(sql_text, date_range)
            
            # Use a clean version of the query name as the key
            clean_name = sanitize_table_name(query_name.lower().replace(' ', '_'))
            
            # Extract title from the comment block
            title_match = re.search(r'\*\s*QUERY\s+\d+[A-C]?:\s*([^\n]*)', section)
            query_title = title_match.group(1).strip() if title_match else query_name
            
            queries[clean_name] = parameterized_query
            query_mappings.append((clean_name, query_title))
            
            logging.info(f"Extracted query '{clean_name}': {query_title}")
        else:
            logging.warning(f"Could not find SQL in section with name: {query_name}")
    
    # Log mapping information
    if query_mappings:
        logging.info("Query name to title mapping:")
        for query_name, query_title in query_mappings:
            ascii_title = re.sub(r'[^\x00-\x7F]+', '_', query_title)  # Ensure ASCII-compatible
            logging.info(f"  - {query_name} -> {ascii_title}")
    
    return queries


def extract_queries_with_patterns(full_sql: str, date_range: DateRange, 
                                 patterns: Dict[str, Dict[str, str]]) -> Dict[str, str]:
    """
    Extract queries from SQL file using specific regex patterns for each query
    
    Args:
        full_sql: String containing all SQL queries
        date_range: DateRange object for date parameter substitution
        patterns: Dictionary mapping query names to pattern dictionaries
                 Each pattern dict should have keys 'pattern' and 'description'
        
    Returns:
        Dictionary mapping query names to query strings
    """
    queries = {}
    query_mappings = []
    
    # Extract date parameters section if present
    date_params_pattern = r"(-- Set date parameters.*?SET @ToDate = '[^']+';)"
    date_params_match = re.search(date_params_pattern, full_sql, re.DOTALL)
    date_params = date_params_match.group(1) if date_params_match else ""
    
    # Update date parameters to use provided dates
    date_params = apply_date_parameters(date_params, date_range)
    
    # Extract each query using its specific pattern
    for query_name, pattern_info in patterns.items():
        pattern = pattern_info['pattern']
        description = pattern_info['description']
        
        query_match = re.search(pattern, full_sql, re.DOTALL)
        if query_match:
            # Get the matched SQL text
            sql_text = query_match.group(1) if query_match.groups() else ""
            
            # Add date parameters if needed
            if date_params and not "SET @FromDate" in sql_text:
                processed_query = f"{date_params}\n\n{sql_text}"
            else:
                processed_query = sql_text
            
            # Apply date parameters
            parameterized_query = apply_date_parameters(processed_query, date_range)
            
            queries[query_name] = parameterized_query
            query_mappings.append((query_name, description))
            
            logging.info(f"Extracted query '{query_name}': {description}")
        else:
            logging.warning(f"Could not find query matching pattern for: {query_name}")
    
    # Log mapping information
    if query_mappings:
        logging.info("Query name to description mapping:")
        for query_name, description in query_mappings:
            logging.info(f"  - {query_name} -> {description}")
    
    return queries


def extract_all_queries_generic(full_sql: str, date_range: DateRange) -> Dict[str, str]:
    """
    Generic fallback method to extract SQL queries when structured patterns fail
    
    Args:
        full_sql: String containing all SQL queries
        date_range: DateRange object for date parameter substitution
        
    Returns:
        Dictionary mapping query names to query strings
    """
    queries = {}
    
    # Try to find all complete SQL statements
    sql_blocks = re.finditer(r'(SELECT[\s\S]+?;)', full_sql, re.IGNORECASE)
    
    for i, match in enumerate(sql_blocks, 1):
        sql_text = match.group(0).strip()
        
        # Apply date parameters to the query
        parameterized_query = apply_date_parameters(sql_text, date_range)
        
        # Use a generic name
        query_name = f"query_{i}"
        
        queries[query_name] = parameterized_query
        logging.info(f"Extracted query '{query_name}' using generic method")
    
    return queries


# =====================================================================
# CSV Export Utilities
# =====================================================================

def export_to_csv(df: pd.DataFrame, 
                 output_dir: Path, 
                 query_name: str, 
                 prefix: str = "", 
                 include_date: bool = True) -> Path:
    """
    Export DataFrame to CSV with consistent naming
    
    Args:
        df: DataFrame to export
        output_dir: Directory to save CSV
        query_name: Name of the query used in filename
        prefix: Optional prefix for the filename
        include_date: Whether to include today's date in filename
        
    Returns:
        Path to the exported CSV file
    """
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Build filename
    if prefix:
        base_name = f"{prefix}_{query_name}"
    else:
        base_name = query_name
        
    if include_date:
        current_date = datetime.now().strftime("%Y%m%d")
        filename = f"{base_name}_{current_date}.csv"
    else:
        filename = f"{base_name}.csv"
    
    # Export path
    csv_path = output_dir / filename
    
    # Export to CSV
    df.to_csv(csv_path, index=False)
    logging.info(f"Exported {len(df)} rows to {csv_path}")
    
    return csv_path


def print_summary(query_results: Dict[str, Any], 
                 output_dir: Path, 
                 script_name: str) -> None:
    """
    Print a summary of query execution results
    
    Args:
        query_results: Dictionary of query results
        output_dir: Output directory where files were saved
        script_name: Name of the script for the header
    """
    total_queries = len(query_results)
    successful_queries = sum(1 for result in query_results.values() 
                             if result.get('status') == 'SUCCESS')
    failed_queries = total_queries - successful_queries
    total_rows = sum(result.get('rows', 0) for result in query_results.values())
    
    # Determine overall status
    if failed_queries == 0:
        overall_status = "SUCCESS"
    elif successful_queries == 0:
        overall_status = "FAILURE"
    else:
        overall_status = "PARTIAL FAILURE"
    
    # Print the summary
    print("\n" + "="*80)
    print(f"{script_name.upper()} EXPORT SUMMARY")
    print("="*80 + "\n")
    
    print("QUERY RESULTS:")
    print("-"*80)
    
    # Print details for each query
    for query_name, result in query_results.items():
        print(f"Query: {query_name}")
        print(f"  Status: {result.get('status', 'UNKNOWN')}")
        print(f"  Rows: {result.get('rows', 0)}")
        
        if result.get('output_file'):
            print(f"  Output: {result['output_file'].name}")
            print(f"  Full path: {result['output_file']}")
        
        print()
    
    print("-"*80)
    print(f"Total queries executed: {total_queries}")
    print(f"Total rows exported: {total_rows}")
    print(f"Overall status: {overall_status}")
    print(f"Output directory: {output_dir}")
    print("="*80) 