## SmartTreatment model

#### Predicting and Tracking Treatment Plan Acceptance (Including Partial Acceptance)

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

```plaintext
.
├── data/
│   ├── raw/                # Extracted tables from OpenDental & KPI data
│   ├── processed/          # Cleaned and merged datasets
│   └── README.md           # Notes on data ingestion
├── notebooks/
│   ├── EDA.ipynb           # Exploratory Data Analysis
│   ├── feature_engineering.ipynb
│   ├── modeling.ipynb      # Model training & validation
│   └── README.md
├── src/
│   ├── data_ingestion.py   # Scripts for extracting & merging data
│   ├── preprocessing.py    # Data cleaning & feature creation
│   ├── modeling.py         # Multi-class classifier implementation
│   └── utils.py            # Shared helper functions
├── reports/
│   ├── figures/            # Visualizations, plots
│   └── model_results.md    # Performance metrics & error analysis
├── README.md               # High-level project description
└── requirements.txt        # Dependencies (pandas, scikit-learn, etc.)

