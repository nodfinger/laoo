USE [DBTDMeeting];
GO

/* Latest reason entered while changing the booking status. */
IF COL_LENGTH(N'dbo.TDADMeetingRoomBooking', N'StatusRemark') IS NULL
BEGIN
    ALTER TABLE dbo.TDADMeetingRoomBooking
        ADD StatusRemark NVARCHAR(1000) NULL;
END;
GO

/* Backfill the latest known approval/status-history reason. */
UPDATE B
SET StatusRemark=COALESCE(H.Remark,A.Remark)
FROM dbo.TDADMeetingRoomBooking B
OUTER APPLY
(
    SELECT TOP 1 X.Remark
    FROM dbo.TDADMeetingRoomBookingStatusHistory X
    WHERE X.BookingID=B.BookingID AND X.CompanyID=B.CompanyID
      AND NULLIF(LTRIM(RTRIM(X.Remark)),N'') IS NOT NULL
    ORDER BY X.ChangedDate DESC,X.BookingStatusHistoryID DESC
) H
OUTER APPLY
(
    SELECT TOP 1 X.Remark
    FROM dbo.TDADMeetingRoomBookingApproval X
    WHERE X.BookingID=B.BookingID
      AND NULLIF(LTRIM(RTRIM(X.Remark)),N'') IS NOT NULL
    ORDER BY X.ActionDate DESC,X.BookingApprovalID DESC
) A
WHERE B.StatusRemark IS NULL
  AND COALESCE(H.Remark,A.Remark) IS NOT NULL;
GO
