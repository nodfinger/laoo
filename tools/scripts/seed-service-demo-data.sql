/* LAOO Service demo seed. Idempotent. Company 1 is the approved test company. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @CompanyID bigint = 1;
DECLARE @ResidentID bigint;
DECLARE @PersonID bigint;
DECLARE @RequesterUserID bigint;
DECLARE @StaffUserID bigint;
DECLARE @Location nvarchar(500);
DECLARE @Today date = CONVERT(date, SYSUTCDATETIME());
DECLARE @Suffix char(8) = CONVERT(char(8), @Today, 112);

SELECT TOP (1)
    @ResidentID = R.ResidentID,
    @PersonID = R.PersonID,
    @RequesterUserID = U.UserID
FROM dbo.TDADResident R
JOIN dbo.TDADUser U
  ON U.CompanyID = R.CompanyID AND U.PersonID = R.PersonID AND U.IsActive = 1
WHERE R.CompanyID = @CompanyID AND R.IsActive = 1
ORDER BY R.ResidentID;

SELECT TOP (1) @StaffUserID = U.UserID
FROM dbo.TDADEmployee E
JOIN dbo.TDADUser U
  ON U.CompanyID = E.CompanyID AND U.PersonID = E.PersonID AND U.IsActive = 1
WHERE E.CompanyID = @CompanyID AND E.IsActive = 1 AND E.IsServiceTechnician = 1
ORDER BY E.EmployeeID;

IF @ResidentID IS NULL OR @RequesterUserID IS NULL OR @StaffUserID IS NULL
    THROW 51001, 'Seed requires an active resident user and service technician user in Company 1.', 1;

SELECT TOP (1) @Location = LocationSnapshot
FROM dbo.TDADServiceRequest
WHERE CompanyID = @CompanyID AND ResidentID = @ResidentID AND IsActive = 1
ORDER BY RequestID DESC;
SET @Location = COALESCE(@Location, N'ข้อมูลสถานที่สำหรับทดสอบ');

;WITH DemoComplaint AS (
    SELECT N'CPTEST' + @Suffix + N'01' AS ComplaintNo, N'[TEST] แจ้งเรื่องร้องเรียนใหม่' AS Subject, N'ทดสอบการรับเรื่องร้องเรียนจากผู้พักอาศัย' AS Detail, N'NEW' AS StatusCode, CAST(NULL AS nvarchar(2000)) AS ResolutionDetail, CAST(NULL AS nvarchar(1000)) AS CancellationReason
    UNION ALL SELECT N'CPTEST' + @Suffix + N'02', N'[TEST] เรื่องร้องเรียนกำลังดำเนินการ', N'ทดสอบสถานะกำลังดำเนินการ', N'IN_PROGRESS', NULL, NULL
    UNION ALL SELECT N'CPTEST' + @Suffix + N'03', N'[TEST] เรื่องร้องเรียนปิดแล้ว', N'ทดสอบบันทึกผลและปิดเรื่องร้องเรียน', N'COMPLETED', N'ตรวจสอบและแก้ไขเรียบร้อยแล้ว', NULL
    UNION ALL SELECT N'CPTEST' + @Suffix + N'04', N'[TEST] เรื่องร้องเรียนยกเลิก', N'ทดสอบเหตุผลการยกเลิกเรื่องร้องเรียน', N'CANCELLED', NULL, N'ยกเลิกเพื่อทดสอบการแสดงผล'
)
INSERT dbo.TDADServiceComplaint
(
    CompanyID, ComplaintNo, ComplainantPersonID, ComplainantNameSnapshot,
    ComplainantPhoneSnapshot, ComplainantEmailSnapshot, LocationSnapshot,
    Subject, Detail, StatusCode, StartedDate, StartedBy, CompletedDate,
    CompletedBy, ResolutionDetail, CancelledDate, CancelledBy,
    CancellationReason, CreateBy, UpdateBy
)
SELECT
    @CompanyID, D.ComplaintNo, @PersonID, P.FullName, P.Mobile, P.Email,
    @Location, D.Subject, D.Detail, D.StatusCode,
    CASE WHEN D.StatusCode IN (N'IN_PROGRESS',N'COMPLETED') THEN DATEADD(day,-2,SYSUTCDATETIME()) END,
    CASE WHEN D.StatusCode IN (N'IN_PROGRESS',N'COMPLETED') THEN @StaffUserID END,
    CASE WHEN D.StatusCode = N'COMPLETED' THEN DATEADD(day,-1,SYSUTCDATETIME()) END,
    CASE WHEN D.StatusCode = N'COMPLETED' THEN @StaffUserID END,
    D.ResolutionDetail,
    CASE WHEN D.StatusCode = N'CANCELLED' THEN DATEADD(day,-1,SYSUTCDATETIME()) END,
    CASE WHEN D.StatusCode = N'CANCELLED' THEN @StaffUserID END,
    D.CancellationReason, @RequesterUserID, @RequesterUserID
FROM DemoComplaint D
JOIN dbo.TDADPerson P ON P.CompanyID=@CompanyID AND P.PersonID=@PersonID AND P.IsActive=1
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.TDADServiceComplaint C
    WHERE C.CompanyID=@CompanyID AND C.ComplaintNo=D.ComplaintNo
);

DECLARE @AssignmentID bigint;
DECLARE @ItemInstanceID bigint;
DECLARE @PlanName nvarchar(200);
DECLARE @ItemSnapshot nvarchar(500);
SELECT TOP (1)
    @AssignmentID=A.PmPlanAssignmentID,
    @ItemInstanceID=A.ItemInstanceID,
    @PlanName=P.PlanName,
    @ItemSnapshot=CONCAT(I.ItemCode,N' | ',I.ItemName)
FROM dbo.TDADServicePmPlanAssignment A
JOIN dbo.TDADServicePmPlan P ON P.PmPlanID=A.PmPlanID AND P.CompanyID=A.CompanyID
JOIN dbo.TDIVItemInstance X ON X.ItemInstanceID=A.ItemInstanceID AND X.CompanyID=A.CompanyID
JOIN dbo.TDIVItem I ON I.ItemID=X.ItemID AND I.CompanyID=X.CompanyID
WHERE A.CompanyID=@CompanyID AND A.IsActive=1
ORDER BY A.PmPlanAssignmentID;

IF @AssignmentID IS NOT NULL
BEGIN
    ;WITH DemoPm AS (
        SELECT DATEADD(day,-21,@Today) AS DueDate, N'COMPLETED' AS StatusCode, N'[TEST] ตรวจ PM เสร็จเรียบร้อย' AS ResultDetail, CAST(NULL AS nvarchar(1000)) AS SkipReason
        UNION ALL SELECT DATEADD(day,-14,@Today), N'IN_PROGRESS', NULL, NULL
        UNION ALL SELECT DATEADD(day,-7,@Today), N'SKIPPED', NULL, N'[TEST] เลื่อนงานเพื่อทดสอบสถานะข้าม'
    )
    INSERT dbo.TDADServicePmWorkOrder
    (
        CompanyID,PmPlanAssignmentID,ItemInstanceID,DueDate,StatusCode,
        PlanNameSnapshot,ItemSnapshot,LocationSnapshot,StartedDate,StartedBy,
        CompletedDate,CompletedBy,ResultDetail,SkipReason,CreateBy,UpdateBy
    )
    SELECT
        @CompanyID,@AssignmentID,@ItemInstanceID,D.DueDate,D.StatusCode,
        @PlanName,@ItemSnapshot,@Location,
        CASE WHEN D.StatusCode IN(N'IN_PROGRESS',N'COMPLETED') THEN DATEADD(day,-1,CONVERT(datetime2,D.DueDate)) END,
        CASE WHEN D.StatusCode IN(N'IN_PROGRESS',N'COMPLETED') THEN @StaffUserID END,
        CASE WHEN D.StatusCode=N'COMPLETED' THEN CONVERT(datetime2,D.DueDate) END,
        CASE WHEN D.StatusCode=N'COMPLETED' THEN @StaffUserID END,
        D.ResultDetail,D.SkipReason,@StaffUserID,@StaffUserID
    FROM DemoPm D
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.TDADServicePmWorkOrder W
        WHERE W.CompanyID=@CompanyID AND W.PmPlanAssignmentID=@AssignmentID AND W.DueDate=D.DueDate
    );

    INSERT dbo.TDADServicePmWorkOrderCheck
    (
        CompanyID,PmWorkOrderID,PmChecklistItemID,SequenceNo,CheckItemSnapshot,
        IsRequired,IsChecked,ResultNote
    )
    SELECT
        @CompanyID,W.PmWorkOrderID,CI.PmChecklistItemID,CI.SequenceNo,CI.CheckItem,
        CI.IsRequired,CASE WHEN W.StatusCode=N'COMPLETED' THEN 1 ELSE 0 END,
        CASE WHEN W.StatusCode=N'COMPLETED' THEN N'[TEST] ตรวจผ่าน' END
    FROM dbo.TDADServicePmWorkOrder W
    JOIN dbo.TDADServicePmPlanChecklist PC
      ON PC.CompanyID=@CompanyID
     AND PC.PmPlanID=(SELECT PmPlanID FROM dbo.TDADServicePmPlanAssignment WHERE PmPlanAssignmentID=@AssignmentID)
    JOIN dbo.TDADServicePmChecklistItem CI
      ON CI.CompanyID=PC.CompanyID AND CI.PmChecklistID=PC.PmChecklistID AND CI.IsActive=1
    WHERE W.CompanyID=@CompanyID AND W.PmPlanAssignmentID=@AssignmentID
      AND W.DueDate IN(DATEADD(day,-21,@Today),DATEADD(day,-14,@Today),DATEADD(day,-7,@Today))
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.TDADServicePmWorkOrderCheck C
          WHERE C.CompanyID=@CompanyID AND C.PmWorkOrderID=W.PmWorkOrderID AND C.PmChecklistItemID=CI.PmChecklistItemID
      );
END;

COMMIT TRANSACTION;