# Roles and Permissions in the Pet App

## Current Roles in the System

### 1. **admin** (4 users)
**Current Permissions:**
- View admin dashboard
- Manage all users
- Set coin prices for all coin types
- Transfer any coin type to any user
- Approve/reject customer transactions
- View all transactions

**Dashboard:** `AdminDashboard` (`lib/Dashboard/admin.dart`)

### 2. **customer** (9 users)
**Current Permissions:**
- View customer dashboard
- View their own wallet balance (all 3 coin types)
- View current coin prices
- Send payments (with admin approval required)
- View transaction history
- Scan QR codes
- Generate QR codes for receiving

**Dashboard:** `CustomerDashboard` (`lib/Dashboard/customer.dart`)

### 3. **company** (1 user)
**Current Permissions:**
- Currently routes to CustomerDashboard (needs separate dashboard)
- Has 100Cr coins for each coin type

**Issues:**
- No dedicated dashboard
- Should have special permissions

### 4. **franchise** (3 users)
**Current Permissions:**
- Currently routes to CustomerDashboard
- Limited functionality

**Issues:**
- Needs dedicated dashboard with franchise-specific features

### 5. **channel_partner** (2 users)
**Current Permissions:**
- Currently routes to CustomerDashboard
- Limited functionality

**Issues:**
- Needs dedicated dashboard

### 6. **sub-franchise** (2 users)
**Current Permissions:**
- Currently routes to CustomerDashboard
- Limited functionality

**Issues:**
- Needs dedicated dashboard

## Current Navigation Logic

```dart
// From lib/signin.dart
if (response.user?.role == 'admin') {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const AdminDashboard()),
  );
} else {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const CustomerDashboard()),
  );
}
```

## Recommended Permission Structure

### Role Hierarchy (from highest to lowest authority):

1. **admin** - Full system control
2. **company** - Highest business entity
3. **bank** - Financial institution
4. **channel_partner** - Business partners
5. **franchise** - Regional franchises
6. **sub-franchise** - Sub-regional franchises
7. **merchant** - Business merchants
8. **partner** - General partners
9. **customer** - End users

## Recommendations for Improvement

### 1. **Create Dedicated Dashboards**
- `company.dart` - For company role
- `franchise.dart` - For franchise role
- `channel_partner.dart` - For channel partner role
- `merchant.dart` - For merchant role
- `sub-franchise.dart` - For sub-franchise role

### 2. **Update Navigation Logic**
Create a routing system that:
- Maps each role to its dedicated dashboard
- Falls back to CustomerDashboard for unknown roles
- Handles role-specific permissions

### 3. **Define Clear Permissions**

#### **Company Role:**
- View overall system statistics
- Manage franchises and channel partners
- View all transactions across the network
- Set coin distribution policies
- Transfer coins to franchises/partners

#### **Franchise Role:**
- View their region's statistics
- Manage merchants under them
- View transactions in their region
- Transfer coins to merchants
- Request coins from company

#### **Channel Partner Role:**
- View their partner statistics
- Manage their own transactions
- View commission/earnings
- Transfer coins to merchants

#### **Merchant Role:**
- View their business statistics
- Accept payments from customers
- View their earnings
- Transfer coins to bank

#### **Customer Role:**
- Current functionality is appropriate
- Send/receive payments
- View personal wallet

### 4. **Multi-Level Approval Flow**
Consider implementing:
- Customer → Merchant (approval by Franchise)
- Merchant → Franchise (approval by Company)
- Franchise → Company (auto-approved)
- Bank transactions (admin approval required)

## Files That Need Updates

1. `lib/signin.dart` - Update routing logic
2. Create new dashboard files for each role
3. `lib/Dashboard/admin.dart` - Add role management features
4. `lib/services/auth_service.dart` - Add role validation
5. `lib/models/user.dart` - Add permission checking methods
