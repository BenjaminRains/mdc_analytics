"""
OpenDental Base Index Configurations

This module defines comprehensive indexes supporting core operations:
1. Business operations
2. Analytics and reporting
3. Data integrity validation
4. Performance optimization

Note: ML-specific indexes are defined in treatment_journey_ml/ml_index_configs.py

Index Naming Convention:
- idx_[table]_[purpose]: Basic index pattern
- idx_[table]_[primary_column]_[supporting_columns]: For relationship indexes
- idx_[table]_[action]_[columns]: For specific query patterns
"""

BASE_INDEX_CONFIGURATIONS = {
    "patient_demographics": {
        "description": """
        Patient demographic indexes support:
        - Patient identification and lookup
        - Family relationships
        - Patient status tracking
        - Referral management
        - Emergency contact information
        """,
        "indexes": [
            # Core patient identification
            "CREATE INDEX idx_pat_core ON patient (PatNum, PatStatus, Guarantor)",
            "CREATE INDEX idx_pat_family ON patient (Guarantor, PatNum, PatStatus)",
            "CREATE INDEX idx_pat_referral ON patient (ReferredFrom, PatStatus)",
            "CREATE INDEX idx_pat_name_search ON patient (LName, FName, MiddleI)",
            "CREATE INDEX idx_pat_chart_number ON patient (ChartNumber, PatStatus)",
            
            # Patient relationships
            "CREATE INDEX idx_patientlink_from ON patientlink (PatNumFrom, LinkType, DateTimeLink)",
            "CREATE INDEX idx_patientlink_to ON patientlink (PatNumTo, LinkType, DateTimeLink)",
            "CREATE INDEX idx_patientlink_family ON patientlink (PatNumFrom, PatNumTo, LinkType)",
            
            # Patient notes and documentation
            "CREATE INDEX idx_patientnote_consent ON patientnote (PatNum, Consent, ICEName)",
            "CREATE INDEX idx_patientnote_dates ON patientnote (SecDateTEntry, SecDateTEdit)",
            "CREATE INDEX idx_patientnote_ortho ON patientnote (OrthoMonthsTreatOverride, DateOrthoPlacementOverride)",
            
            # Patient preferences and settings
            "CREATE INDEX idx_patpref_type ON patientpreference (PatNum, PrefType)",
            "CREATE INDEX idx_patpref_communication ON patientpreference (PatNum, CommPref, ContactMethod)"
        ]
    },

    "clinical_procedures": {
        "description": """
        Clinical procedure indexes support:
        - Procedure tracking and status
        - Provider attribution
        - Billing and insurance
        - Clinical notes and documentation
        - Treatment planning integration
        """,
        "indexes": [
            # Procedure tracking
            "CREATE INDEX idx_proc_core ON procedurelog (PatNum, ProcDate, ProcStatus)",
            "CREATE INDEX idx_proc_billing ON procedurelog (ProcNum, ProcFee, ProcStatus)",
            "CREATE INDEX idx_proc_provider ON procedurelog (ProvNum, ClinicNum, ProcStatus)",
            "CREATE INDEX idx_proc_appointment ON procedurelog (AptNum, ProcStatus, ProcDate)",
            "CREATE INDEX idx_proc_codes ON procedurelog (CodeNum, ProcStatus, ProcFee)",
            "CREATE INDEX idx_proc_treatment ON procedurelog (ToothNum, Surface, ProcStatus)",
            
            # Procedure notes
            "CREATE INDEX idx_procnote_tracking ON procnote (ProcNum, UserNum, EntryDateTime)",
            "CREATE INDEX idx_procnote_signature ON procnote (SigIsTopaz, UserNum, EntryDateTime)",
            "CREATE INDEX idx_procnote_audit ON procnote (SecDateTEntry, SecDateTEdit, UserNum)",
            
            # Clinical documentation
            "CREATE INDEX idx_proccode_category ON procedurecode (ProcCat, IsHygiene)",
            "CREATE INDEX idx_proccode_treatment ON procedurecode (TreatArea, IsProsth, IsMultiVisit)",
            "CREATE INDEX idx_proccode_billing ON procedurecode (ProcCode, NoBillIns, IsTaxed)"
        ]
    },

    "treatment_planning": {
        "description": """
        Treatment planning indexes support:
        - Plan creation and tracking
        - Procedure associations
        - Financial estimates
        - Signature tracking
        """,
        "indexes": [
            # Treatment plans
            "CREATE INDEX idx_treatplan_core ON treatplan (PatNum, DateTP, TPStatus)",
            "CREATE INDEX idx_treatplan_presenter ON treatplan (UserNumPresenter, TPType, DateTSigned)",
            "CREATE INDEX idx_treatplan_signature ON treatplan (DateTSigned, SignatureText, TPStatus)",
            
            # Treatment plan procedures
            "CREATE INDEX idx_proctp_plan ON proctp (TreatPlanNum, ItemOrder, Priority)",
            "CREATE INDEX idx_proctp_patient ON proctp (PatNum, ProcNumOrig, DateTP)",
            "CREATE INDEX idx_proctp_financial ON proctp (FeeAmt, PriInsAmt, SecInsAmt, PatAmt)"
        ]
    },

    "financial_transactions": {
        "description": """
        Financial transaction indexes support:
        - Payment tracking and reconciliation
        - Statement generation
        - Account balances
        - Billing operations
        """,
        "indexes": [
            # Payments and billing
            "CREATE INDEX idx_payment_core ON payment (PatNum, PayDate, PayAmt)",
            "CREATE INDEX idx_payment_tracking ON payment (PayType, PayNum, PayAmt)",
            
            # Statements
            "CREATE INDEX idx_statement_core ON statement (PatNum, DateSent, IsSent)",
            "CREATE INDEX idx_statement_type ON statement (StatementType, IsInvoice, IsReceipt)",
            "CREATE INDEX idx_statement_balance ON statement (BalTotal, InsEst, SmsSendStatus)",
            
            # Statement items
            "CREATE INDEX idx_statementprod_core ON statementprod (StatementNum, ProdType)",
            "CREATE INDEX idx_statementprod_docs ON statementprod (DocNum, FKey)"
        ]
    },

    "insurance_processing": {
        "description": """
        Insurance processing indexes support:
        - Claim tracking and status
        - Payment estimation
        - Benefit verification
        - Insurance plan management
        """,
        "indexes": [
            # Claims
            "CREATE INDEX idx_claim_core ON claim (PatNum, DateService, ClaimStatus)",
            "CREATE INDEX idx_claim_tracking ON claim (ClaimType, ClaimStatus, DateSent)",
            
            # Claim procedures
            "CREATE INDEX idx_claimproc_claim ON claimproc (ClaimNum, Status, InsPayAmt)",
            "CREATE INDEX idx_claimproc_estimate ON claimproc (ProcNum, AllowedAmt, WriteOff)",
            
            # Family aging
            "CREATE INDEX idx_famaging_core ON famaging (PatNum, BalTotal, InsEst)",
            "CREATE INDEX idx_famaging_aging ON famaging (Bal_0_30, Bal_31_60, Bal_61_90, BalOver90)"
        ]
    },

    "scheduling_management": {
        "description": """
        Scheduling indexes support:
        - Appointment management
        - Provider scheduling
        - Operatory allocation
        - Recall system
        """,
        "indexes": [
            # Appointments
            "CREATE INDEX idx_sched_core ON schedule (ProvNum, SchedDate, StartTime)",
            "CREATE INDEX idx_sched_operatory ON scheduleop (ScheduleNum, OperatoryNum)",
            
            # Recall system
            "CREATE INDEX idx_recall_core ON recall (PatNum, DateDue, RecallStatus)",
            "CREATE INDEX idx_recall_dates ON recall (DateDueCalc, DatePrevious, DateScheduled)",
            "CREATE INDEX idx_recall_type ON recall (RecallTypeNum, IsDisabled, Priority)",
            "CREATE INDEX idx_recalltype_config ON recalltype (DefaultInterval, TimePattern)",
            "CREATE INDEX idx_recalltrigger_type ON recalltrigger (RecallTypeNum, CodeNum)"
        ]
    },

    "clinical_exams": {
        "description": """
        Clinical exam indexes support:
        - Periodontal tracking
        - Exam documentation
        - Clinical measurements
        - Initial conditions
        """,
        "indexes": [
            # Periodontal exams
            "CREATE INDEX idx_perioexam_core ON perioexam (PatNum, ExamDate, ProvNum)",
            "CREATE INDEX idx_perioexam_notes ON perioexam (PerioExamNum, Note)",
            
            # Perio measurements
            "CREATE INDEX idx_periomeasure_exam ON periomeasure (PerioExamNum, SequenceType)",
            "CREATE INDEX idx_periomeasure_dates ON periomeasure (SecDateTEntry, SecDateTEdit)",
            
            # Initial tooth conditions
            "CREATE INDEX idx_toothinitial_core ON toothinitial (PatNum, ToothNum, InitialType)",
            "CREATE INDEX idx_toothinitial_tracking ON toothinitial (SecDateTEntry, SecDateTEdit)"
        ]
    },

    "documents_management": {
        "description": """
        Document management indexes support:
        - Sheet and form tracking
        - Document categorization
        - Signature management
        - OCR data indexing
        - External document linking
        """,
        "indexes": [
            # Sheet management
            "CREATE INDEX idx_sheet_patient ON sheet (PatNum, SheetType, DateTimeSheet)",
            "CREATE INDEX idx_sheet_type ON sheet (SheetType, IsWebForm, IsDeleted)",
            "CREATE INDEX idx_sheet_tracking ON sheet (SheetDefNum, DocNum, RevID)",
            
            # Sheet fields
            "CREATE INDEX idx_sheetfield_data ON sheetfield (SheetNum, FieldType, FieldName)",
            "CREATE INDEX idx_sheetfield_signature ON sheetfield (DateTimeSig, IsLocked, CanElectronicallySign)",
            
            # Sheet field definitions
            "CREATE INDEX idx_sheetfielddef_type ON sheetfielddef (SheetDefNum, FieldType, IsRequired)",
            "CREATE INDEX idx_sheetfielddef_layout ON sheetfielddef (LayoutMode, Language, IsLocked)",
            
            # Document management
            "CREATE INDEX idx_document_patient ON document (PatNum, DocCategory, DateCreated)",
            "CREATE INDEX idx_document_type ON document (ImgType, IsFlipped, PrintHeading)",
            "CREATE INDEX idx_document_external ON document (ExternalSource, ExternalGUID)",
            "CREATE INDEX idx_document_signature ON document (SigIsTopaz, ProvNum, DateCreated)",
            "CREATE INDEX idx_document_ocr ON document (DocCategory, OcrResponseData(50))"  # Partial index on OCR data
        ]
    },

    "patient_communication": {
        "description": """
        Communication indexes support:
        - Patient contact tracking
        - Communication preferences
        - Message history
        - Contact methods
        """,
        "indexes": [
            # Communication tracking
            "CREATE INDEX idx_commlog_patient_type ON commlog (PatNum, CommType, CommDateTime)",
            "CREATE INDEX idx_commlog_date ON commlog (CommDateTime, CommType)",
            
            # Patient relationships
            "CREATE INDEX idx_pat_referral_tracking ON patient (ReferredFrom, PatStatus)",
            
            # Patient notes and links
            "CREATE INDEX idx_patientnote_ice ON patientnote (PatNum, ICEName, ICEPhone)",
            "CREATE INDEX idx_patientlink_type ON patientlink (PatNumFrom, PatNumTo, LinkType)",
            "CREATE INDEX idx_patientlink_date ON patientlink (DateTimeLink, LinkType)"
        ]
    },

    "prescription_definitions": {
        "description": """
        Prescription indexes support:
        - Drug definitions
        - RxNorm integration
        - Prescription tracking
        - Pharmacy communication
        """,
        "indexes": [
            # Prescription definitions
            "CREATE INDEX idx_rxdef_drug ON rxdef (Drug, IsControlled)",
            "CREATE INDEX idx_rxdef_lookup ON rxdef (RxCui, IsProcRequired)",
            
            # RxNorm reference
            "CREATE INDEX idx_rxnorm_lookup ON rxnorm (RxCui, MmslCode)",
            "CREATE INDEX idx_rxnorm_search ON rxnorm (Description(50))",  # Partial index on Description
            
            # Patient prescriptions
            "CREATE INDEX idx_rxpat_patient ON rxpat (PatNum, RxDate, IsControlled)",
            "CREATE INDEX idx_rxpat_provider ON rxpat (ProvNum, SendStatus, RxType)",
            "CREATE INDEX idx_rxpat_pharmacy ON rxpat (PharmacyNum, ErxGuid, IsErxOld)",
            "CREATE INDEX idx_rxpat_tracking ON rxpat (RxDate, Drug, DaysOfSupply)"
        ]
    },

    "task_management": {
        "description": """
        Task management indexes support:
        - Task tracking and status
        - User assignments
        - Priority management
        - Reminder system
        """,
        "indexes": [
            # Task tracking
            "CREATE INDEX idx_task_status ON task (TaskStatus, IsRepeating, DateTask)",
            "CREATE INDEX idx_task_user ON task (UserNum, TaskListNum, PriorityDefNum)",
            "CREATE INDEX idx_task_reminder ON task (ReminderType, ReminderFrequency, DateTimeOriginal)",
            "CREATE INDEX idx_task_triage ON task (TriageCategory, TaskStatus, IsReadOnly)"
        ]
    },

    "system_configuration": {
        "description": """
        System configuration indexes support:
        - Definition management
        - Auto code configuration
        - System settings
        - Reference data
        """,
        "indexes": [
            # Definition management
            "CREATE INDEX idx_definition_category ON definition (Category, ItemOrder)",
            "CREATE INDEX idx_definition_lookup ON definition (ItemName, IsHidden)",
            "CREATE INDEX idx_definition_value ON definition (Category, ItemValue, IsHidden)",
            
            # Auto code configuration
            "CREATE INDEX idx_autocode_status ON autocode (IsHidden, LessIntrusive)",
            "CREATE INDEX idx_autocode_lookup ON autocode (Description, IsHidden)"
        ]
    },

    "location_management": {
        "description": """
        Location management indexes support:
        - Clinic settings
        - Address validation
        - Geographic lookups
        - Regional configuration
        """,
        "indexes": [
            # Zip code lookups
            "CREATE INDEX idx_zipcode_lookup ON zipcode (ZipCodeDigits, City, State)",
            "CREATE INDEX idx_zipcode_frequent ON zipcode (IsFrequent, State, City)",
            
            # Clinic configuration
            "CREATE INDEX idx_clinic_status ON clinic (ClinicNum, IsHidden)",
            "CREATE INDEX idx_clinic_region ON clinic (Region, PlaceService)",
            
            # Provider locations
            "CREATE INDEX idx_provlocation_schedule ON providerlocations (ProvNum, ClinicNum, DayOfWeek)",
            "CREATE INDEX idx_provlocation_status ON providerlocations (IsAvailable, StartTime, EndTime)"
        ]
    },

    "referral_details": {
        "description": """
        Referral management indexes support:
        - Provider referrals
        - Referral tracking
        - Specialty management
        - Contact information
        """,
        "indexes": [
            # Referral tracking
            "CREATE INDEX idx_referral_provider ON referral (LName, FName, IsDoctor)",
            "CREATE INDEX idx_referral_status ON referral (IsHidden, IsPreferred, Specialty)",
            "CREATE INDEX idx_referral_contact ON referral (Telephone, EMail, NationalProvID)",
            
            # Referral attachments
            "CREATE INDEX idx_refattach_status ON refattach (RefType, RefToStatus, IsTransitionOfCare)",
            "CREATE INDEX idx_refattach_dates ON refattach (RefDate, DateProcComplete)",
            "CREATE INDEX idx_refattach_patient ON refattach (PatNum, ReferralNum, ProcNum)"
        ]
    }
}

# Flatten configurations into list format for IndexManager compatibility
BASE_INDEXES = [
    index 
    for category in BASE_INDEX_CONFIGURATIONS.values() 
    for index in category["indexes"]
]

# Documentation for specific indexes
INDEX_DOCUMENTATION = {
    "idx_pat_core": "Primary patient lookup index for core operations",
    "idx_pat_family": "Supports family relationship queries and guarantor lookups",
    "idx_proc_core": "Primary procedure tracking and patient history index",
    "idx_treatplan_core": "Primary treatment plan lookup and status tracking",
    "idx_document_patient": "Patient document management and categorization",
    "idx_task_status": "Task tracking and management operations",
    "idx_clinic_status": "Clinic configuration and status management",
    "idx_referral_provider": "Provider referral tracking and management"
} 