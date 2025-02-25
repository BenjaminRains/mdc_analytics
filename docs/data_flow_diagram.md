%%{
  init: {
    'flowchart': {
      'diagramPadding': 50,
      'nodeSpacing': 50,
      'rankSpacing': 40,
      'curve': 'basis'
    },
    'themeVariables': {
      'fontSize': '16px',
      'fontFamily': 'Arial',
      'primaryColor': '#333333',
      'primaryTextColor': '#ffffff',
      'primaryBorderColor': '#000000',
      'lineColor': '#333333',
      'edgeLabelBackground': '#ffffff'
    }
  }
}%%
flowchart TB
%% Patient and Procedure
A[Patient] -->|Undergoes Procedure| B[ProcedureLog<br>ProcNum, ProcFee, ProcStatus]
%% Fee Processing & Verification
subgraph FeeProcessing["Fee Processing & Verification"]
B -->|"Initial Clinic Fee Set"| C[Clinic Fee Source<br>Standard Tiers]
C -->|"Verifies/Updates Fee"| B
B -->|"Lookup Fee Schedule"| D[Fee Schedule Check]
D -->|"No Schedule"| E[Fee Setting Decision]
D -->|"Has Schedule"| F[Contracted Rates]
F -->|"Updates Clinic Fee"| B
end
%% Insurance Processing
subgraph InsuranceProcessing["Insurance Processing"]
B -->|"Creates Claim"| I[Claim<br>ClaimNum, Status]
I -->|"Batch Rules"| BA[Batch Analysis<br>Size, Timing, Value]
BA -->|"Optimizes"| BS[Batch Submission<br>Max 4 Claims, Similar Values]
BS -->|"Generates ClaimProc"| J[ClaimProc<br>ProcNum, Status]
J -->|"For Insurance"| K[Insurance Carrier/Plan]
K -->|"Receives Estimation"| L[Insurance Estimation]
L -->|"Documents Payment"| M[Insurance Payment]
end
%% Payment Allocation & Reconciliation
subgraph PaymentAllocation["Payment Allocation & Reconciliation"]
M -->|"Insurance Payment"| P[Payment<br>PayNum, PayAmt, PayType, PayDate]
B -->|"Patient Payment"| P
P -->|"Creates"| PS[PaySplit<br>SplitNum, PayNum, SplitAmt, ProcNum]
PS -->|"Classifies"| ST[Split Types]
ST -->|"Regular (88.9%)"| T0[Type 0<br>Direct Application]
ST -->|"Prepayment (10.9%)"| T288[Type 288<br>Unearned Revenue]
ST -->|"TP Prepayment (0.2%)"| T439[Type 439<br>Treatment Plan Deposit]
PS -->|"Includes"| TR[Transfer Payments<br>Net $0, Offsetting Splits]
PS -->|"Split Pattern"| SP[Split Pattern Analysis]
SP -->|"Normal (99.3%)"| NS[Normal Splits<br>1-3 per payment]
SP -->|"Complex (0.7%)"| CS[Complex Splits<br>Max 2 claims/proc]
PS -->|"Validates"| VR[Validation Rules<br>Sum=PayAmt, Non-negative]
VR -->|"Date Validation"| TD[Transaction Date Check]
TD -->|"Before as_of_date"| AR[AR Analysis]
TD -->|"After as_of_date"| EX[Exclude from AR]
end
%% AR Analysis
subgraph ARAnalysis["AR Analysis"]
AR -->|"Age Classification"| AG[Aging Buckets]
AG -->|"Current (≤30d)<br>39.3%"| A1[Current AR]
AG -->|"30-60d<br>11.7%"| A2[30-60d AR]
AG -->|"60-90d<br>12.7%"| A3[60-90d AR]
AG -->|"90+d<br>36.2%"| A4[90+d AR]
end
%% Collection Flow
subgraph CollectionProcess["Collection Process"]
AR -->|"Collection Status"| CS[Collection Status]
CS -->|"Actions"| CA[Collection Actions]
CA -->|"Success"| COL[Collected]
CA -->|"Failure"| ESC[Escalation Options]
end
%% Success Criteria
COL -->|"Complete"| X[Journey Complete]
ESC -->|"Resolution"| X

%% Styling
classDef feeProcessingStyle fill:#f9f,stroke:#333,stroke-width:2px
classDef insuranceProcessingStyle fill:#bbf,stroke:#333,stroke-width:2px
classDef paymentAllocationStyle fill:#ff9,stroke:#333,stroke-width:2px
classDef arAnalysisStyle fill:#fef,stroke:#333,stroke-width:2px
classDef collectionProcessStyle fill:#dfd,stroke:#333,stroke-width:2px

class FeeProcessing feeProcessingStyle
class InsuranceProcessing insuranceProcessingStyle
class PaymentAllocation paymentAllocationStyle
class ARAnalysis arAnalysisStyle
class CollectionProcess collectionProcessStyle

