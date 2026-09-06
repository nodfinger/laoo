USE [DBTDMeeting];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

UPDATE G
SET G.IconName = V.IconName,
    G.UpdateDate = SYSDATETIME()
FROM dbo.TDADMenuGroup AS G
INNER JOIN (VALUES
    ('01', N'business_center'),
    ('02', N'manage_accounts'),
    ('03', N'extension'),
    ('04', N'fact_check'),
    ('05', N'settings_suggest'),
    ('06', N'domain'),
    ('07', N'groups'),
    ('10', N'verified_user'),
    ('11', N'verified_user'),
    ('12', N'verified_user'),
    ('13', N'event_available'),
    ('14', N'sensor_door'),
    ('15', N'settings_suggest'),
    ('16', N'analytics')
) AS V(MenuGroupCode, IconName)
    ON V.MenuGroupCode = RTRIM(G.MenuGroupCode)
WHERE ISNULL(G.IconName, N'') <> V.IconName;

UPDATE M
SET M.IconName = V.IconName,
    M.UpdateDate = SYSDATETIME()
FROM dbo.TDADMainMenu AS M
INNER JOIN (VALUES
    ('01001', N'handshake'),
    ('01002', N'domain'),
    ('01003', N'account_tree'),
    ('01004', N'terminal'),
    ('02001', N'support_agent'),
    ('02002', N'badge'),
    ('02003', N'groups'),
    ('03001', N'view_module'),
    ('03002', N'extension'),
    ('03003', N'shield'),
    ('04001', N'fact_check'),
    ('04002', N'login'),
    ('05001', N'tune'),
    ('05002', N'data_object'),
    ('06001', N'domain'),
    ('06002', N'account_tree'),
    ('07001', N'manage_accounts'),
    ('10001', N'badge'),
    ('10002', N'manage_accounts'),
    ('10003', N'groups_3'),
    ('10004', N'rule'),
    ('10005', N'account_tree'),
    ('10006', N'supervisor_account'),
    ('11001', N'badge'),
    ('11002', N'manage_accounts'),
    ('11003', N'groups_3'),
    ('11004', N'rule'),
    ('11005', N'account_tree'),
    ('12001', N'badge'),
    ('12002', N'support_agent'),
    ('12003', N'groups_3'),
    ('12004', N'rule'),
    ('12005', N'account_tree'),
    ('13001', N'event_available'),
    ('13002', N'calendar_month'),
    ('13003', N'mark_email_read'),
    ('13004', N'approval'),
    ('14001', N'how_to_reg'),
    ('14002', N'handyman'),
    ('14003', N'report_problem'),
    ('15001', N'apartment'),
    ('15002', N'meeting_room'),
    ('15003', N'devices_other'),
    ('15005', N'account_tree'),
    ('16001', N'analytics'),
    ('16002', N'person_off'),
    ('16003', N'reviews')
) AS V(MenuCode, IconName)
    ON V.MenuCode = RTRIM(M.MenuCode)
WHERE ISNULL(M.IconName, N'') <> V.IconName;

COMMIT TRANSACTION;
GO
