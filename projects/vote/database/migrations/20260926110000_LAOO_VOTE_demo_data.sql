-- Demo data is intentionally scoped to one active company and can be rerun safely.
DECLARE @CompanyID bigint = (
    SELECT TOP (1) U.CompanyID
    FROM dbo.TDADUser U
    INNER JOIN dbo.TDADUserProject UP ON UP.CompanyID=U.CompanyID AND UP.UserID=U.UserID AND UP.IsActive=1
    INNER JOIN dbo.TDADProject P ON P.ProjectID=UP.ProjectID AND P.ProjectCode=N'LAOO_VOTE'
    WHERE U.IsActive=1
    ORDER BY U.IsCompanyAdmin DESC,U.UserID
);
DECLARE @UserID bigint = (SELECT TOP (1) UserID FROM dbo.TDADUser WHERE CompanyID=@CompanyID AND IsActive=1 ORDER BY IsCompanyAdmin DESC,UserID);

IF @CompanyID IS NOT NULL AND @UserID IS NOT NULL
BEGIN
    MERGE dbo.TDVTSetting AS T USING (SELECT @CompanyID CompanyID) S ON T.CompanyID=S.CompanyID
    WHEN NOT MATCHED THEN INSERT(CompanyID,IsEnabled,DefaultOpenHours,UpdateBy) VALUES(@CompanyID,1,72,@UserID);

    IF NOT EXISTS(SELECT 1 FROM dbo.TDVTTopic WHERE CompanyID=@CompanyID AND VoteNo=N'DEMO-VOTE-DRAFT')
        INSERT dbo.TDVTTopic(CompanyID,VoteNo,TopicName,Description,TargetMode,IdentityMode,StatusCode,OpenDateTime,CloseDateTime,CreateBy)
        VALUES(@CompanyID,N'DEMO-VOTE-DRAFT',N'ตัวอย่าง: เลือกกิจกรรมสัมพันธ์ประจำปี',N'หัวข้อร่างสำหรับทดลองแก้ไขและลบ',N'ALL',N'ANONYMOUS',N'DRAFT',DATEADD(day,1,SYSUTCDATETIME()),DATEADD(day,4,SYSUTCDATETIME()),@UserID);
    IF NOT EXISTS(SELECT 1 FROM dbo.TDVTTopic WHERE CompanyID=@CompanyID AND VoteNo=N'DEMO-VOTE-PENDING')
        INSERT dbo.TDVTTopic(CompanyID,VoteNo,TopicName,Description,TargetMode,IdentityMode,StatusCode,OpenDateTime,CloseDateTime,CreateBy,SubmitBy,SubmitDate)
        VALUES(@CompanyID,N'DEMO-VOTE-PENDING',N'ตัวอย่าง: เลือกวันจัดกิจกรรมบริษัท',N'รอผู้อนุมัติพิจารณา',N'ALL',N'OPEN',N'PENDING_APPROVAL',DATEADD(day,2,SYSUTCDATETIME()),DATEADD(day,5,SYSUTCDATETIME()),@UserID,@UserID,SYSUTCDATETIME());
    IF NOT EXISTS(SELECT 1 FROM dbo.TDVTTopic WHERE CompanyID=@CompanyID AND VoteNo=N'DEMO-VOTE-OPEN')
        INSERT dbo.TDVTTopic(CompanyID,VoteNo,TopicName,Description,TargetMode,IdentityMode,StatusCode,OpenDateTime,CloseDateTime,CreateBy,ApproveBy,ApproveDate,PublishBy,PublishDate)
        VALUES(@CompanyID,N'DEMO-VOTE-OPEN',N'ตัวอย่าง: เมนูอาหารกลางวัน',N'เปิดให้โหวตอยู่ในขณะนี้ เลือกได้ 1 รายการ',N'ALL',N'ANONYMOUS',N'PUBLISHED',DATEADD(hour,-1,SYSUTCDATETIME()),DATEADD(day,2,SYSUTCDATETIME()),@UserID,@UserID,DATEADD(hour,-2,SYSUTCDATETIME()),@UserID,DATEADD(hour,-1,SYSUTCDATETIME()));
    IF NOT EXISTS(SELECT 1 FROM dbo.TDVTTopic WHERE CompanyID=@CompanyID AND VoteNo=N'DEMO-VOTE-CLOSED')
        INSERT dbo.TDVTTopic(CompanyID,VoteNo,TopicName,Description,TargetMode,IdentityMode,StatusCode,OpenDateTime,CloseDateTime,CreateBy,ApproveBy,ApproveDate,PublishBy,PublishDate)
        VALUES(@CompanyID,N'DEMO-VOTE-CLOSED',N'ตัวอย่าง: รูปแบบการทำงานแบบยืดหยุ่น',N'หัวข้อปิดแล้วเพื่อแสดงสถิติและ Dashboard',N'ALL',N'ANONYMOUS',N'CLOSED',DATEADD(day,-8,SYSUTCDATETIME()),DATEADD(day,-1,SYSUTCDATETIME()),@UserID,@UserID,DATEADD(day,-9,SYSUTCDATETIME()),@UserID,DATEADD(day,-8,SYSUTCDATETIME()));

    DECLARE @TopicID bigint;
    DECLARE demo_topics CURSOR LOCAL FAST_FORWARD FOR SELECT VoteTopicID FROM dbo.TDVTTopic WHERE CompanyID=@CompanyID AND VoteNo IN(N'DEMO-VOTE-DRAFT',N'DEMO-VOTE-PENDING',N'DEMO-VOTE-OPEN',N'DEMO-VOTE-CLOSED');
    OPEN demo_topics; FETCH NEXT FROM demo_topics INTO @TopicID;
    WHILE @@FETCH_STATUS=0 BEGIN
      IF NOT EXISTS(SELECT 1 FROM dbo.TDVTTopicOption WHERE VoteTopicID=@TopicID)
        INSERT dbo.TDVTTopicOption(CompanyID,VoteTopicID,OptionText,SortOrder) VALUES(@CompanyID,@TopicID,N'ตัวเลือก A',1),(@CompanyID,@TopicID,N'ตัวเลือก B',2),(@CompanyID,@TopicID,N'ตัวเลือก C',3);
      FETCH NEXT FROM demo_topics INTO @TopicID;
    END
    CLOSE demo_topics; DEALLOCATE demo_topics;

    INSERT dbo.TDVTTopicVoter(CompanyID,VoteTopicID,UserID,EmployeeID)
    SELECT DISTINCT @CompanyID,T.VoteTopicID,U.UserID,UE.EmployeeID
    FROM dbo.TDVTTopic T JOIN dbo.TDADUser U ON U.CompanyID=@CompanyID AND U.IsActive=1
    LEFT JOIN dbo.TDADUserEmployee UE ON UE.CompanyID=U.CompanyID AND UE.UserID=U.UserID AND UE.IsActive=1
    WHERE T.CompanyID=@CompanyID AND T.VoteNo IN(N'DEMO-VOTE-OPEN',N'DEMO-VOTE-CLOSED')
      AND NOT EXISTS(SELECT 1 FROM dbo.TDVTTopicVoter V WHERE V.VoteTopicID=T.VoteTopicID AND V.UserID=U.UserID);

    INSERT dbo.TDVTVote(CompanyID,VoteTopicID,VoteTopicVoterID,VoteTopicOptionID,VoteDate)
    SELECT @CompanyID,T.VoteTopicID,V.VoteTopicVoterID,(SELECT TOP(1) O.VoteTopicOptionID FROM dbo.TDVTTopicOption O WHERE O.VoteTopicID=T.VoteTopicID ORDER BY O.SortOrder),DATEADD(day,-2,SYSUTCDATETIME())
    FROM dbo.TDVTTopic T JOIN dbo.TDVTTopicVoter V ON V.VoteTopicID=T.VoteTopicID
    WHERE T.CompanyID=@CompanyID AND T.VoteNo=N'DEMO-VOTE-CLOSED' AND NOT EXISTS(SELECT 1 FROM dbo.TDVTVote X WHERE X.VoteTopicVoterID=V.VoteTopicVoterID);
    UPDATE V SET VotedAt=DATEADD(day,-2,SYSUTCDATETIME()) FROM dbo.TDVTTopicVoter V JOIN dbo.TDVTTopic T ON T.VoteTopicID=V.VoteTopicID WHERE T.CompanyID=@CompanyID AND T.VoteNo=N'DEMO-VOTE-CLOSED' AND V.VotedAt IS NULL;
END
