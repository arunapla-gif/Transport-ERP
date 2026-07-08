# Transport ERP - Future Enhancements Roadmap

This document serves as a permanent record of planned modules, architectural upgrades, and enhancements discussed for future implementation.

## 1. E-Way Bill Record Management (Command Center)
**Priority:** High
**Description:** Transitioning E-Way Bills from simple text fields to fully managed, lifecycle-tracked legal documents.
**Key Features:**
*   **Database Schema Upgrade:** Create an `EwayBillLog` table linking to GCs to track fetched, reassigned, Part-B updated, expired, and cancelled statuses.
*   **Expiry Tracking & Alerts:** Implement an automated background cron job to track `Valid Upto` timestamps and trigger alerts for EWBs expiring within 12 hours.
*   **Missing Part-B Tracking:** Identify and list active EWBs that have not yet been assigned to a physical vehicle.
*   **CEWB Generation Integration:** Bulk select active EWBs loaded onto a specific lorry to instantly generate a Consolidated E-Way Bill via the GST API.

## 2. Daily Accounts / Petty Cash (Daybook)
**Priority:** Medium
**Description:** A dedicated financial module to track day-to-day office and operational cash flows.
**Key Features:**
*   Logging routine office expenses, stationary, and tea expenses.
*   Tracking loading/unloading (coolie) charges not directly tied to a specific GC.
*   Managing diesel advances and miscellaneous branch expenses.

## 3. Consolidated Invoicing (Monthly Billing)
**Priority:** Medium
**Description:** Automated generation of formal monthly statements for corporate clients.
**Key Features:**
*   Ability to group multiple "To Pay" or "T.B.B" (To Be Billed) GCs into a single formal invoice.
*   Automated PDF generation and party ledger integration for bulk payments.

## 4. Role-Based Access Control (RBAC) & Staff Profiles
**Priority:** High
**Description:** Secure the ERP by restricting what different employees can see and do.
**Key Features:**
*   Create distinct roles (Admin, Branch Manager, Data Entry Operator).
*   Restrict specific actions (e.g., preventing operators from deleting financial records or modifying locked GCs).
*   Audit logging to track which user made specific entries or edits.
