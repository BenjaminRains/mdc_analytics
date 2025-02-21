import pandas as pd
import os
from datetime import datetime
import logging
from src.connections.factory import ConnectionFactory
import argparse
from scripts.base.index_manager import IndexManager
from pathlib import Path

def setup_logging(log_dir='validation/logs'):
    """Setup logging configuration"""
    # Ensure log directory exists
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)
    
    # Create log filename with timestamp
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    log_file = os.path.join(log_dir, f'payment_validation_{timestamp}.log')
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()  # Also print to console
        ]
    )
    
    logging.info("Starting payment validation export")
    logging.info(f"Log file: {log_file}")
    return log_file

def ensure_directory_exists(directory):
    """Create directory if it doesn't exist"""
    if not os.path.exists(directory):
        os.makedirs(directory)
        logging.info(f"Created directory: {directory}")

def get_ctes():
    """Return the common CTEs used by multiple queries"""
    return """
    WITH PaymentSummary AS (
        SELECT 
            p.PayNum,
            p.PayAmt,
            p.PayDate,
            p.PayType,
            p.PayNote,
            COUNT(ps.SplitNum) AS split_count,
            SUM(ps.SplitAmt) AS total_split_amount,
            ABS(p.PayAmt - SUM(ps.SplitAmt)) AS split_difference,
            CASE WHEN p.PayAmt < 0 THEN 1 ELSE 0 END AS is_reversal
        FROM payment p
        LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
        WHERE p.PayDate >= '2024-01-01'
          AND p.PayDate < '2025-01-01'
        GROUP BY p.PayNum, p.PayAmt, p.PayDate, p.PayType, p.PayNote
    ),
    PaymentMethodAnalysis AS (
        SELECT 
            p.PayType,
            COUNT(*) AS payment_count,
            SUM(p.PayAmt) AS total_amount,
            COUNT(CASE WHEN p.PayAmt < 0 THEN 1 END) AS reversal_count,
            AVG(CASE WHEN ps.split_difference > 0.01 THEN 1 ELSE 0 END) AS error_rate
        FROM payment p
        JOIN PaymentSummary ps ON p.PayNum = ps.PayNum
        WHERE p.PayDate >= '2024-01-01'
          AND p.PayDate < '2025-01-01'
        GROUP BY p.PayType
    ),
    InsurancePaymentAnalysis AS (
        SELECT 
            CASE 
                WHEN cp.InsPayAmt IS NOT NULL THEN 'Insurance'
                ELSE 'Patient'
            END AS payment_source,
            COUNT(DISTINCT ps.PayNum) AS payment_count,
            SUM(ps.SplitAmt) AS total_paid,
            AVG(DATEDIFF(p.PayDate, pl.ProcDate)) AS avg_days_to_payment
        FROM paysplit ps
        JOIN payment p ON ps.PayNum = p.PayNum
        JOIN procedurelog pl ON ps.ProcNum = pl.ProcNum
        LEFT JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
        WHERE p.PayDate >= '2024-01-01'
          AND p.PayDate < '2025-01-01'
        GROUP BY 
            CASE 
                WHEN cp.InsPayAmt IS NOT NULL THEN 'Insurance'
                ELSE 'Patient'
            END
    ),
    ProcedurePayments AS (
        SELECT 
            pl.ProcNum,
            pl.ProcFee,
            pl.ProcStatus,
            pl.CodeNum,
            ps.PayNum,
            ps.SplitAmt,
            p.PayAmt,
            p.PayDate,
            ps.UnearnedType,
            DATEDIFF(p.PayDate, pl.ProcDate) AS days_to_payment,
            ROW_NUMBER() OVER (PARTITION BY pl.ProcNum ORDER BY p.PayDate) AS payment_sequence
        FROM procedurelog pl
        JOIN paysplit ps ON pl.ProcNum = ps.ProcNum
        JOIN payment p ON ps.PayNum = p.PayNum
        WHERE p.PayDate >= '2024-01-01'
          AND p.PayDate < '2025-01-01'
    ),
    SplitPatternAnalysis AS (
        SELECT 
            ProcNum,
            COUNT(DISTINCT PayNum) AS payment_count,
            COUNT(*) AS split_count,
            SUM(SplitAmt) AS total_paid,
            AVG(days_to_payment) AS avg_days_to_payment,
            GROUP_CONCAT(payment_sequence ORDER BY payment_sequence) AS payment_sequence_pattern,
            CASE 
                WHEN COUNT(*) BETWEEN 1 AND 3 THEN 'normal_split'
                WHEN COUNT(*) BETWEEN 4 AND 15 THEN 'complex_split'
                WHEN COUNT(*) > 15 THEN 'review_needed'
                ELSE 'no_splits'
            END AS split_pattern
        FROM ProcedurePayments
        GROUP BY ProcNum
    ),
    PaymentBaseCounts AS (
        SELECT 
            'base_counts' as metric,
            COUNT(DISTINCT p.PayNum) as total_payments,
            MIN(p.PayDate) as min_date,
            MAX(p.PayDate) as max_date
        FROM payment p
        WHERE p.PayDate >= '2024-01-01'
            AND p.PayDate < '2025-01-01'
    ),
    PaymentJoinDiagnostics AS (
        SELECT 
            p.PayNum,
            p.PayDate,
            p.PayAmt,
            p.PayType,
            CASE 
                WHEN ps.PayNum IS NULL THEN 'No Splits'
                WHEN cp.ProcNum IS NULL THEN 'No Procedures'
                WHEN cp.InsPayAmt IS NULL THEN 'No Insurance'
                ELSE 'Complete'
            END as join_status,
            COUNT(DISTINCT ps.SplitNum) as split_count,
            COUNT(DISTINCT cp.ProcNum) as proc_count
        FROM payment p
        LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
        LEFT JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
        WHERE p.PayDate >= '2024-01-01'
            AND p.PayDate < '2025-01-01'
        GROUP BY 
            p.PayNum,
            p.PayDate,
            p.PayAmt,
            p.PayType,
            CASE 
                WHEN ps.PayNum IS NULL THEN 'No Splits'
                WHEN cp.ProcNum IS NULL THEN 'No Procedures'
                WHEN cp.InsPayAmt IS NULL THEN 'No Insurance'
                ELSE 'Complete'
            END
    ),
    PaymentFilterDiagnostics AS (
        SELECT 
            pd.PayNum,
            pd.PayAmt,
            pd.join_status,
            pd.split_count,
            pd.proc_count,
            CASE
                WHEN pd.PayAmt = 0 THEN 'Zero Amount'
                WHEN pd.split_count > 15 THEN 'High Split Count'
                WHEN pd.PayAmt < 0 THEN 'Reversal'
                WHEN pd.join_status != 'Complete' THEN pd.join_status
                ELSE 'Normal Payment'
            END as filter_reason
        FROM PaymentJoinDiagnostics pd
    )"""

