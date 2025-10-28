# PET Coin Wallets Page - Database Analysis Report

## Executive Summary

After analyzing the database structure and the code, I've identified **critical issues** with how wallet balances are displayed on the PET Coin Wallets page.

---

## Database Structure

### Table: `pet_coin_wallets`

| Column | Type | Description | Current Value Issue |
|--------|------|-------------|---------------------|
| `id` | uuid | Wallet ID | ✅ |
| `user_id` | uuid | Foreign key to users | ✅ |
| `balance` | numeric | **LEGACY** field | ❌ Not sum of coins |
| `petnt_balance` | numeric | PET NT coins | ⚠️ Not fetched |
| `petbnt_balance` | numeric | PET BNT coins | ⚠️ Not fetched |
| `petindx_balance` | numeric | PET INDX coins | ⚠️ Not fetched |
| `created_at` | timestamp | Created timestamp | ✅ |
| `updated_at` | timestamp | Updated timestamp | ✅ |

---

## The Problem

### Issue #1: Query Doesn't Fetch Coin-Specific Balances

**Location:** `lib/services/pet_coin_wallet_service.dart` (lines 79-83)

```dart
final response = await _client
    .from('pet_coin_wallets')
    .select('''
      id, user_id, balance, created_at, updated_at,
      user:users!pet_coin_wallets_user_id_fkey(email, role)
    ''')
    .order('balance', ascending: false);
```

**Problem:** The query only selects the legacy `balance` field and NOT the coin-specific balances (`petnt_balance`, `petbnt_balance`, `petindx_balance`).

### Issue #2: UI Displays Wrong Balance

**Location:** `lib/admin/coinwallets.dart` (line 1440)

```dart
Text(
  '${PetCoinWalletService.formatCoins(wallet.balance)} 🪙',
  // ...
)
```

**Problem:** The UI displays `wallet.balance` instead of the actual coin-specific balances.

### Issue #3: Data Mismatch

**Example from Database:**

User: **vstrongfitness2025@gmail.com**
- DB `balance` field: **101.97** (shown in UI)
- DB `petnt_balance`: **120.97**
- DB `petbnt_balance`: **0.00**
- DB `petindx_balance`: **1.00**
- **Actual Total: 121.97** (NOT shown)

**The UI is showing 101.97, but the real balance is 121.97!**

---

## Real Database Data

Here's actual data from your database:

```json
[
  {
    "email": "vstrongfitness2025@gmail.com",
    "role": "sub-franchise",
    "balance": "101.97",         // ❌ Shown in UI
    "petnt_balance": "120.97",   // ✅ Real balance
    "petbnt_balance": "0.00",
    "petindx_balance": "1.00"
  },
  {
    "email": "23csea55santhoshmrs@gmail.com",
    "role": "customer",
    "balance": "118.03",         // ❌ Shown in UI
    "petnt_balance": "109.03",   // ✅ Real balance
    "petbnt_balance": "0.00",
    "petindx_balance": "6.0"
  }
]
```

---

## The Root Cause

1. **Database has 4 balance columns:**
   - `balance` (legacy, outdated)
   - `petnt_balance` (current)
   - `petbnt_balance` (current)
   - `petindx_balance` (current)

2. **Service only fetches the legacy `balance` field**

3. **UI displays the wrong balance**

---

## Recommended Fix

### Option 1: Fix the Query (Recommended)

Update `getAllWallets()` to fetch all balance columns:

```dart
static Future<({List<PetCoinWallet> wallets, String? error})>
getAllWallets() async {
  try {
    final response = await _client
        .from('pet_coin_wallets')
        .select('''
          id, user_id, balance, 
          petnt_balance, petbnt_balance, petindx_balance,
          created_at, updated_at,
          user:users!pet_coin_wallets_user_id_fkey(email, role)
        ''')
        .order('balance', ascending: false);
    // ... rest of code
  }
}
```

### Option 2: Update the UI to Show Individual Coin Balances

Replace single balance display with individual coin balances:

```dart
// Instead of:
Text('${PetCoinWalletService.formatCoins(wallet.balance)} 🪙')

// Show:
Column(
  children: [
    Text('PET NT: ${wallet.petntBalance}'),
    Text('PET BNT: ${wallet.petbntBalance}'),
    Text('PET INDX: ${wallet.petindxBalance}'),
    Text('Total: ${wallet.petntBalance + wallet.petbntBalance + wallet.petindxBalance}'),
  ],
)
```

---

## Impact

- **Users are seeing incorrect balances** (outdated `balance` field)
- **Transfer functionality may be using wrong amounts**
- **Stats cards show wrong totals**
- **Company balance calculations are incorrect**

---

## Additional Issues Found

1. **No Error Handling:** Service catches errors but only prints to console
2. **No Pagination:** All wallets load at once (slow for large user bases)
3. **Inefficient Query:** Creates wallets for all users every time (line 82-84)
4. **Transfer Logic:** May be transferring from wrong balance types

---

## Next Steps

1. ✅ Update `getAllWallets()` query to fetch all balance fields
2. ✅ Update UI to show coin-specific balances
3. ✅ Fix transfer functionality to use correct balance types
4. ✅ Add proper error handling
5. ✅ Consider adding pagination
6. ✅ Optimize wallet creation process

Would you like me to implement these fixes?

