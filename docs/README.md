# mdc_analytics 

## SmartTreatment model

### Predicting and Tracking Treatment Plan Acceptance (Including Partial Acceptance)

## Overview
This project proposes a systematic approach to predict whether a patient will fully accept, partially accept, or completely decline a recommended treatment plan at a dental clinic. Unlike simpler models focused on full acceptance or rejection, this proposal addresses the realistic scenario where patients often accept some procedures while declining others. By leveraging data from **OpenDental (MariaDB)** and **Practice by Numbers** KPI dashboards, the project aims to produce actionable insights that can help improve treatment acceptance rates—especially among new patients, where the need is most critical.

## Key Objectives
1. **Develop a Multi-Class Model**  
   - **Full Acceptance**: 100% of recommended procedures are accepted.  
   - **Partial Acceptance**: At least one procedure accepted, but not all.  
   - **No Acceptance**: All recommended procedures are declined.

2. **Deliver Actionable Insights**  
   - Identify drivers of acceptance and rejection.  
   - Tailor communication and financial strategies for at-risk or new patients.  
   - Guide staff in prioritizing follow-up efforts.

## Project Structure

project/
├── raw_data/                # Store raw data files here.
│   ├── patients.csv
│   ├── appointments.csv
│   ├── procedures.csv
├── scripts/                 # Store all SQL scripts here.
│   ├── create_temp_tables/  # Subfolder for temp table scripts.
│   │   ├── temp_patients.sql
│   │   ├── temp_appointments.sql
│   │   ├── temp_procedures.sql
│   ├── analysis_queries.sql # Scripts for analysis-specific queries.
├── processed_data/          # Exported processed data for analysis.
│   ├── temp_patients.csv
│   ├── temp_appointments.csv
├── notebooks/               # Jupyter notebooks for analysis.
│   ├── exploratory_analysis.ipynb
│   ├── modeling.ipynb
│   └── utils.py            # Shared helper functions
├── reports/
│   ├── figures/            # Visualizations, plots
│   └── model_results.md    # Performance metrics & error analysis
├── docs/                    # Documentation about the project.
│   ├── README.md
│   ├── data_dictionary.md
├── src/
│   ├── data_ingestion.py   # Scripts for extracting & merging data
│   ├── preprocessing.py    # Data cleaning & feature creation
│   ├── modeling.py         # Multi-class classifier implementation
│   └── utils.py            # Shared helper functions