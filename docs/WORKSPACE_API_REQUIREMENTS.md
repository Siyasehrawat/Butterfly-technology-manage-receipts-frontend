# Workspace API Requirements Document

**Version:** 1.0  
**Date:** December 3, 2025  
**Status:** Required for Mobile App  

---

## Overview

This document outlines the backend API endpoints required to complete the Workspace (TeamHub) feature in the Manage Receipt mobile application.

**Base URL:** `https://manage-receipt-backend-dev.onrender.com/api`

---

## Table of Contents

1. [User Dashboard APIs](#1-user-dashboard-apis)
2. [Manager Dashboard APIs](#2-manager-dashboard-apis)
3. [Expense Reports APIs](#3-expense-reports-apis)
4. [User Workspace Receipts APIs](#4-user-workspace-receipts-apis)
5. [Needs/Resource Requests APIs](#5-needsresource-requests-apis)
6. [Owner Pending Approvals API](#6-owner-pending-approvals-api)
7. [Activity Feed API](#7-activity-feed-api)

---

## 1. User Dashboard APIs

### 1.1 Get User Dashboard Summary

Returns dashboard metrics for a workspace member (user role).

**Endpoint:**
```
GET /workspace/:workspaceId/user-dashboard
```

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| userId | string | Yes | The user's ID |

**Example Request:**
```
GET /workspace/ws-123/user-dashboard?userId=user-456
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "summary": {
      "pendingExpenses": 3,
      "approvedExpenses": 12,
      "thisMonthSpend": 8540.00,
      "totalSpend": 45230.00
    },
    "recentSubmissions": [
      {
        "id": "receipt-uuid",
        "title": "Office Supplies",
        "category": "Office Expenses",
        "amount": 1250.00,
        "status": "approved",
        "date": "2025-11-20"
      },
      {
        "id": "receipt-uuid-2",
        "title": "Team Lunch",
        "category": "Business Meals",
        "amount": 2800.00,
        "status": "pending",
        "date": "2025-11-19"
      }
    ]
  }
}
```

**Error Response (404):**
```json
{
  "success": false,
  "error": "User not found in workspace"
}
```

---

## 2. Manager Dashboard APIs

### 2.1 Get Manager Dashboard Summary

Returns dashboard metrics for a workspace manager.

**Endpoint:**
```
GET /workspace/:workspaceId/manager-dashboard
```

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| userId | string | Yes | The manager's user ID |

**Example Request:**
```
GET /workspace/ws-123/manager-dashboard?userId=manager-456
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "summary": {
      "pendingApprovals": 5,
      "monthlySpend": 12450.00,
      "teamMembersCount": 8,
      "needsRequestsCount": 2
    },
    "recentActivity": [
      {
        "type": "expense_submitted",
        "title": "Expense Submitted",
        "description": "Office Supplies - ₹2,500 by John Doe",
        "timestamp": "2025-12-01T10:00:00Z",
        "userId": "user-uuid",
        "userName": "John Doe"
      },
      {
        "type": "member_joined",
        "title": "New Member",
        "description": "Sarah joined the workspace",
        "timestamp": "2025-12-01T09:00:00Z",
        "userId": "user-uuid-2",
        "userName": "Sarah Smith"
      }
    ]
  }
}
```

---

## 3. Expense Reports APIs

### 3.1 Create Expense Report

Creates a new expense report with selected receipts.

**Endpoint:**
```
POST /workspace/:workspaceId/expense-reports
```

**Request Body:**
```json
{
  "userId": "user-uuid",
  "title": "Monthly Expenses - November",
  "description": "All business expenses for November 2025",
  "receiptIds": [
    "receipt-uuid-1",
    "receipt-uuid-2",
    "receipt-uuid-3"
  ]
}
```

**Request Body Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| userId | string | Yes | User submitting the report |
| title | string | Yes | Report title |
| description | string | No | Report description |
| receiptIds | array | Yes | Array of receipt IDs to include |

**Success Response (201):**
```json
{
  "success": true,
  "data": {
    "id": "report-uuid",
    "title": "Monthly Expenses - November",
    "description": "All business expenses for November 2025",
    "status": "pending",
    "receiptCount": 3,
    "totalAmount": 12450.00,
    "submittedBy": {
      "id": "user-uuid",
      "name": "John Doe",
      "email": "john@company.com"
    },
    "submittedAt": "2025-12-01T10:00:00Z",
    "createdAt": "2025-12-01T10:00:00Z"
  }
}
```

**Error Response (400):**
```json
{
  "success": false,
  "error": "At least one receipt is required"
}
```

---

### 3.2 List Expense Reports

Returns expense reports for a user.

**Endpoint:**
```
GET /workspace/:workspaceId/expense-reports
```

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| userId | string | Yes | Filter by user ID |
| status | string | No | Filter by status: `pending`, `approved`, `rejected`, `all` |
| page | number | No | Page number (default: 1) |
| pageSize | number | No | Items per page (default: 20) |

**Example Request:**
```
GET /workspace/ws-123/expense-reports?userId=user-456&status=pending&page=1&pageSize=20
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "reports": [
      {
        "id": "report-uuid-1",
        "title": "Monthly Expenses - November",
        "description": "All business expenses for November",
        "status": "pending",
        "receiptCount": 8,
        "totalAmount": 12450.00,
        "submittedAt": "2025-11-28T10:00:00Z",
        "approvedBy": null,
        "approvedAt": null,
        "rejectionReason": null
      },
      {
        "id": "report-uuid-2",
        "title": "Client Meeting Expenses",
        "description": "Expenses from client meetings",
        "status": "approved",
        "receiptCount": 3,
        "totalAmount": 5680.00,
        "submittedAt": "2025-11-20T10:00:00Z",
        "approvedBy": {
          "id": "manager-uuid",
          "name": "Manager Name"
        },
        "approvedAt": "2025-11-21T14:00:00Z",
        "rejectionReason": null
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "totalCount": 15,
      "totalPages": 1,
      "hasNextPage": false,
      "hasPrevPage": false
    }
  }
}
```

---

### 3.3 Get Expense Report Details

Returns detailed information about a specific expense report.

**Endpoint:**
```
GET /workspace/:workspaceId/expense-reports/:reportId
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "id": "report-uuid",
    "title": "Monthly Expenses - November",
    "description": "All business expenses for November 2025",
    "status": "pending",
    "receipts": [
      {
        "id": "receipt-uuid-1",
        "merchant": "Office Supplies Store",
        "amount": 1250.00,
        "category": "Office Expenses",
        "date": "2025-11-26",
        "imageLink": "https://..."
      },
      {
        "id": "receipt-uuid-2",
        "merchant": "Client Lunch Restaurant",
        "amount": 2800.00,
        "category": "Business Meals",
        "date": "2025-11-25",
        "imageLink": "https://..."
      }
    ],
    "totalAmount": 12450.00,
    "submittedBy": {
      "id": "user-uuid",
      "name": "John Doe",
      "email": "john@company.com"
    },
    "submittedAt": "2025-12-01T10:00:00Z",
    "approvedBy": null,
    "approvedAt": null,
    "rejectionReason": null
  }
}
```

---

### 3.4 Approve/Reject Expense Report

Updates the status of an expense report.

**Endpoint:**
```
PATCH /workspace/:workspaceId/expense-reports/:reportId
```

**Request Body (Approve):**
```json
{
  "status": "approved",
  "approvedBy": "manager-uuid"
}
```

**Request Body (Reject):**
```json
{
  "status": "rejected",
  "rejectedBy": "manager-uuid",
  "rejectionReason": "Missing itemized receipts"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "id": "report-uuid",
    "status": "approved",
    "approvedBy": {
      "id": "manager-uuid",
      "name": "Manager Name"
    },
    "approvedAt": "2025-12-01T14:00:00Z"
  }
}
```

---

## 4. User Workspace Receipts APIs

### 4.1 Get User's Workspace Receipts

Returns receipts submitted by a user to the workspace.

**Endpoint:**
```
GET /workspace/:workspaceId/receipts
```

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| userId | string | Yes | Filter by user ID |
| status | string | No | Filter: `all`, `pending`, `approved`, `rejected` |
| page | number | No | Page number (default: 1) |
| pageSize | number | No | Items per page (default: 20) |
| merchant | string | No | Search by merchant name |

**Example Request:**
```
GET /workspace/ws-123/receipts?userId=user-456&status=all&page=1&pageSize=20
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "receipts": [
      {
        "id": "receipt-uuid-1",
        "merchant": "Office Supplies Store",
        "amount": 1250.00,
        "category": "Office Expenses",
        "date": "2025-11-26",
        "status": "approved",
        "imageLink": "https://...",
        "expenseReportId": "report-uuid",
        "rejectionReason": null
      },
      {
        "id": "receipt-uuid-2",
        "merchant": "Team Lunch",
        "amount": 2800.00,
        "category": "Business Meals",
        "date": "2025-11-25",
        "status": "pending",
        "imageLink": "https://...",
        "expenseReportId": null,
        "rejectionReason": null
      },
      {
        "id": "receipt-uuid-3",
        "merchant": "Personal Item",
        "amount": 500.00,
        "category": "Other",
        "date": "2025-11-24",
        "status": "rejected",
        "imageLink": "https://...",
        "expenseReportId": null,
        "rejectionReason": "Not a business expense"
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "totalCount": 50,
      "totalPages": 3,
      "hasNextPage": true,
      "hasPrevPage": false
    }
  }
}
```

---

### 4.2 Submit Receipt to Workspace

Links an existing user receipt to the workspace or creates a new one.

**Endpoint:**
```
POST /workspace/:workspaceId/receipts
```

**Request Body (Link Existing Receipt):**
```json
{
  "userId": "user-uuid",
  "receiptId": "existing-receipt-uuid"
}
```

**Request Body (Create New Receipt):**
```json
{
  "userId": "user-uuid",
  "merchant": "Office Supplies Store",
  "amount": 1250.00,
  "category": "Office Expenses",
  "date": "2025-11-26",
  "imageLink": "https://...",
  "description": "Printer paper and ink cartridges"
}
```

**Success Response (201):**
```json
{
  "success": true,
  "data": {
    "id": "workspace-receipt-uuid",
    "merchant": "Office Supplies Store",
    "amount": 1250.00,
    "category": "Office Expenses",
    "date": "2025-11-26",
    "status": "pending",
    "imageLink": "https://...",
    "submittedAt": "2025-12-01T10:00:00Z"
  }
}
```

---

## 5. Needs/Resource Requests APIs

### 5.1 Create Resource Request

Creates a new needs/resource request.

**Endpoint:**
```
POST /workspace/:workspaceId/needs-requests
```

**Request Body:**
```json
{
  "userId": "user-uuid",
  "title": "New Laptop",
  "category": "Hardware",
  "estimatedCost": 85000.00,
  "costPeriod": "one-time",
  "description": "Current laptop is 4 years old and slowing down productivity. Need replacement for design work.",
  "priority": "high"
}
```

**Request Body Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| userId | string | Yes | User submitting the request |
| title | string | Yes | Request title |
| category | string | Yes | `Hardware`, `Software`, `Software Subscription`, `Service`, `Other` |
| estimatedCost | number | Yes | Estimated cost |
| costPeriod | string | No | `one-time`, `monthly`, `yearly` (default: `one-time`) |
| description | string | Yes | Detailed description |
| priority | string | No | `low`, `medium`, `high` (default: `medium`) |

**Success Response (201):**
```json
{
  "success": true,
  "data": {
    "id": "request-uuid",
    "title": "New Laptop",
    "category": "Hardware",
    "estimatedCost": 85000.00,
    "costPeriod": "one-time",
    "description": "Current laptop is 4 years old...",
    "priority": "high",
    "status": "pending",
    "submittedBy": {
      "id": "user-uuid",
      "name": "John Doe"
    },
    "submittedAt": "2025-12-01T10:00:00Z"
  }
}
```

---

### 5.2 List Resource Requests

Returns resource requests.

**Endpoint:**
```
GET /workspace/:workspaceId/needs-requests
```

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| userId | string | No | Filter by submitter (for "My Requests") |
| status | string | No | Filter: `pending`, `approved`, `rejected`, `all` |
| page | number | No | Page number (default: 1) |
| pageSize | number | No | Items per page (default: 20) |

**Example Request (My Requests):**
```
GET /workspace/ws-123/needs-requests?userId=user-456
```

**Example Request (Team Requests - Manager/Owner):**
```
GET /workspace/ws-123/needs-requests?status=pending
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "requests": [
      {
        "id": "request-uuid-1",
        "title": "New Laptop",
        "category": "Hardware",
        "estimatedCost": 85000.00,
        "costPeriod": "one-time",
        "description": "Current laptop is 4 years old...",
        "priority": "high",
        "status": "pending",
        "submittedBy": {
          "id": "user-uuid",
          "name": "John Doe"
        },
        "submittedAt": "2025-12-01T10:00:00Z",
        "approvedBy": null,
        "approvedAt": null,
        "rejectionReason": null
      },
      {
        "id": "request-uuid-2",
        "title": "Adobe Creative Cloud",
        "category": "Software Subscription",
        "estimatedCost": 2500.00,
        "costPeriod": "monthly",
        "description": "Required for graphic design work",
        "priority": "medium",
        "status": "approved",
        "submittedBy": {
          "id": "user-uuid",
          "name": "John Doe"
        },
        "submittedAt": "2025-11-25T10:00:00Z",
        "approvedBy": {
          "id": "manager-uuid",
          "name": "Manager Name"
        },
        "approvedAt": "2025-11-26T14:00:00Z",
        "rejectionReason": null
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "totalCount": 5,
      "totalPages": 1
    }
  }
}
```

---

### 5.3 Update Resource Request Status

Approve or reject a resource request.

**Endpoint:**
```
PATCH /workspace/:workspaceId/needs-requests/:requestId
```

**Request Body (Approve):**
```json
{
  "status": "approved",
  "approvedBy": "manager-uuid",
  "notes": "Approved for Q1 budget"
}
```

**Request Body (Reject):**
```json
{
  "status": "rejected",
  "rejectedBy": "manager-uuid",
  "rejectionReason": "Budget constraints this quarter"
}
```

**Request Body (Assign to Owner):**
```json
{
  "assignedTo": "owner-uuid",
  "notes": "Needs owner approval for this amount"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "id": "request-uuid",
    "status": "approved",
    "approvedBy": {
      "id": "manager-uuid",
      "name": "Manager Name"
    },
    "approvedAt": "2025-12-01T14:00:00Z"
  }
}
```

---

## 6. Owner Pending Approvals API

### 6.1 Get All Pending Items for Owner

Returns all pending items (expense reports + needs requests) for owner review.

**Endpoint:**
```
GET /workspace/:workspaceId/owner/pending-approvals
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "pendingExpenseReports": [
      {
        "id": "report-uuid-1",
        "title": "November Expenses",
        "submittedBy": {
          "id": "user-uuid",
          "name": "John Doe",
          "avatar": "https://..."
        },
        "totalAmount": 15000.00,
        "receiptCount": 5,
        "submittedAt": "2025-12-01T10:00:00Z"
      },
      {
        "id": "report-uuid-2",
        "title": "Travel Expenses",
        "submittedBy": {
          "id": "user-uuid-2",
          "name": "Jane Smith",
          "avatar": "https://..."
        },
        "totalAmount": 28000.00,
        "receiptCount": 8,
        "submittedAt": "2025-11-30T10:00:00Z"
      }
    ],
    "pendingNeedsRequests": [
      {
        "id": "request-uuid-1",
        "title": "New Laptop",
        "submittedBy": {
          "id": "user-uuid",
          "name": "John Doe",
          "avatar": "https://..."
        },
        "estimatedCost": 85000.00,
        "category": "Hardware",
        "priority": "high",
        "submittedAt": "2025-12-01T10:00:00Z"
      }
    ],
    "counts": {
      "expenseReports": 2,
      "needsRequests": 1,
      "total": 3
    }
  }
}
```

---

## 7. Activity Feed API

### 7.1 Get Workspace Activity Feed

Returns recent activity in the workspace.

**Endpoint:**
```
GET /workspace/:workspaceId/activity
```

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| limit | number | No | Number of activities (default: 10, max: 50) |
| offset | number | No | Offset for pagination |

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "activities": [
      {
        "id": "activity-uuid-1",
        "type": "member_added",
        "title": "New Team Member Added",
        "description": "John added Sarah to the workspace",
        "timestamp": "2025-12-01T10:00:00Z",
        "actor": {
          "id": "user-uuid",
          "name": "John Doe",
          "avatar": "https://..."
        },
        "metadata": {
          "newMemberId": "sarah-uuid",
          "newMemberName": "Sarah Smith"
        }
      },
      {
        "id": "activity-uuid-2",
        "type": "expense_approved",
        "title": "Expense Approved",
        "description": "Office Supplies - ₹2,500",
        "timestamp": "2025-11-30T14:00:00Z",
        "actor": {
          "id": "manager-uuid",
          "name": "Manager Name",
          "avatar": "https://..."
        },
        "metadata": {
          "expenseId": "expense-uuid",
          "amount": 2500.00
        }
      },
      {
        "id": "activity-uuid-3",
        "type": "report_submitted",
        "title": "Expense Report Submitted",
        "description": "Monthly Expenses - November",
        "timestamp": "2025-11-30T10:00:00Z",
        "actor": {
          "id": "user-uuid",
          "name": "John Doe",
          "avatar": "https://..."
        },
        "metadata": {
          "reportId": "report-uuid",
          "totalAmount": 12450.00
        }
      }
    ]
  }
}
```

**Activity Types:**
- `member_added` - New member added to workspace
- `member_removed` - Member removed from workspace
- `role_changed` - Member role updated
- `expense_submitted` - Single expense submitted
- `expense_approved` - Single expense approved
- `expense_rejected` - Single expense rejected
- `report_submitted` - Expense report submitted
- `report_approved` - Expense report approved
- `report_rejected` - Expense report rejected
- `request_submitted` - Needs request submitted
- `request_approved` - Needs request approved
- `request_rejected` - Needs request rejected

---

## Summary - All New APIs Required

| # | Method | Endpoint | Priority |
|---|--------|----------|----------|
| 1 | GET | `/workspace/:workspaceId/user-dashboard` | High |
| 2 | GET | `/workspace/:workspaceId/manager-dashboard` | High |
| 3 | POST | `/workspace/:workspaceId/expense-reports` | High |
| 4 | GET | `/workspace/:workspaceId/expense-reports` | High |
| 5 | GET | `/workspace/:workspaceId/expense-reports/:reportId` | Medium |
| 6 | PATCH | `/workspace/:workspaceId/expense-reports/:reportId` | High |
| 7 | GET | `/workspace/:workspaceId/receipts` | High |
| 8 | POST | `/workspace/:workspaceId/receipts` | High |
| 9 | POST | `/workspace/:workspaceId/needs-requests` | Medium |
| 10 | GET | `/workspace/:workspaceId/needs-requests` | Medium |
| 11 | PATCH | `/workspace/:workspaceId/needs-requests/:requestId` | Medium |
| 12 | GET | `/workspace/:workspaceId/owner/pending-approvals` | High |
| 13 | GET | `/workspace/:workspaceId/activity` | Low |

---

## Notes for Backend Team

1. **Authentication:** All endpoints require Bearer token authentication
2. **Authorization:** Endpoints should validate user's role in workspace (owner/manager/user)
3. **Pagination:** Use consistent pagination format across all list endpoints
4. **Timestamps:** Use ISO 8601 format (e.g., `2025-12-01T10:00:00Z`)
5. **Currency:** Amount fields should be stored as decimal/float with 2 decimal places
6. **Status Values:**
   - Expenses/Reports: `pending`, `approved`, `rejected`
   - Needs Requests: `pending`, `approved`, `rejected`

---

## Contact

For any questions regarding these API requirements, please contact the mobile development team.




























