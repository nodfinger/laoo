IF COL_LENGTH(N'dbo.TDGPGatePassItem',N'ExpectedReturnDate') IS NULL
BEGIN
    ALTER TABLE dbo.TDGPGatePassItem ADD ExpectedReturnDate date NULL;
    EXEC(N'UPDATE i SET ExpectedReturnDate=CONVERT(date,g.ExpectedReturnDate) FROM dbo.TDGPGatePassItem i JOIN dbo.TDGPGatePass g ON g.GatePassID=i.GatePassID AND g.CompanyID=i.CompanyID WHERE i.IsReturnRequired=1 AND g.ExpectedReturnDate IS NOT NULL');
END;
