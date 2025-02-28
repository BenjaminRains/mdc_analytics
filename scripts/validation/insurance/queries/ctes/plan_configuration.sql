-- Description: This CTE extracts detailed plan configuration data including fee schedules, filing codes, and special handling settings.
-- Date range: 2024-01-01 to 2025-01-01
-- Dependent CTEs:

PlanConfiguration AS (
    SELECT 
        i.PlanNum,
        i.CarrierNum,
        i.GroupName,
        i.GroupNum,
        i.PlanType,
        i.DivisionNo,
        i.FeeSched,
        i.CopayFeeSched,
        i.AllowedFeeSched,
        i.ManualFeeSchedNum,
        i.ClaimFormNum,
        i.UseAltCode,
        i.ClaimsUseUCR,
        i.FilingCode,
        i.FilingCodeSubtype,
        i.IsMedical,
        i.ShowBaseUnits,
        i.CodeSubstNone,
        i.IsBlueBookEnabled,
        i.CobRule,
        i.ExclusionFeeRule,
        i.HasPpoSubstWriteoffs,
        i.InsPlansZeroWriteOffsOnAnnualMaxOverride,
        i.InsPlansZeroWriteOffsOnFreqOrAgingOverride,
        i.PerVisitPatAmount,
        i.PerVisitInsAmount,
        i.OrthoType,
        i.OrthoAutoProcFreq,
        i.OrthoAutoFeeBilled,
        i.OrthoAutoClaimDaysWait,
        i.PlanNote,
        i.IsHidden,
        i.SecDateTEdit as LastModified
    FROM insplan i
)