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
    %% LEGEND - Add this at the bottom of your diagram
    subgraph Legend["Legend"]
        direction LR
        Process["Process"]:::processStyle
        DataStore[(Data Store)]
        Entity[External Entity]
        SystemA[Fee Processing]:::feeProcessingStyle
        SystemB[Insurance Processing]:::insuranceProcessingStyle
        SystemC[Payment Allocation]:::paymentAllocationStyle
        SystemD[AR Analysis]:::arAnalysisStyle
        SystemE[Collection Process]:::collectionProcessStyle
    end

    %% Patient and Procedure - Using proper shapes
    A[Patient]:::entityStyle -->|Patient Information| B["Record Procedure"]:::processStyle
    B -->|Procedure Data| ProcLog[(ProcedureLog<br>ProcNum, ProcFee, ProcStatus)]:::datastoreStyle
    
    %% Fee Processing & Verification
    subgraph FeeProcessing["Fee Processing & Verification"]
        ProcLog -->|Fee Request| C["Set Initial Clinic Fee"]:::processStyle
        C -->|Updated Fee| ProcLog
        ProcLog -->|Schedule Lookup| D["Check Fee Schedule"]:::processStyle
        D -->|No Schedule Found| E["Make Fee Decision"]:::processStyle
        D -->|Schedule Exists| F[(Contracted Rates)]:::datastoreStyle
        F -->|Schedule Rate| ProcLog
    end
    
    %% Insurance Processing
    subgraph InsuranceProcessing["Insurance Processing"]
        ProcLog -->|Procedure Details| I["Create Claim"]:::processStyle
        I -->|New Claim| ClaimStore[(Claim Records)]:::datastoreStyle
        ClaimStore -->|Claim Data| BA["Analyze Batch"]:::processStyle
        BA -->|Batch Criteria| BS["Submit Batch"]:::processStyle
        BS -->|Claim Submission| J["Generate ClaimProc"]:::processStyle
        J -->|ClaimProc Data| CP[(ClaimProc Records)]:::datastoreStyle
        CP -->|Carrier Request| K[Insurance Carrier/Plan]:::entityStyle
        K -->|Coverage Details| L["Estimate Insurance"]:::processStyle
        L -->|Payment Estimate| M["Document Payment"]:::processStyle
    end
    
    %% Payment Allocation & Reconciliation
    subgraph PaymentAllocation["Payment Allocation & Reconciliation"]
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
    end
    
    %% AR Analysis
    subgraph ARAnalysis["AR Analysis"]
        AR -->|Aging Data| AG["Categorize Aging"]:::processStyle
        AG -->|Current Bucket| A1[(Current AR)]:::datastoreStyle
        AG -->|30-60d Bucket| A2[(30-60d AR)]:::datastoreStyle
        AG -->|60-90d Bucket| A3[(60-90d AR)]:::datastoreStyle
        AG -->|90+d Bucket| A4[(90+d AR)]:::datastoreStyle
    end
    
    %% Collection Flow
    subgraph CollectionProcess["Collection Process"]
        AR -->|Receivables Data| CS["Check Collection Status"]:::processStyle
        CS -->|Required Actions| CA["Take Collection Actions"]:::processStyle
        CA -->|Success Path| COL["Record Collection"]:::processStyle
        CA -->|Failure Path| ESC["Escalate Options"]:::processStyle
    end
    
    %% Success Criteria
    COL -->|Completion Data| X["Close Journey"]:::processStyle
    ESC -->|Resolution Data| X

    %% Define styles for different node types
    classDef entityStyle stroke:#333,stroke-width:2px,fill:#fff,color:#000
    classDef datastoreStyle stroke:#333,stroke-width:2px,fill:#fff,color:#000,shape:cylinder
    classDef processStyle stroke:#333,stroke-width:2px,fill:#fff,color:#000,rx:10,ry:10
    
    %% Styling for systems/boundaries
    classDef feeProcessingStyle fill:#f9f,stroke:#333,stroke-width:2px
    classDef insuranceProcessingStyle fill:#bbf,stroke:#333,stroke-width:2px
    classDef paymentAllocationStyle fill:#ff9,stroke:#333,stroke-width:2px
    classDef arAnalysisStyle fill:#fef,stroke:#333,stroke-width:2px
    classDef collectionProcessStyle fill:#dfd,stroke:#333,stroke-width:2px

    %% Apply styles to elements
    class FeeProcessing feeProcessingStyle
    class InsuranceProcessing insuranceProcessingStyle
    class PaymentAllocation paymentAllocationStyle
    class ARAnalysis arAnalysisStyle
    class CollectionProcess collectionProcessStyle

