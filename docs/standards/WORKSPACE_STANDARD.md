# WORKSPACE_STANDARD.md

# Laoo Solutions Workspace Standard

Version: 1.0
Status: Core Standard

## Vision
Workspace เป็นศูนย์กลางการใช้งานของ Laoo Solutions ไม่ใช่เพียงเมนู

Simple Today. Ready Tomorrow.

## Core Principles
1. Authentication → Permission → Workspace
2. เมนูทั้งหมดมาจาก API
3. Flutter Render ตามข้อมูลจาก API
4. รองรับ Windows, Web, Android, iOS และจอสัมผัส

## Workspace
Support Workspace
- Partner
- Company
- Branch
- User
- Permission
- Project
- Audit
- System

Business Workspace
- Meeting
- SmartMarket
- POS
- Inventory
- CRM

## Layout Modes
- Classic
- Touch
- Favorite
- Card
- Tile
- Compact

## Favorite
เป็นแนวทางหลักของ Laoo Solutions
- ผู้ใช้เลือกเมนูเอง
- ปุ่มใหญ่สำหรับ Touch
- ใช้ Permission เดียวกับเมนูปกติ

## Device Profile
Desktop -> Classic
Tablet -> Touch
POS -> Favorite
Meeting -> Kiosk

## Dynamic Menu
Permission -> Menu API -> Workspace API -> Flutter Render

## Search
- Search Everywhere
- Recent
- Favorite

## Rule
ทุก Module ใหม่ต้องเชื่อมผ่าน Workspace และปฏิบัติตามมาตรฐานนี้
