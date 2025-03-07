-- Description: This CTE extracts detailed carrier configuration data including address, phone, and electronic filing settings.
-- Date range: @start_date to @end_date
-- Dependent CTEs:

CarrierConfiguration AS (
    SELECT 
        c.CarrierNum,
        c.CarrierName,
        c.ElectID,
        c.TIN,
        c.Address,
        c.City,
        c.State,
        c.Zip,
        c.Phone,
        c.NoSendElect,
        c.TrustedEtransFlags,
        c.EraAutomationOverride,
        c.IsCoinsuranceInverted,
        c.CobInsPaidBehaviorOverride,
        c.OrthoInsPayConsolidate,
        c.CarrierGroupName,
        c.SecUserNumEntry,
        c.SecDateEntry,
        c.SecDateTEdit as LastModified,
        c.IsHidden
    FROM carrier c
)