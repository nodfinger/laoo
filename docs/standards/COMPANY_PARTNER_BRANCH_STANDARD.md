# COMPANY_PARTNER_BRANCH_STANDARD

Version: 1.0  
Last Update: 2026-08-05  
Owner: CI / CA / SA / DBA  
Status: Active

---

# Purpose

เอกสารนี้กำหนดโครงสร้างมาตรฐานสำหรับการจัดการ Partner, Company และ Branch ภายใต้ Laoo Solutions เพื่อให้ทุก Project ใช้โครงสร้างเดียวกัน รองรับลูกค้าที่มีหลายสาขา และไม่เพิ่มความซับซ้อนเกินความจำเป็นใน Version 1

---

# Core Principle

```text
Partner
   └── ดูแลหลาย Company

Company
   └── มีหลาย Branch
```

รหัสหลักที่ใช้ร่วมกันทุก Project คือ

```text
PartnerCode
CompanyCode
BranchCode
```

Version 1 ไม่ใช้ `TenantCode`

---

# Definitions

## PartnerCode

`PartnerCode` หมายถึงผู้ขาย ผู้ติดตั้ง ผู้ให้บริการ หรือผู้ดูแลระบบให้กับลูกค้า

Partner หนึ่งรายสามารถดูแลหลาย Company ได้ แต่ Partner ไม่ใช่เจ้าของข้อมูลธุรกิจของ Company และห้ามใช้ PartnerCode แทน CompanyCode ในข้อมูลธุรกิจ

## CompanyCode

`CompanyCode` หมายถึงลูกค้าหนึ่งรายหรือบริษัทหนึ่งแห่งที่ใช้ระบบ

Company เป็นขอบเขตหลักของข้อมูลธุรกิจ เช่น ผู้ใช้งาน สินค้า เอกสาร การขาย การซื้อ สิทธิ์ การตั้งค่า รายงาน Subscription และ Branding

CompanyCode ต้องมาจาก User Profile, Domain Mapping, Token หรือ Server Configuration ห้ามให้ผู้ใช้กรอกเองในหน้าจอทำงานทั่วไป

## BranchCode

`BranchCode` หมายถึงสาขาภายใน Company

Company หนึ่งแห่งสามารถมีหลาย Branch ได้ โดยใช้แยกข้อมูลระดับสาขา เช่น Stock, POS, ห้องประชุม, ยอดขาย, พนักงานประจำสาขา และอุปกรณ์ประจำสาขา

---

# Relationship Model

## Partner to Company

Partner หนึ่งรายดูแลได้หลาย Company

Company สามารถเปลี่ยน Partner ได้โดยไม่กระทบข้อมูลธุรกิจเดิม

ให้เก็บความสัมพันธ์ใน Table กลาง เช่น

```text
PartnerCompany
```

Column แนะนำ

```text
PartnerCode
CompanyCode
StartDate
EndDate
Status
CanSupport
CanConfigure
CanProvision
CanViewBilling
CreatedAt
CreatedBy
UpdatedAt
UpdatedBy
```

## Company to Branch

Company หนึ่งแห่งมีได้หลาย Branch

Branch ต้องอยู่ภายใต้ Company เสมอ

Key ที่แนะนำ

```text
CompanyCode + BranchCode
```

---

# Data Ownership

เจ้าของข้อมูลธุรกิจคือ Company

Partner เป็นผู้ดูแลตามสิทธิ์ที่ได้รับ

ข้อมูลธุรกิจหลักควรใช้

```text
CompanyCode
```

เป็นขอบเขตหลัก

ข้อมูลระดับสาขาใช้

```text
CompanyCode + BranchCode
```

PartnerCode ไม่ควรอยู่ในทุก Transaction Table แต่ควรอยู่เฉพาะ Table ที่เกี่ยวกับความสัมพันธ์ Partner, สิทธิ์ Support, Billing, Commission และ Audit

---

# Recommended Tables

## Partner

```text
PartnerCode
PartnerName
PartnerType
ContactName
Phone
Email
Status
CreatedAt
CreatedBy
UpdatedAt
UpdatedBy
```

## Company

```text
CompanyCode
CompanyName
DisplayName
TaxId
Address
Phone
Email
Domain
LogoPath
ThemeCode
DatabaseMode
ConnectionKey
Status
CreatedAt
CreatedBy
UpdatedAt
UpdatedBy
```

## Branch

```text
CompanyCode
BranchCode
BranchName
Address
Phone
Email
TimeZone
IsHeadOffice
Status
CreatedAt
CreatedBy
UpdatedAt
UpdatedBy
```

## PartnerCompany

```text
PartnerCode
CompanyCode
StartDate
EndDate
Status
CanSupport
CanConfigure
CanProvision
CanViewBilling
CreatedAt
CreatedBy
UpdatedAt
UpdatedBy
```

## CompanyProduct

ใช้กำหนดว่า Company เปิดใช้งาน Project หรือ Product ใดบ้าง

