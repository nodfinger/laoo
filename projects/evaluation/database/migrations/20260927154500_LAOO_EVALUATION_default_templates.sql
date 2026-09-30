SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @ProjectID bigint =
(
    SELECT ProjectID
    FROM dbo.TDADProject
    WHERE ProjectCode = N'LAOO_EVALUATION'
      AND IsActive = 1
);
IF @ProjectID IS NULL THROW 53117, N'Active LAOO_EVALUATION project is required.', 1;

DECLARE @Company TABLE (CompanyID bigint PRIMARY KEY);
INSERT @Company(CompanyID)
SELECT DISTINCT CP.CompanyID
FROM dbo.TDADCompanyProject CP
JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=CP.CompanyID AND C.IsActive=1
WHERE CP.ProjectID=@ProjectID
  AND CP.IsEnabled=1
  AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
  AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()));

DECLARE @Seed TABLE
(
    SourceType nvarchar(30) PRIMARY KEY,
    TemplateCode nvarchar(30) NOT NULL,
    TemplateName nvarchar(200) NOT NULL,
    Question1 nvarchar(2000) NOT NULL,
    Question2 nvarchar(2000) NOT NULL
);
INSERT @Seed VALUES
(N'TRAINING_COURSE',N'TRN-COURSE-DEFAULT',N'แบบประเมินหลักสูตรมาตรฐาน',N'เนื้อหาหลักสูตรตรงกับวัตถุประสงค์',N'สามารถนำความรู้ไปใช้ในการทำงานได้'),
(N'TRAINING_INSTRUCTOR',N'TRN-INSTRUCTOR-DEFAULT',N'แบบประเมินวิทยากรมาตรฐาน',N'วิทยากรถ่ายทอดเนื้อหาได้ชัดเจน',N'วิทยากรตอบคำถามและบริหารเวลาได้เหมาะสม'),
(N'MEETING_ROOM',N'MEETING-ROOM-DEFAULT',N'แบบประเมินห้องประชุมมาตรฐาน',N'ความพร้อมของห้องและอุปกรณ์',N'ความสะอาดและความเหมาะสมของห้อง'),
(N'VENDOR',N'VENDOR-DEFAULT',N'แบบประเมิน Vendor มาตรฐาน',N'คุณภาพสินค้าและบริการเป็นไปตามข้อตกลง',N'การส่งมอบและการประสานงานมีประสิทธิภาพ'),
(N'SERVICE',N'SERVICE-DEFAULT',N'แบบประเมินงานบริการมาตรฐาน',N'ความรวดเร็วในการให้บริการ',N'คุณภาพและความครบถ้วนของการแก้ไข'),
(N'GENERAL',N'GENERAL-DEFAULT',N'แบบประเมินทั่วไปมาตรฐาน',N'ความพึงพอใจโดยรวม',N'ผลลัพธ์เป็นไปตามความคาดหวัง');

INSERT dbo.TDEVTemplate(CompanyID,TemplateCode,TemplateName,SourceType,IsActive)
SELECT C.CompanyID,S.TemplateCode,S.TemplateName,S.SourceType,1
FROM @Company C
CROSS JOIN @Seed S
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDEVTemplate T
    WHERE T.CompanyID=C.CompanyID AND T.TemplateCode=S.TemplateCode
);

INSERT dbo.TDEVTemplateQuestion(EvaluationTemplateID,CompanyID,QuestionText,QuestionType,IsRequired,SortOrder)
SELECT T.EvaluationTemplateID,T.CompanyID,Q.QuestionText,Q.QuestionType,Q.IsRequired,Q.SortOrder
FROM dbo.TDEVTemplate T
JOIN @Company C ON C.CompanyID=T.CompanyID
JOIN @Seed S ON S.TemplateCode=T.TemplateCode AND S.SourceType=T.SourceType
CROSS APPLY
(
    VALUES
      (S.Question1,N'RATING_5',CONVERT(bit,1),1),
      (S.Question2,N'RATING_5',CONVERT(bit,1),2),
      (N'ความคิดเห็นเพิ่มเติม',N'TEXT',CONVERT(bit,0),3)
) Q(QuestionText,QuestionType,IsRequired,SortOrder)
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDEVTemplateQuestion X
    WHERE X.EvaluationTemplateID=T.EvaluationTemplateID AND X.SortOrder=Q.SortOrder
);

INSERT dbo.TDEVSystemSetting(CompanyID,SourceType,DefaultEvaluationTemplateID,IsActive)
SELECT C.CompanyID,S.SourceType,T.EvaluationTemplateID,1
FROM @Company C
CROSS JOIN @Seed S
JOIN dbo.TDEVTemplate T
  ON T.CompanyID=C.CompanyID
 AND T.TemplateCode=S.TemplateCode
 AND T.SourceType=S.SourceType
 AND T.IsActive=1
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDEVSystemSetting X
    WHERE X.CompanyID=C.CompanyID AND X.SourceType=S.SourceType
);

COMMIT TRANSACTION;