def export_validation_results(cursor, queries=None, output_dir=None):
    """
    Export payment validation query results to separate CSV files
    
    Args:
        cursor: Database cursor object
        queries: List of query names to run (None for all)
        output_dir: Directory to store output files (None for default)
    """
    # Set default output directory if none provided
    if output_dir is None:
        output_dir = r"C:\Users\rains\mdc_analytics\scripts\validation\data"
    
    logging.info(f"Starting export to {output_dir}")
    ensure_directory_exists(output_dir)
    
    # Common CTEs used by multiple queries
    logging.info("Loading CTEs")
    ctes = get_ctes()
    
    # Define queries and their output files
    exports = [
        {
            'name': 'summary',
            'query': f"""{ctes} 
                SELECT 
                    'summary' AS report_type,
                    pb.total_payments AS base_payment_count,
                    COUNT(DISTINCT pfd.PayNum) AS filtered_payment_count,
                    AVG(pfd.split_count) AS avg_splits_per_payment,
                    SUM(CASE WHEN pfd.filter_reason != 'Normal Payment' THEN 1 ELSE 0 END) AS problem_payment_count
                FROM PaymentFilterDiagnostics pfd
                CROSS JOIN PaymentBaseCounts pb
                GROUP BY pb.total_payments
                
                UNION ALL
                
                SELECT 
                    'problem_detail' AS report_type,
                    pfd.PayNum,
                    pfd.PayAmt,
                    pfd.filter_reason,
                    pfd.split_count
                FROM PaymentFilterDiagnostics pfd
                WHERE pfd.filter_reason != 'Normal Payment'
                ORDER BY report_type DESC""",
            'file': 'payment_split_validation_2024_summary.csv'
        },
        {
            'name': 'base_counts',
            'query': f"""{ctes}
                SELECT 
                    'Payment Counts' as metric,
                    COUNT(DISTINCT p.PayNum) as total_payments,
                    COUNT(DISTINCT ps.SplitNum) as total_splits,
                    COUNT(DISTINCT ps.ProcNum) as total_procedures,
                    CAST(COUNT(DISTINCT ps.SplitNum) AS FLOAT) / 
                        NULLIF(COUNT(DISTINCT p.PayNum), 0) as avg_splits_per_payment
                FROM payment p
                LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
                WHERE p.PayDate >= '2024-01-01'
                    AND p.PayDate < '2025-01-01'""",
            'file': 'payment_split_validation_2024_base_counts.csv'
        },
        {
            'name': 'source_counts',
            'query': f"""{ctes} 
                SELECT 
                    CASE 
                        WHEN cp.InsPayAmt IS NOT NULL THEN 'Insurance'
                        ELSE 'Patient'
                    END AS metric,
                    COUNT(DISTINCT ps.PayNum) as total_payments,
                    COUNT(DISTINCT ps.SplitNum) as total_splits,
                    COUNT(DISTINCT ps.ProcNum) as total_procedures,
                    CAST(COUNT(DISTINCT ps.SplitNum) AS FLOAT) / 
                        NULLIF(COUNT(DISTINCT ps.PayNum), 0) as avg_splits_per_payment
                FROM paysplit ps
                JOIN payment p ON ps.PayNum = p.PayNum
                LEFT JOIN claimproc cp ON ps.ProcNum = cp.ProcNum
                WHERE p.PayDate >= '2024-01-01'
                    AND p.PayDate < '2025-01-01'
                GROUP BY 
                    CASE 
                        WHEN cp.InsPayAmt IS NOT NULL THEN 'Insurance'
                        ELSE 'Patient'
                    END""",
            'file': 'payment_split_validation_2024_source_counts.csv'
        },
        {
            'name': 'filter_summary',
            'query': f"{ctes} SELECT 'filter_summary' as report_type, filter_reason, COUNT(*) as payment_count, SUM(PayAmt) as total_amount FROM PaymentFilterDiagnostics GROUP BY filter_reason ORDER BY payment_count DESC",
            'file': 'payment_split_validation_2024_filter_summary.csv'
        },
        {
            'name': 'diagnostic',
            'query': f"{ctes} SELECT 'diagnostic_summary' as report_type, filter_reason, COUNT(*) as payment_count, SUM(PayAmt) as total_amount, AVG(split_count) as avg_splits, MIN(PayAmt) as min_amount, MAX(PayAmt) as max_amount FROM PaymentFilterDiagnostics GROUP BY filter_reason ORDER BY payment_count DESC",
            'file': 'payment_split_validation_2024_diagnostic.csv'
        },
        {
            'name': 'verification',
            'query': f"{ctes} SELECT 'verification_counts' as report_type, 'Total Base Payments' as metric, total_payments as payment_count, min_date, max_date FROM PaymentBaseCounts UNION ALL SELECT 'verification_counts' as report_type, join_status as metric, COUNT(*) as payment_count, MIN(PayDate) as min_date, MAX(PayDate) as max_date FROM PaymentJoinDiagnostics GROUP BY join_status",
            'file': 'payment_split_validation_2024_verification.csv'
        },
        {
            'name': 'problems',
            'query': f"{ctes} SELECT 'problem_details' as report_type, pd.* FROM PaymentFilterDiagnostics pd WHERE filter_reason != 'Normal Payment' ORDER BY PayAmt DESC LIMIT 100",
            'file': 'payment_split_validation_2024_problems.csv'
        },
        {
            'name': 'duplicate_joins',
            'query': f"""
                WITH ProcedureClaims AS (
                    -- First get claim counts per procedure
                    SELECT 
                        ProcNum,
                        COUNT(DISTINCT ClaimNum) as claim_count
                    FROM claimproc
                    WHERE Status IN (1, 4, 5)
                        AND InsPayAmt > 0
                    GROUP BY ProcNum
                ),
                PaymentJoins AS (
                    SELECT 
                        p.PayNum,
                        p.PayAmt,
                        p.PayDate,
                        p.PayType,
                        ps.SplitNum,
                        ps.SplitAmt,
                        cp.ClaimNum,
                        cp.ClaimProcNum,
                        ps.ProcNum,
                        cp.InsPayAmt,
                        cp.Status,
                        cp.ProcNum as ClaimProcProcNum,
                        pl.PatNum,
                        c.PatNum as ClaimPatNum,
                        pc.claim_count as claims_per_proc
                    FROM payment p
                    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
                    LEFT JOIN procedurelog pl ON ps.ProcNum = pl.ProcNum
                    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum
                        AND cp.Status IN (1, 4, 5)
                        AND cp.InsPayAmt > 0
                    LEFT JOIN claim c ON cp.ClaimNum = c.ClaimNum
                        AND pl.PatNum = c.PatNum
                    LEFT JOIN ProcedureClaims pc ON ps.ProcNum = pc.ProcNum
                    WHERE p.PayDate >= '2024-01-01' 
                        AND p.PayDate < '2025-01-01'
                        AND p.PayAmt != 0
                )
                SELECT 
                    PayNum,
                    PayAmt,
                    PayDate,
                    PayType,
                    COUNT(*) as join_count,
                    COUNT(DISTINCT SplitNum) as split_count,
                    COUNT(DISTINCT ClaimProcNum) as claimproc_count,
                    COUNT(DISTINCT ClaimNum) as unique_claims,
                    COUNT(DISTINCT ProcNum) as unique_procs,
                    COUNT(DISTINCT PatNum) as unique_patients,
                    MAX(claims_per_proc) as max_claims_per_proc,
                    GROUP_CONCAT(DISTINCT ClaimNum) as claim_nums,
                    GROUP_CONCAT(DISTINCT CONCAT(
                        ProcNum, ':', 
                        COALESCE(claims_per_proc, 0)
                    ) ORDER BY claims_per_proc DESC) as proc_claim_counts,
                    GROUP_CONCAT(DISTINCT CONCAT(
                        SplitNum, ':', 
                        COALESCE(SplitAmt, 0), ':', 
                        COALESCE(ClaimNum, 'NULL'), ':',
                        COALESCE(InsPayAmt, 0)
                    ) ORDER BY SplitNum) as split_details
                FROM PaymentJoins
                GROUP BY PayNum, PayAmt, PayDate, PayType
                HAVING COUNT(*) > COUNT(DISTINCT SplitNum)
                    AND COUNT(DISTINCT ClaimProcNum) > COUNT(DISTINCT SplitNum)
                ORDER BY join_count DESC""",
            'file': 'payment_split_validation_2024_duplicate_joins.csv'
        },
        {
            'name': 'join_stages',
            'query': f"""
                {ctes}
                SELECT 
                    (SELECT COUNT(DISTINCT PayNum) 
                     FROM payment 
                     WHERE PayDate >= '2024-01-01' AND PayDate < '2025-01-01'
                    ) as base_count,
                    
                    (SELECT COUNT(DISTINCT p.PayNum)
                     FROM payment p
                     LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
                     WHERE p.PayDate >= '2024-01-01' AND p.PayDate < '2025-01-01'
                    ) as paysplit_count,
                    
                    (SELECT COUNT(DISTINCT p.PayNum)
                     FROM payment p
                     LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
                     LEFT JOIN procedurelog pl ON ps.ProcNum = pl.ProcNum
                     LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum
                         AND cp.Status IN (1, 4, 5)
                         AND cp.InsPayAmt > 0
                     WHERE p.PayDate >= '2024-01-01' AND p.PayDate < '2025-01-01'
                    ) as claimproc_count,
                    
                    (SELECT COUNT(DISTINCT PayNum) 
                     FROM payment 
                     WHERE PayDate >= '2024-01-01' AND PayDate < '2025-01-01'
                    ) - 
                    (SELECT COUNT(DISTINCT p.PayNum)
                     FROM payment p
                     LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
                     LEFT JOIN procedurelog pl ON ps.ProcNum = pl.ProcNum
                     LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum
                         AND cp.Status IN (1, 4, 5)
                         AND cp.InsPayAmt > 0
                     WHERE p.PayDate >= '2024-01-01' AND p.PayDate < '2025-01-01'
                    ) as missing_payments""",
            'file': 'payment_split_validation_2024_join_stages.csv'
        }
    ]
    
    # Filter exports if specific queries requested
    if queries:
        exports = [e for e in exports if e['name'] in queries]
        logging.info(f"Running selected queries: {', '.join(queries)}")
    
    # Execute each query and export results
    for export in exports:
        try:
            logging.info(f"Processing export: {export['name']}")
            start_time = datetime.now()
            
            # Execute query and fetch results
            cursor.execute(export['query'])
            results = cursor.fetchall()
            
            # Convert to DataFrame
            df = pd.DataFrame(results)
            
            # Write to CSV, mode='w' ensures overwrite
            output_path = os.path.join(output_dir, export['file'])
            if os.path.exists(output_path):
                logging.info(f"Overwriting existing file: {export['file']}")
            df.to_csv(output_path, index=False, mode='w')
            
            duration = (datetime.now() - start_time).total_seconds()
            logging.info(f"Exported {len(df):,} rows to {export['file']} in {duration:.2f} seconds")
            
        except Exception as e:
            logging.error(f"Error exporting {export['name']}: {str(e)}", exc_info=True)

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description='Export payment validation data to CSV files',
        formatter_class=argparse.RawTextHelpFormatter
    )
    
    parser.add_argument(
        '--output-dir',
        default=r"C:\Users\rains\mdc_analytics\scripts\validation\data",
        help='Directory to store output files'
    )
    
    parser.add_argument(
        '--log-dir',
        default='validation/logs',
        help='Directory to store log files'
    )
    
    parser.add_argument(
        '--database',
        default='opendental_analytics_opendentalbackup_01_03_2025',
        help='Database name to connect to'
    )
    
    parser.add_argument(
        '--queries',
        nargs='+',
        choices=['duplicate_joins', 'join_stages'],
        help='Specific queries to run (default: all)'
    )
    
    return parser.parse_args()

