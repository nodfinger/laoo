SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

DECLARE @PaymentMethods TABLE
(
    Code nvarchar(20) NOT NULL,
    Name nvarchar(400) NOT NULL,
    Seq int NOT NULL
);

INSERT @PaymentMethods(Code, Name, Seq)
VALUES
    (N'00001', N'เงินสด', 1),
    (N'00002', N'โอนเงิน', 2),
    (N'00003', N'เช็ค', 3),
    (N'00004', N'บัตรเครดิต/เดบิต', 4);

UPDATE target
SET target.Name = source.Name,
    target.Seq = source.Seq
FROM dbo.TDSTMasterCont target
INNER JOIN @PaymentMethods source ON source.Code = target.Code
WHERE target.GroupCode = N'005';

INSERT dbo.TDSTMasterCont(GroupCode, Code, Name, Seq)
SELECT N'005', source.Code, source.Name, source.Seq
FROM @PaymentMethods source
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.TDSTMasterCont target
    WHERE target.GroupCode = N'005'
      AND target.Code = source.Code
);

COMMIT TRANSACTION;

SELECT GroupCode, Code, Name, Seq
FROM dbo.TDSTMasterCont
WHERE GroupCode = N'005'
ORDER BY Seq, Code;
