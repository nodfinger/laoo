-- Keep the project code unchanged; update the Thai display name only.
UPDATE dbo.TDADProject
SET ProjectNameTH = N'ระบบนำทรัพย์สินออก'
WHERE ProjectCode = N'LAOO_GATE_PASS'
  AND ProjectNameTH = N'ระบบนำทรัพย์สินออกนอกพื้นที่';