def ensure_indexes(connection, database_name):
    """Ensure required indexes exist for validation queries"""
    logging.info("Checking and creating required payment validation indexes...")
    
    REQUIRED_INDEXES = [
        # Payment Analysis - core indexes for payment date filtering and joins
        "CREATE INDEX IF NOT EXISTS idx_ml_payment_core ON payment (PayNum, PayDate)",
        "CREATE INDEX IF NOT EXISTS idx_ml_payment_window ON payment (PayDate)",
        
        # Payment Split Analysis - for payment-split relationships
        "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_payment ON paysplit (ProcNum, PayNum, SplitAmt)",
        "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_proc_pay ON paysplit (ProcNum, PayNum, SplitAmt)",
        
        # Insurance Processing - for insurance payment identification
        "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_core ON claimproc (ProcNum, InsPayAmt, InsPayEst, Status, ClaimNum)"
    ]
    
    try:
        manager = IndexManager(database_name)  # Pass database name instead of connection
        
        # Show existing indexes before creation
        logging.info("Current payment-related indexes:")
        manager.show_custom_indexes()
        
        # Create only the required indexes
        logging.info("Creating required payment validation indexes...")
        manager.create_indexes(REQUIRED_INDEXES)
        
        # Verify indexes after creation
        logging.info("Verifying indexes after creation:")
        manager.show_custom_indexes()
        
        logging.info("Payment validation index creation complete")
        
    except Exception as e:
        logging.error(f"Error managing payment validation indexes: {str(e)}")
        raise

if __name__ == "__main__":
    try:
        # Parse command line arguments
        args = parse_args()
        
        # Setup logging first
        log_file = setup_logging(args.log_dir)
        
        # Log the arguments
        logging.info(f"Output directory: {args.output_dir}")
        logging.info(f"Database: {args.database}")
        if args.queries:
            logging.info(f"Running queries: {', '.join(args.queries)}")
        
        # Create database connection using factory
        factory = ConnectionFactory()
        connection = factory.create_connection(
            connection_type='local_mariadb',
            database=args.database,
            use_root=True
        )
        
        # Create required indexes first
        with connection.connect() as conn:
            ensure_indexes(conn, args.database)
        
        # Now execute the exports with a fresh connection
        with connection.connect() as conn:
            cursor = conn.cursor(dictionary=True)
            export_validation_results(cursor, args.queries, args.output_dir)
            
    except Exception as e:
        logging.error("Fatal error in main execution", exc_info=True)
        raise 