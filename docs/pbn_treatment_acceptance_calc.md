# Treatment Plan Acceptance Calculations

## Tx Plan Accepted %

### Overview

The Tx Plan Accepted % tracks the percentage of the dollar amount of treatment plan items that have been accepted (either completed or scheduled) out of the total dollar amount of all treatment plans presented to patients. This KPI is calculated individually for each provider, given that an exam was performed on the patient within 30 days of creating the treatment plan.

**Key Components:**
- **Accepted Treatment Plan Amount**: The total dollar amount of treatment plan items that have been accepted, whether they have been completed or scheduled.
- **Total Treatment Plan Amount**: The total dollar amount of all treatment plans presented to patients.

### Calculation

To calculate the Tx Plan Accepted %, follow these steps:

1. Determine the Accepted Treatment Plan Amount for a specific provider.
2. Determine the Total Treatment Plan Amount for the same provider.
3. Use the following formula:
```sql
Tx Plan Accepted % = (Accepted Treatment Plan Amount / Total Treatment Plan Amount) * 100
```

This metric helps to evaluate the efficacy and acceptance of proposed treatment plans by patients. A higher percentage indicates better acceptance and scheduling of treatments.

---

## Percentage of Patients that Accepted Treatment for All Exams Types

### Description

This KPI measures the percentage of patients who have accepted (either completed or scheduled) at least one item from their treatment plan after being presented with it. The calculation is specific to each provider. To appropriately allocate a treatment plan to a provider, the patient must have undergone an exam within the 30 days leading up to the creation of the treatment plan.

**Key Components:**
- **Exam Code**: The specific codes for the types of exams can be edited in the Settings - Service Code Sets page.
- **Timeline**: The exam must be performed within 30 days before the creation of the treatment plan.

### Calculation

To calculate the KPI:

1. Count the number of patients who have accepted (completed or scheduled) at least one item from their treatment plan.
2. Count the total number of patients who were presented with a treatment plan.
3. Calculate the percentage:
```sql
Percentage = (Number of Patients who Accepted Treatment / Total Number of Patients Presented a Treatment Plan) * 100
```

This KPI helps in understanding the effectiveness of treatment plan presentations and the acceptance rate per provider, allowing for targeted improvements and personalized strategies for patient engagement.

---

## Additional KPIs Related to Treatment Plans

### Total Tx Plan Presented

**Description**: The value of all treatment plans presented per provider within the specified time frame.

**Calculation**: Sum the value of all treatment plans presented per provider.

### Total Tx Plan Accepted

**Description**: The value of all treatment plans accepted (completed or scheduled) per provider within the specified time frame.

**Calculation**:
1. Identify treatment plans presented within the selected time range.
2. Filter to include only accepted treatment plans.
3. Sum the monetary value of accepted items per provider.

### Same Day Treatment

**Description**: The dollar amount of treatments completed on the same day the treatment plan was created.

**Calculation**: Sum the value of treatments finalized on the same day as the treatment plan creation.

---

## Report Visualizations

### Accepted Treatments by Service Type and Provider

#### Report Overview
This chart visualizes the distribution of accepted dental treatments by service type and provider. It provides actionable insights to enhance performance assessment and operational efficiency within a dental practice.

#### KPI Description
This chart provides insights into the distribution of accepted treatments by service type and provider, with production metrics categorized by service type and code.

**Chart Properties:**
- **Chart Type**: Pie or Bar Chart
- **Software**: Practice by Numbers
- **Category - Service Type**: Field used is `service_type` with value `production`
- **Category - Service Code**: Field used is `service_code` with value `production`

#### Purpose
This chart helps dental practices:
- Analyze the types of treatments being accepted by different providers
- Evaluate performance metrics for individual providers
- Optimize operational efficiency by identifying service patterns

### Service Types and Codes by Dental Providers

#### Report Overview
This report focuses on dental treatment types presented by providers, categorized by service type and service code. It offers valuable insights into the types of treatments presented within a dental practice.

#### KPI: TX Presented by Type & Provider

**Description**:
This chart provides insights into the types of treatments presented by each provider, categorized by:
1. **Service Type**: The category of service provided, identified by the field `service_type` and valued as `production`
2. **Service Code**: The specific code for the service provided, identified by the field `service_code` and valued as `production`

**Parameters:**
- **Provider**: Selected based on request
- **Exam Code Type**: Set to `all` to encompass all types of exam codes

**Display Information:**
- The chart is displayed with the name: **Presented**

#### Usage
This chart can be used to:
- Analyze the distribution of various treatment types presented by different providers
- Evaluate production and service patterns within the dental practice
- Identify trends and measure provider contributions 