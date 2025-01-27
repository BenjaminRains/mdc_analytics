Overview
The MDC Project is designed to bridge operational (OLTP) and analytical (OLAP) data workflows for a dental practice using OpenDental. By maintaining two distinct databases, this project enables the efficient capture and transformation of data, ultimately empowering advanced analytics such as machine learning, dashboard reporting, and financial analysis.

Architecture
OLTP Database

Name: opendental
Purpose: Day-to-day operations of the dental practice (scheduling, patient records, real-time transaction logging).
Characteristics: Highly transactional, frequently updated during business hours.
OLAP Database

Name: mdc_analytics_opendentalbackup_01_03_2025
Purpose: Data warehousing and analytical queries (patient behavior modeling, resource management, financial reporting, etc.).
Characteristics: Heavily indexed to optimize read performance for various analytical workflows.
Data Pipeline Components
pipeline.py

Description: Extracts data from the OLTP database (opendental) and loads it into the OLAP database (mdc_analytics_opendentalbackup_01_03_2025).
Key Functions:
Connect to both databases.
Run extraction queries or procedures on the OLTP database.
Load and/or append data into the OLAP database tables for analytical use.
setup_indexes.py

Description: Creates and modifies indexes on the OLAP database tables to optimize query performance.
Key Functions:
Establish index strategies based on anticipated analytical queries.
Transform the raw schema into a more efficient design suitable for OLAP processes.
Other SQL Scripts

Description: Includes a variety of data transformation and aggregation scripts to generate feature-rich datasets.
Use Cases:
Machine Learning: Building training datasets for predictive models.
Dashboards/Reporting: Feeding aggregated metrics into Tableau or other BI tools.
Financial & Operational Analysis: Generating specialized reports on transactions, procedures, patient details, and more.
- Database access credentials
