# Transport ERP — System Architecture & Operational Master Guide

> **Enterprise Resource Planning & Warehouse Automation System**  
> **Business**: Arunachalam Transport Logistics  
> **Version**: 3.0.2 Live  

---

## 1. System Overview

Transport ERP is a high-velocity, modern logistics management system engineered for fleet management, consignment tracking (GC), daily warehouse inward operations, lorry hire accounting, and trip settlements.

### Core Business Modules:
1. **📦 Daily Warehouse Inward**: E-Way bill scanner/fetcher, box entry, godown allocation, and 1-click WhatsApp receipt dispatching.
2. **📄 Goods Consignment (GC) Entry**: Wholesale & Retail/B2C booking with contact phone tracking, E-Way Bill auto-filling, and fixed/rate-based freight calculations.
3. **🚛 Goods Delivery Memo (GDM)**: Vehicle loading allocation, memo generation, and CEWB (Consolidated E-Way Bill) integration.
4. **🛣️ Trip Settlement & Lorry Accounts**: Vehicle trip P&L, loading payer tracking, broker commissions, halts/deductions, and driver advances.
5. **🏢 Master Management**: Deduplicated Consignor, Consignee, Vehicle, Driver, and HSN master databases.

---

## 2. Technology Stack

* **Frontend**: React 18, Vite, Tailwind CSS, Lucide Icons, `react-window` (List Virtualization).
* **Backend**: Node.js, Express.js REST API.
* **Database & ORM**: Supabase PostgreSQL, Prisma ORM.
* **Mobile App**: React Native / Expo (`mobile/` directory) for Android APK generation.
* **External APIs**:
  * **WhiteBooks API**: E-Way Bill auto-fetch & generation (OAuth 2.0).
  * **ULIP / Vahan**: Vehicle RC verification.
  * **Driver DL**: Driver license validation.
  * **Fastag API**: Toll history and vehicle location tracking.
  * **WhatsApp API**: Instant receipt delivery via `wa.me` deep links and WhatsApp Business API.

---

## 3. Project Directory Structure

```
TRANSPORT ERP/
├── backend/
│   ├── prisma/
│   │   └── schema.prisma        # Database Models (GC, WarehouseInward, Trip, Consignor, etc.)
│   ├── routes/                  # Express REST API Routes
│   │   ├── warehouse.js         # Inward stock & receipt endpoints
│   │   ├── ewaybill.js          # WhiteBooks EWB integration
│   │   └── masters/             # Consignor, Consignee, Vehicle masters
│   └── server.js                # Main Backend Server Entry
├── frontend/
│   ├── src/
│   │   ├── pages/               # WarehouseEntry, NewGcEntry, TripSettlement, etc.
│   │   ├── components/          # Reusable UI components & form modules
│   │   └── api.js               # Central Axios/Fetch API client
├── mobile/                      # React Native Android Mobile App
│   ├── src/screens/             # Native Android WarehouseEntryScreen
│   └── src/utils/whatsapp.js    # Native Android WhatsApp Share Intent
├── boot.js                      # System Boot Runner (Backend + Frontend concurrent)
└── package.json                 # Root script definitions
```

---

## 4. One-Command System Boot

To start both the **Express Backend Server** and **Vite Frontend Dev Server** simultaneously, run:

```bash
npm run dev
```

* **Frontend**: `http://localhost:5173`
* **Backend API**: `http://localhost:5000/api`
* **Warehouse Entry**: `http://localhost:5173/warehouse-entry`

---

## 5. WhatsApp Receipt Delivery Flow

1. Staff saves a warehouse inward entry on Web or Android App.
2. The system formats a clean receipt summary with legal disclaimer:
   `⚠️ Note: Final confirmation subject to office verification.`
3. Clicking **WhatsApp Receipt** triggers native WhatsApp sharing with 1 tap.
4. Internal godown numbers are automatically excluded from customer receipts for operational privacy.

---

## 6. Deployment & Production

* **Web Deployment**: Pushed via Git to Vercel / Cloudflare Pages.
  ```bash
  git add .
  git commit -m "Production release"
  git push origin main
  ```
* **Android APK Build**:
  ```bash
  cd mobile
  npx eas build -p android --profile preview
  ```

---
*Documentation maintained by Antigravity AI Engine.*
