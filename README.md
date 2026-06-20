# greenroot-mobile
greenroot-mobile

# GreenRoot Mobile

GreenRoot Mobile is the official mobile application for nursery owners, gumastas, and drivers to manage plant dispatches, deliveries, and transportation activities.

---

## Overview

GreenRoot helps plant businesses:

* Create dispatches
* Manage plant loading
* Assign drivers
* Track trips
* Verify deliveries
* Maintain dispatch history
* Monitor transportation operations

---

## User Roles

### Owner

Features:

* View all dispatches
* Approve dispatches
* Track active trips
* View reports
* Manage users
* Monitor deliveries

---

### Gumasta

Features:

* Create dispatches
* Add plant items
* Start loading
* Complete loading
* Upload loading photos
* Assign drivers

---

### Driver

Features:

* View assigned trips
* Start trip
* Share GPS location
* Upload delivery photos
* Complete deliveries

---

## Key Features

### Authentication

* Mobile OTP Login
* Device Registration
* Role-Based Access

### Dispatch Management

* Create Dispatch
* Plant Manifest
* Loading Workflow
* Approval Workflow

### GPS Tracking

* Real-Time Location Updates
* Trip Monitoring
* Route Visibility

### Delivery Verification

* Delivery Photos
* GPS Validation
* Timestamp Verification

### Notifications

* Dispatch Created
* Dispatch Approved
* Trip Started
* Trip Delivered
* Trip Cancelled

---

## Technology Stack

### Framework

Flutter

### Language

Dart

### Architecture

Feature First Architecture

### State Management

Riverpod

### Networking

Dio

### Local Storage

Hive

### Maps

OpenStreetMap

### Notifications

Firebase Cloud Messaging (FCM)

### Authentication

Firebase Authentication

---

## Project Structure

```text
lib/

├── app/
├── core/
├── features/
│
├── auth/
├── dashboard/
├── dispatch/
├── plants/
├── trips/
├── tracking/
├── notifications/
├── profile/
│
├── shared/
├── widgets/
├── services/
└── main.dart
```

---

## Build Environments

### Development

```text
DEV
```

Used for local development and testing.

### Production

```text
PROD
```

Used for real customers.

---

## Minimum Supported Version

Android 10+

---

## Security

* OTP Authentication
* Secure API Tokens
* Device Registration
* Audit Logging
* Role-Based Authorization

---

## Future Roadmap

### V1

* Dispatch Management
* Driver Tracking
* Delivery Verification

### V2

* Nursery Analytics
* Customer Management
* Advanced Reports

### V3

* Plant Marketplace
* Customer Ordering
* AI Recommendations

---

## Product Vision

GreenRoot aims to become the digital operating platform for nursery businesses by providing visibility from plant loading to final delivery.

