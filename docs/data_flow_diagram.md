%%--------------------------------------------------------------------------
%% Mermaid Initialization & Theme
%%--------------------------------------------------------------------------
%%{
  init: {
    'flowchart': {
      'diagramPadding': 80,
      'nodeSpacing': 65,
      'rankSpacing': 50,
      'curve': 'basis'
    },
    'themeVariables': {
      'fontSize': '16px',
      'fontFamily': 'Arial',
      'primaryColor': '#333333',
      'primaryTextColor': '#ffffff',
      'primaryBorderColor': '#000000',
      'lineColor': '#333333',
      'edgeLabelBackground': '#ffffff',
      'tertiaryColor': '#fff'
    }
  }
}%%

flowchart TB

    %%--------------------------------------------------------------------------
    %% EXTERNAL ENTITY & PROCEDURE RECORDING
    %%--------------------------------------------------------------------------
    A[Patient]:::entityStyle -->|Patient Information| B["Record Procedure"]:::processStyle
    B -->|Procedure Data| ProcLog[(ProcedureLog<br>ProcNum, ProcFee, ProcStatus)]:::datastoreStyle

    %%--------------------------------------------------------------------------
    %% SYSTEM A: FEE PROCESSING & VERIFICATION
    %%--------------------------------------------------------------------------
    subgraph FeeProcessing["System A: Fee Processing & Verification"]
        ProcLog -->|Fee Request| C["Set Initial Clinic Fee"]:::processStyle
        C -->|Updated Fee| ProcLog
        ProcLog -->|Schedule Lookup| D["Check Fee Schedule"]:::processStyle
        D -->|No Schedule Found| E["Make Fee Decision"]:::processStyle
        D -->|Schedule Exists| F[(Contracted Rates)]:::datastoreStyle
        F -->|Schedule Rate| ProcLog
        
        %% Fee validation flow
        E -->|Fee Proposal| FV["Validate Fee"]:::processStyle
        FV -->|Invalid| E
        FV -->|Valid| ProcLog
    end

    %%--------------------------------------------------------------------------
    %% SYSTEM B: INSURANCE PROCESSING
    %%--------------------------------------------------------------------------
    subgraph InsuranceProcessing["System B: Insurance Processing"]
        ProcLog -->|Procedure Details| I["Create Claim"]:::processStyle
        I -->|New Claim| ClaimStore[(Claim Records)]:::datastoreStyle
        ClaimStore -->|Claim Data| BA["Analyze Batch"]:::processStyle
        BA -->|Batch Criteria| BS["Submit Batch"]:::processStyle
        BS -->|Claim Submission| J["Generate ClaimProc"]:::processStyle
        J -->|ClaimProc Data| CP[(ClaimProc Records)]:::datastoreStyle
        CP -->|Carrier Request| K[Insurance Carrier/Plan]:::entityStyle
        K -->|Coverage Details| L["Estimate Insurance"]:::processStyle
        L -->|Payment Estimate| M["Document Payment"]:::processStyle
        
        %% Add claim status tracking
        ClaimStore -->|Status Update| CST["Track Claim Status"]:::processStyle
        CST -->|Status History| ClaimStore
        
        %% Enhanced error handling
        BS -->|Rejection| RE["Handle Rejection"]:::processStyle
        RE -->|Resubmission| BS
        RE -->|Unable to Process| ErrorResolution["Error Resolution"]:::processStyle
        ErrorResolution -->|Manual Review| MR["Manual Resolution"]:::processStyle
        MR -->|Resolved| BS
        MR -->|Unresolvable| CT["Close & Tag"]:::processStyle
    end

    %%--------------------------------------------------------------------------
    %% SYSTEM C: PAYMENT ALLOCATION & RECONCILIATION
    %%--------------------------------------------------------------------------
    subgraph PaymentAllocation["System C: Payment Allocation & Reconciliation"]
        M -->|Insurance Payment| P[(Payment Records)]:::datastoreStyle
        ProcLog -->|Patient Payment| P
        P -->|Payment Details| PS["Create PaySplit"]:::processStyle
        PS -->|Split Data| PSStore[(PaySplit Records)]:::datastoreStyle
        
        PSStore -->|Classification| ST["Classify Split Type"]:::processStyle
        ST -->|Regular Split| T0["Direct Application"]:::processStyle
        ST -->|Prepayment| T288["Unearned Revenue"]:::processStyle
        ST -->|TP Prepayment| T439["Treatment Plan Deposit"]:::processStyle

        PSStore -->|Transfer Info| TR["Manage Transfers"]:::processStyle
        PSStore -->|Split Patterns| SP["Analyze Patterns"]:::processStyle
        SP -->|Normal Pattern| NS["Process Normal Splits"]:::processStyle
        SP -->|Complex Pattern| CS["Handle Complex Splits"]:::processStyle

        PSStore -->|Split Totals| VR["Validate Rules"]:::processStyle
        VR -->|Date Check| TD["Verify Transaction Date"]:::processStyle
        TD -->|Before as_of_date| AR["Process AR"]:::processStyle
        TD -->|After as_of_date| EX["Exclude from AR"]:::processStyle
        
        %% Bidirectional verification & payment history
        VR <-->|Validation Feedback| PSStore
        P -->|Payment History| AR

        %% Add reconciliation process
        PSStore -->|Daily Totals| RC["Reconcile Payments"]:::processStyle
        RC -->|Discrepancies| AL["Alert & Log"]:::processStyle
        RC -->|Balanced| PSStore
        
        %% Enhanced split validation
        VR -->|Invalid Split| RV["Review & Correct"]:::processStyle
        RV -->|Corrected| PSStore
    end

    %%--------------------------------------------------------------------------
    %% SYSTEM D: AR ANALYSIS
    %%--------------------------------------------------------------------------
    subgraph ARAnalysis["System D: AR Analysis"]
        AR -->|Aging Data| AG["Categorize Aging"]:::processStyle
        AG -->|Current Bucket| A1[(Current AR)]:::datastoreStyle
        AG -->|30-60d Bucket| A2[(30-60d AR)]:::datastoreStyle
        AG -->|60-90d Bucket| A3[(60-90d AR)]:::datastoreStyle
        AG -->|90+d Bucket| A4[(90+d AR)]:::datastoreStyle
        
        %% AR monitoring
        AG -->|Trends| ARM["Monitor AR Metrics"]:::processStyle
        ARM -->|Alerts| CS2
    end

    %%--------------------------------------------------------------------------
    %% SYSTEM E: COLLECTION PROCESS
    %%--------------------------------------------------------------------------
    subgraph CollectionProcess["System E: Collection Process"]
        AR -->|Receivables Data| CS2["Check Collection Status"]:::processStyle
        CS2 -->|Required Actions| CA["Take Collection Actions"]:::processStyle
        
        %% Enhanced collection paths
        CA -->|Initial Contact| IC["First Notice"]:::processStyle
        IC -->|No Response| SR["Second Notice"]:::processStyle
        SR -->|No Response| FR["Final Notice"]:::processStyle
        FR -->|No Response| ESC["Escalate Options"]:::processStyle
        
        %% Success paths
        IC -->|Payment Received| COL["Record Collection"]:::processStyle
        SR -->|Payment Received| COL
        FR -->|Payment Received| COL
        
        %% Payment plan option
        CA -->|Payment Plan Request| PP["Setup Payment Plan"]:::processStyle
        PP -->|Plan Active| COL
    end

    %%--------------------------------------------------------------------------
    %% SUCCESS CRITERIA
    %%--------------------------------------------------------------------------
    COL -->|Completion Data| X["Close Journey"]:::processStyle
    ESC -->|Resolution Data| X

    %%--------------------------------------------------------------------------
    %% LEGEND
    %%--------------------------------------------------------------------------
    subgraph Legend["Legend"]
        direction LR
        Process["Process"]:::processStyle
        DataStore[(Data Store)]:::datastoreStyle
        Entity[External Entity]:::entityStyle
        SystemA[Fee Processing]:::feeProcessingStyle
        SystemB[Insurance Processing]:::insuranceProcessingStyle
        SystemC[Payment Allocation]:::paymentAllocationStyle
        SystemD[AR Analysis]:::arAnalysisStyle
        SystemE[Collection Process]:::collectionProcessStyle
    end

    %%--------------------------------------------------------------------------
    %% CLASS DEFINITIONS
    %%--------------------------------------------------------------------------
    classDef entityStyle stroke:#333,stroke-width:2px,fill:#fff,color:#000
    classDef datastoreStyle stroke:#333,stroke-width:2px,fill:#fff,color:#000,shape:cylinder
    classDef processStyle stroke:#333,stroke-width:2px,fill:#fff,color:#000,rx:10,ry:10

    classDef feeProcessingStyle fill:#ffcccc,stroke:#333,stroke-width:2px
    classDef insuranceProcessingStyle fill:#cce5ff,stroke:#333,stroke-width:2px
    classDef paymentAllocationStyle fill:#fff2cc,stroke:#333,stroke-width:2px
    classDef arAnalysisStyle fill:#e6ccff,stroke:#333,stroke-width:2px
    classDef collectionProcessStyle fill:#ccffcc,stroke:#333,stroke-width:2px

    class FeeProcessing feeProcessingStyle
    class InsuranceProcessing insuranceProcessingStyle
    class PaymentAllocation paymentAllocationStyle
    class ARAnalysis arAnalysisStyle
    class CollectionProcess collectionProcessStyle

    %% Add new style for critical paths
    classDef criticalPath stroke:#ff0000,stroke-width:3px
    class FR,ESC criticalPath
