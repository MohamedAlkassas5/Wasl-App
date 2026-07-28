# 🤖 AI Development Instructions

> **Role:** Lead Software Engineer • Software Architect • Senior Backend Engineer • Senior Flutter Engineer • DevOps Engineer • Code Reviewer • QA Engineer

---

# Mission

You are responsible for transforming this repository into a **production-ready MVP (V1)**.

Your objective is **NOT** to rewrite or recreate the project.

Your objective is to understand, improve, complete, and stabilize the existing codebase while preserving the current architecture and business vision.

Always think like a senior engineer working on an existing production product—not like a code generator.

---

# Project

## Wasl (وصل)

A hyper-local delivery marketplace connecting:

- 👤 Customers
- 🛵 Delivery Drivers
- 🏪 Merchants

Initial launch city:

**Kom Hamada, El Beheira, Egypt**

The architecture must remain scalable for nationwide expansion.

---

# Engineering Principles

Always follow these principles:

- Analyze before coding.
- Never make assumptions.
- Never replace working code.
- Never duplicate functionality.
- Never redesign the application without a technical reason.
- Never hardcode business logic.
- Never leave unfinished work.
- Never create placeholder implementations.
- Never create fake APIs.
- Never ignore compile warnings.
- Prefer extending existing modules over creating new ones.
- Keep changes incremental and maintainable.

---

# Development Workflow

The project must be completed using the following phases.

---

# Phase 1 — Codebase Audit

Read the **entire project** before making any changes.

Understand:

- Flutter architecture
- Folder structure
- Navigation
- State management
- Dependency Injection
- Shared widgets
- Feature modules
- Models
- Repositories
- Services
- APIs
- Backend modules
- Database schema
- Environment configuration
- Assets
- Build configuration

Do not write code until the audit is complete.

---

## Audit Report

Generate a detailed report including:

### Flutter

- Existing features
- Missing screens
- Broken navigation
- UI inconsistencies
- Responsive issues
- Accessibility issues
- Duplicate widgets
- Dead code
- Unused assets
- Unused packages
- Missing localization

### Backend

- Existing modules
- Missing endpoints
- Incorrect DTO validation
- Missing authentication
- Missing authorization
- Security issues
- Database inconsistencies
- Performance bottlenecks
- Missing indexes
- Transaction issues

### General

- Technical debt
- Architecture violations
- Dependency problems
- Code smells
- Potential bugs
- Missing tests

Do not modify code before completing this report.

---

# Phase 2 — Architecture Review

Review the architecture and improve only when necessary.

Keep:

- Existing design system
- Existing UI
- Existing navigation
- Existing branding
- Existing business idea

Improve:

- Maintainability
- Scalability
- Performance
- Security
- Testability

---

# Phase 3 — MVP Completion

Complete every missing feature required for MVP V1.

Do not leave partially implemented functionality.

Every feature must be fully integrated.

---

# Customer Features

Implement and verify:

- Phone Authentication
- WhatsApp OTP
- Profile
- Home
- Categories
- Search
- Stores
- Products
- Cart
- Checkout
- Saved Addresses
- Favorites
- Wallet
- Coupons
- Notifications
- Order Tracking
- Live Driver Tracking

---

# Driver Features

Implement:

- Registration
- Document Upload
- Vehicle Information
- Approval Workflow
- Online / Offline
- Nearby Orders
- Accept Orders
- Reject Orders
- Counter Offer
- Earnings
- Wallet
- Commission History
- Navigation
- Delivery Completion

---

# Merchant Features

Implement:

- Merchant Registration
- Store Management
- Product Management
- Categories
- Inventory
- Orders
- Order Status
- Store Profile

---

# Marketplace Orders

Support full marketplace flow.

Customer

↓

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

Driver Assignment

↓

Tracking

↓

Delivery

---

# Send Anything Orders

Support custom delivery requests.

Required fields:

- Pickup Location
- Destination
- Description
- Images
- Voice Note
- Notes

Examples:

- Documents
- Medicine
- Packages
- Personal Items

---

# GPS & Maps

Never use hardcoded coordinates.

Implement:

- Device GPS
- Live Driver Tracking
- Manual Map Selection
- Saved Addresses
- Reverse Geocoding
- ETA
- Distance Calculation

Backend must support:

- Latitude
- Longitude
- Spatial Queries
- Radius Search

Recommended:

- PostgreSQL
- PostGIS

---

# Driver Matching Engine

Implement nearest driver algorithm.

Radius expansion:

5 km

↓

10 km

↓

20 km

↓

30 km

↓

Until driver found.

Prioritize:

- Online
- Available
- Closest
- Highest Rating

---

# Delivery Pricing Engine

Pricing must exist only in backend.

Create:

```text
DeliveryPricingService
```

Requirements:

- Base fee
- Distance pricing
- Area pricing
- Surge pricing support
- Configurable commission
- Future promo support

Example:

| Distance | Delivery Fee |
|-----------|-------------:|
| 0–5 KM | 20 EGP |
| 5–15 KM | 40 EGP |
| 15+ KM | Dynamic |

---

# Authentication

Create provider-independent OTP service.

```text
OtpService
```

Supported providers:

- Meta WhatsApp Cloud API
- Twilio WhatsApp
- WhatsApp Business API

Implementation must be provider-agnostic.

---

# Payments

Current MVP

Customer:

- Cash on Delivery

Driver:

- Wallet
- Automatic commission deduction

Future-ready architecture for:

- Stripe
- Paymob
- Fawry

---

# Flutter Standards

Improve:

- Responsiveness
- Animations
- UX
- Error Handling
- Empty States
- Loading States
- Form Validation
- Offline Handling

Maintain:

- Existing Theme
- Existing Colors
- Existing Components

---

# Backend Standards

Use:

- NestJS
- JWT Authentication
- Guards
- DTO Validation
- Repository Pattern
- Service Layer
- PostgreSQL
- PostGIS
- Redis (if appropriate)
- Transaction Support

---

# Code Quality

Follow:

- SOLID
- Clean Architecture
- DRY
- KISS
- Repository Pattern
- Dependency Injection

Remove:

- Duplicate code
- Dead code
- Unused imports
- Magic numbers
- Hardcoded values

---

# Testing

After every significant implementation execute:

## Flutter

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Backend

```bash
npm run lint
npm run test
npm run build
```

Resolve all errors before proceeding.

---

# Final Delivery

Provide a complete engineering report containing:

## Completed Features

List every implemented feature.

## Modified Files

List every changed file.

## New Files

List every created file.

## Database Changes

Include:

- New tables
- New columns
- Indexes
- Constraints
- Migrations

## API Changes

List:

- New endpoints
- Modified endpoints
- Removed endpoints

## Security Improvements

Describe:

- Authentication
- Authorization
- Validation
- Rate limiting
- Input sanitization

## Performance Improvements

Describe:

- Query optimization
- Caching
- Widget optimization
- Memory improvements

## Remaining Issues

List only real blockers.

## MVP Readiness

Provide a realistic percentage with justification.

---

# Success Criteria

The project is considered complete only when:

- No compile errors
- No analyzer errors
- No duplicate code
- No placeholder implementations
- No fake APIs
- All navigation works
- All required screens are functional
- Backend builds successfully
- Flutter builds successfully
- MVP is ready for real-world testing in Kom Hamada, Egypt
- Architecture remains scalable for future expansion
