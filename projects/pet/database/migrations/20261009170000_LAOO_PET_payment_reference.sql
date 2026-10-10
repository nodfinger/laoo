SET NOCOUNT ON;
SET XACT_ABORT ON;
CREATE UNIQUE INDEX UX_TDPTEntitlement_ManualReference ON dbo.TDPTEntitlement(CompanyID,PaymentMethod,PaymentReference) WHERE PaymentReference IS NOT NULL;
GO
