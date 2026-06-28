Use the **same visual style**, but show different dashboards, menus, and FAB actions for each role.

> **Final rule used:** Manager can create a quotation, but **cannot create or convert an order**.

## 🌳 Nursery Owner

**Bottom menu:**
`Home | Business | Sourcing | Profile`

**Dashboard**

* Orders needing action
* Quotations awaiting action
* Loading in progress
* Active dispatches
* Plant sourcing responses
* Pending manager/driver invites

**Business menu**

* Orders
* Quotations
* Loading
* Dispatches
* Inventory
* Managers
* Connected Drivers
* Customers

**Sourcing menu**

* Nearby Nurseries
* Search Plants
* Need Plants
* Available Plants
* My Posts
* Responses
* Top 20 Plants

**FAB (+)**

* Create Order
* Create Quotation
* Need Plants

**Order-level actions**

* Assign manager
* Assign driver
* Start/reopen loading
* Generate trip QR
* Cancel order
* Track dispatch

---

## 👨‍💼 Manager

**Bottom menu:**
`Home | My Work | Sourcing | Profile`

**Dashboard**

* Orders assigned to me
* Quotations created by me
* Loading tasks
* Dispatch tasks
* Plant requirements
* Sourcing responses

**My Work menu**

* Assigned Orders
* My Quotations
* Loading Queue
* Dispatches
* Loading Photos
* Inventory — view only
* Connected Drivers

**Sourcing menu**

* Nearby Nurseries
* Search Plants
* Need Plants
* Available Plants
* My Posts
* Responses
* Top Available Plants

**FAB (+)**

* Create Quotation
* Need Plants
* Available Plants

**Assigned-order actions**

* Start loading
* Add/update/remove items during loading
* Upload loading photos
* Complete loading
* Create dispatch when eligible
* Track assigned dispatch

**Never show**

* Create Order
* Convert to Order
* Assign manager or driver
* Cancel order
* Edit inventory
* Manager management
* Customer mobile number or address

Managers need full sourcing access because they usually perform the physical sourcing work. 

---

## 🚛 Driver

**Bottom menu:**
`Home | Trips | Profile`

**Dashboard**

* Current active trip
* Pending trip invitation
* Next destination
* Trip status
* Recent completed trip

**Trips menu**

* Active Trip
* Scan Trip QR
* Enter Trip Code
* Pending Trips
* Trip History

**FAB**

* Scan Trip QR

**Trip actions**

* Accept trip
* Reject trip
* Share GPS automatically
* Add trip event
* Upload delivery proof
* Complete delivery

**Never show**

* Orders
* Quotations
* Plants
* Inventory
* Sourcing
* Nursery operations
* Customer private details

The driver experience should focus entirely on the assigned trip and allow only one active trip at a time. 

---

## 🤝 Customer

**Bottom menu:**
`Home | Plants | My Activity | Profile`

**Dashboard**

* New quotations
* Active orders
* Delivery in progress
* Recently completed orders
* Nursery relationships

**Plants menu**

* Browse Plants
* Search Plants
* Plant Details
* Care Information
* Sizes and Names

**My Activity menu**

* My Quotations
* My Orders
* Track Delivery
* Connected Nurseries
* Accept Customer Invite

**FAB (+)**

* Scan Customer Invite
* Register My Nursery

**Quotation actions**

* View quotation
* Accept quotation
* Reject quotation

**Order actions**

* View own order
* View status
* Track delivery

**Never show**

* Create selling order
* Edit order or quotation
* Loading
* Dispatch controls
* Inventory
* Plant sourcing
* Manager or driver private details
* Nursery internal operations

Customers should only see their own quotations, orders, and delivery information. 

## Common top layout

```text
┌──────────────────────────────┐
│ Workspace/Nursery    🔔  👤  │
├──────────────────────────────┤
│ Important status card        │
├──────────────────────────────┤
│ Quick links — 2 × 2 grid     │
├──────────────────────────────┤
│ Current tasks / recent items │
├──────────────────────────────┤
│ Role-based bottom menu   FAB │
└──────────────────────────────┘
```

This gives each user one clear purpose:

* **Owner:** Control the nursery.
* **Manager:** Complete assigned operational and sourcing work.
* **Driver:** Complete the current trip.
* **Customer:** View quotations, orders, and delivery.
