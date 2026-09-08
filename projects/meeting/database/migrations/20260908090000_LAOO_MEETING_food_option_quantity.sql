IF COL_LENGTH(N'dbo.TDADMeetingBookingFoodOption', N'Quantity') IS NULL
BEGIN
    ALTER TABLE dbo.TDADMeetingBookingFoodOption
        ADD Quantity int NOT NULL
            CONSTRAINT DF_TDADMeetingBookingFoodOption_Quantity DEFAULT (1) WITH VALUES;
END;
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.TDADMeetingBookingFoodOption') AND name=N'CK_TDADMeetingBookingFoodOption_Quantity')
BEGIN
    ALTER TABLE dbo.TDADMeetingBookingFoodOption WITH CHECK
        ADD CONSTRAINT CK_TDADMeetingBookingFoodOption_Quantity CHECK (Quantity > 0);
END;