```text
CompanyCode
ProductCode
StartDate
EndDate
LicenseType
Status
CreatedAt
CreatedBy
UpdatedAt
UpdatedBy
```

ตัวอย่าง ProductCode

```text
laoo
laoo_meeting
laoo_market
laoo_pos
laoo_hr
```

---

# Domain and Deployment

Company แต่ละรายสามารถใช้ Domain ของตนเองได้ เช่น

```text
www.customera.com
www.customerb.com
```

ระบบต้องมี Mapping ระหว่าง Domain และ CompanyCode

```text
www.customera.com -> CompanyCode = CUSTOMER_A
www.customerb.com -> CompanyCode = CUSTOMER_B
```

ห้ามรับ CompanyCode จาก Query String แล้วเชื่อทันที Server ต้องตรวจสอบ Domain, Session หรือ Token ก่อนกำหนด CompanyCode

---

# Database Modes

## Shared Database

หลาย Company ใช้ Database ร่วมกัน

ทุก Table ธุรกิจต้องมี

```text
CompanyCode
```

ข้อมูลระดับสาขาต้องมี

```text
CompanyCode
BranchCode
```

ทุก Query ต้องกรอง CompanyCode

## Dedicated Database

Company ใช้ Database ของตนเอง

Database Schema, Source Code, API Contract และ Feature Structure ต้องเหมือนกับ Shared Database

ความแตกต่างอยู่ที่ Connection Configuration เท่านั้น

---

# Security Rules

1. CompanyCode ต้องมาจาก User Profile, Domain Mapping, Token หรือ Server Configuration
2. ห้ามให้ Client ส่ง CompanyCode แล้ว Server เชื่อโดยไม่ตรวจสอบ
3. ทุก Query ที่เป็นข้อมูลธุรกิจต้องกรอง CompanyCode
4. ข้อมูลระดับสาขาต้องตรวจ CompanyCode และ BranchCode
5. Partner ต้องเห็นเฉพาะ Company ที่อยู่ใน PartnerCompany
6. Partner ต้องไม่เปิดข้อมูลธุรกิจของ Company โดยอัตโนมัติ
7. สิทธิ์ Support ต้องกำหนดเป็นราย Company
8. การเข้าถึงของ Partner ต้องมี Audit Log
9. การเปลี่ยน Partner ต้องไม่แก้ข้อมูลธุรกิจย้อนหลัง
10. Unique Key ของข้อมูลธุรกิจควรรวม CompanyCode เมื่อมีโอกาสซ้ำข้าม Company

ตัวอย่าง

```text
CompanyCode + UserName
CompanyCode + ProductCode
CompanyCode + DocumentNo
CompanyCode + BranchCode + StockLocationCode
```

---

# Application Rules

ทุก Project ภายใต้ Laoo Solutions ต้องใช้คำจำกัดความเดียวกัน

```text
PartnerCode = ผู้ขายหรือผู้ดูแลระบบ
CompanyCode = ลูกค้าหนึ่งรายหรือบริษัทที่ใช้ระบบ
BranchCode  = สาขาภายใน Company
```

ห้ามให้แต่ละ Project ตีความรหัสเหล่านี้ต่างกัน

---

# Version 1 Scope

Version 1 ใช้

```text
PartnerCode
CompanyCode
BranchCode
```

ไม่ใช้

```text
TenantCode
```

ไม่สร้าง Group Company เพิ่มจนกว่าจะมี Requirement จริง

หากในอนาคตลูกค้าหนึ่งรายมีหลายบริษัท ให้สร้าง CompanyCode แยกแต่ละบริษัท และค่อยพิจารณา GroupCode ภายหลัง

---

# Example

```text
PartnerCode = PT001
CompanyCode = ABC
BranchCode  = BKK01
```

ความหมาย

- Partner `PT001` เป็นผู้ดูแลบริษัท `ABC`
- บริษัท `ABC` เป็นลูกค้าของระบบ
- `BKK01` เป็นสาขาหนึ่งของบริษัท `ABC`

ถ้าบริษัท `ABC` เปลี่ยนไปใช้ Partner `PT002` ให้แก้เฉพาะความสัมพันธ์ใน `PartnerCompany`

ข้อมูลเดิม เช่น User, Product, Order, Stock และ Meeting ต้องไม่เปลี่ยน CompanyCode

---

# Naming Standard

ใช้ชื่อ Column ดังนี้

```text
PartnerCode
CompanyCode
BranchCode
```

ไม่ใช้ชื่อที่มีความหมายซ้ำ เช่น

```text
CustomerCode
TenantCode
ClientCode
OrganizationCode
```

เว้นแต่ได้รับอนุมัติให้เพิ่มในอนาคต

---

# Final Decision

> Laoo Solutions ใช้ Company เป็นตัวแทนลูกค้าหนึ่งราย  
> Company สามารถมีหลาย Branch  
> Partner เป็นผู้ดูแล Company ผ่านความสัมพันธ์แยก  
> Version 1 ไม่ใช้ TenantCode

เอกสารนี้เป็นมาตรฐานกลางและต้องใช้ร่วมกันทุก Project
