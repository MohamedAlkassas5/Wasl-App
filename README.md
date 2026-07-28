# 🤖 AI Development Instructions

> **Role:** Lead Software Engineer • Product Architect • Senior Code Reviewer

This repository is intended to be developed collaboratively with AI coding assistants such as **Claude Code**, **Cursor AI**, **GitHub Copilot Agent**, or **Gemini CLI**.

## Mission

Your mission is **NOT** to rebuild this project.

Your mission is to understand the existing architecture, audit the codebase, and complete the project into a production-ready MVP while preserving the original business vision.

---

# Project

**Wasl (وصل)**

A local delivery marketplace connecting:

- 👤 Customers
- 🛵 Delivery Drivers
- 🏪 Merchants

Initial launch target:

**Kom Hamada, El Beheira, Egypt**

The architecture must remain scalable for future expansion.

---

# Primary Objectives

Before writing any code:

- Read the entire project.
- Understand every module.
- Understand navigation.
- Understand architecture.
- Understand state management.
- Understand backend modules.
- Understand database design.

Never make assumptions.

---

# Development Workflow

## Phase 1 — Audit

Create a complete audit report including:

- Existing features
- Missing features
- Broken screens
- Broken APIs
- Duplicate code
- Architecture issues
- Missing validation
- Database inconsistencies
- Performance issues
- Security issues
- Technical debt

Do **NOT** modify anything until the audit is complete.

---

## Phase 2 — Architecture Review

Review the project's:

- Flutter Architecture
- Clean Architecture implementation
- Feature modules
- Dependency Injection
- Routing
- Riverpod providers
- Repositories
- Services
- DTOs
- Entities
- NestJS modules
- Database schema

Refactor only where necessary.

---

## Phase 3 — Implementation

Complete the missing functionality while preserving:

- Existing design language
- Existing color palette
- Existing navigation
- Existing UI components
- Existing architecture
- Existing business logic

Do not redesign the application.

---

# Core Features

## Customer

- Phone Authentication
- WhatsApp OTP
- Profile
- Home
- Search
- Categories
- Stores
- Products
- Cart
- Checkout
- Saved Addresses
- Wallet
- Coupons
- Favorites
- Notifications
- Order Tracking
- Live Driver Tracking

---

## Driver

- Registration
- Documents
- Vehicle Information
- Online / Offline
- Nearby Orders
- Accept / Reject Orders
- Delivery Pricing
- Navigation
- Earnings
- Wallet
- Commission History

---

## Merchant

- Registration
- Store Management
- Products
- Inventory
- Orders
- Status Updates

---

# Required Order Types

## Marketplace Orders

Customer purchases from registered stores.

Flow:

Category

↓

Store

↓

Products

↓

Cart

↓

Checkout

↓

Payment

↓

Delivery

---

## Send Anything

Customer creates a custom delivery request.

Required:

- Pickup Location
- Destination
- Item Description
- Images
- Voice Note
- Instructions

Example:

- Documents
- Medicine
- Packages
- Personal Items

---

# Required Backend Improvements

Implement production-ready services.

## GPS System

Never hardcode coordinates.

Support:

- GPS
- Live Driver Tracking
- Address Saving
- Radius Search
- ETA
- Distance Calculation

Recommended:

- PostgreSQL
- PostGIS
- Latitude / Longitude
- Spatial Queries

---

## Driver Matching

Create a nearest-driver algorithm.

Example:

Initial search:

5 km

↓

10 km

↓

20 km

↓

Until driver found.

---

## Delivery Pricing Engine

Never calculate prices inside Flutter.

Create:

```text
DeliveryPricingService
```

Example:

| Distance | Price |
|----------|------:|
| 0–5 KM | 20 EGP |
| 5–15 KM | 40 EGP |
| 15+ KM | Dynamic |

Configurable commission.

Example:

Delivery Fee:

40 EGP

Commission:

20%

Driver:

32 EGP

Platform:

8 EGP

---

## WhatsApp OTP

Create abstraction:

```text
OtpService
```

Supported providers:

- Meta WhatsApp Cloud API
- Twilio WhatsApp
- WhatsApp Business API

Never couple the implementation to a single provider.

---

## Payment

MVP:

Cash On Delivery

Driver wallet:

Automatic commission deduction after successful delivery.

---

# Code Quality Rules

✅ Keep working code.

✅ Remove dead code.

✅ No duplicated widgets.

✅ No duplicated APIs.

✅ No hardcoded business logic.

✅ No fake APIs.

✅ No placeholder implementations.

✅ No TODOs.

✅ Proper validation.

✅ Error handling.

✅ Logging.

✅ Clean architecture.

---

# Flutter Requirements

Improve:

- Responsive UI
- Loading states
- Empty states
- Error states
- Animations
- Accessibility
- Performance

Keep:

- Theme
- Navigation
- UI Style

---

# Backend Requirements

Use:

- NestJS
- DTO Validation
- Guards
- JWT
- Repository Pattern
- Service Layer
- PostgreSQL
- PostGIS

---

# Testing

After every major change execute:

Flutter

```bash
flutter analyze

flutter test

flutter build apk
```

Backend

```bash
npm run build
```

Fix every warning before continuing.

---

# Final Delivery

Provide:

- ✅ Completed Features
- ✅ Modified Files
- ✅ New Files
- ✅ Database Changes
- ✅ API Changes
- ✅ Test Results
- ✅ Remaining Issues
- ✅ MVP Readiness Percentage

---

# Important Rules

Never rebuild the project.

Never change the business idea.

Never redesign the UI unnecessarily.

Always preserve the existing architecture unless a refactor is clearly justified.

Always analyze before coding.

The goal is to deliver a **production-ready Wasl MVP V1** suitable for real-world testing in **Kom Hamada, El Beheira, Egypt**, while maintaining a scalable architecture for future expansion.
