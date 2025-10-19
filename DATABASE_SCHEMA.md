# Supabase Database Schema & Integration

## Database Structure

### 1. **users** table
```sql
Columns:
- id: uuid (primary key, auto-generated)
- email: varchar (unique)
- role: varchar (default: 'user')
- password: text (nullable)
- created_at: timestamptz (default: now())
- updated_at: timestamptz (default: now())
```

### 2. **pet_coin_wallets** table
```sql
Columns:
- id: uuid (primary key, auto-generated)
- user_id: uuid (foreign key to users.id, unique)
- balance: numeric (default: 0.00)
- created_at: timestamptz (default: now())
- updated_at: timestamptz (default: now())
```

### 3. **pet_coin_settings** table
```sql
Columns:
- id: uuid (primary key, auto-generated)
- coin_value_rupees: numeric (default: 1.00)
- is_active: boolean (default: true)
- created_at: timestamptz (default: now())
- updated_at: timestamptz (default: now())
- updated_by: uuid (foreign key to users.id, nullable)
```

### 4. **transactions** table
```sql
Columns:
- id: uuid (primary key, auto-generated)
- user_id: uuid (foreign key to auth.users.id, nullable)
- amount: numeric
- currency: varchar (default: 'USD')
- description: text
- status: varchar (default: 'pending', check: 'pending', 'approved', 'rejected')
- transaction_type: varchar (check: 'payment', 'refund', 'withdrawal', 'deposit', 'pet_coin_transfer')
- created_at: timestamptz (default: now())
- updated_at: timestamptz (default: now())
- approved_by: uuid (foreign key to auth.users.id, nullable)
- approved_at: timestamptz (nullable)
- rejection_reason: text (nullable)
- from_user_id: uuid (foreign key to users.id, nullable)
- to_user_id: uuid (foreign key to users.id, nullable)
- pet_coins_amount: numeric (nullable)
- from_franchise_partner_id: uuid (nullable)
- to_franchise_partner_id: uuid (nullable)
- transfer_reason: text (nullable)
```

### 5. **franchise_partners** table
```sql
Columns:
- id: uuid (primary key, auto-generated)
- name: varchar
- location: varchar (nullable)
- contact_email: varchar (nullable)
- contact_phone: varchar (nullable)
- status: varchar (default: 'active')
- created_at: timestamptz (default: now())
- updated_at: timestamptz (default: now())
```

### 6. **pet_coin_price_history** table
```sql
Columns:
- id: uuid (primary key, auto-generated)
- coin_value_rupees: numeric
- previous_value_rupees: numeric (nullable)
- percentage_change: numeric (nullable)
- created_at: timestamptz (default: now())
- updated_at: timestamptz (default: now())
```

## Authentication Flow

### Sign Up Process:
1. Create user in Supabase Auth (auth.users) - **Password stored securely by Supabase**
2. Insert user profile in public.users table (NO password stored here)
3. Create pet coin wallet in pet_coin_wallets table
4. Return user data with token

### Sign In Process:
1. Authenticate with Supabase Auth (password verification handled by Supabase)
2. Fetch user profile from public.users table
3. If user doesn't exist in users table, create them automatically
4. Fetch wallet balance from pet_coin_wallets table
5. Merge data and return user object with token

### Key Points:
- **Passwords are NEVER stored in the public.users table**
- **Supabase Auth handles all password authentication**
- **The public.users table only stores: id, email, role**
- **If a user exists in Supabase Auth but not in public.users, they are automatically created**

## Key Changes Made

### Fixed Issues:
1. **Removed non-existent columns**: The app was trying to use `last_login`, `name`, `pet_coin_balance`, and `is_active` columns that don't exist in the actual database.

2. **Adapted to actual schema**: 
   - Store user data in `users` table with only `id`, `email`, `role`, `password`
   - Store wallet balance in separate `pet_coin_wallets` table
   - Get PET coin price from `pet_coin_settings` table instead of non-existent `pet_coin_prices` table

3. **Data merging**: When fetching user data, we now:
   - Get user profile from `users` table
   - Get wallet balance from `pet_coin_wallets` table
   - Merge both into a single user object for the app

4. **Name handling**: Since the database doesn't have a `name` column, we extract it from the email (part before @) for display purposes.

## App-Database Mapping

| App Field | Database Source | Notes |
|-----------|----------------|-------|
| `id` | users.id | From Supabase Auth |
| `email` | users.email | From Supabase Auth |
| `role` | users.role | Stored in public.users table |
| `name` | Extracted from email | email.split('@')[0] |
| `pet_coin_balance` | pet_coin_wallets.balance | From separate wallet table |
| `is_active` | Hardcoded to `true` | Not stored in database |
| `password` | **NEVER stored** | Handled by Supabase Auth only |
| `created_at` | users.created_at | From public.users table |

## PET Coin Value

The current PET coin value is stored in the `pet_coin_settings` table with the column `coin_value_rupees` (default: 1.00 rupees per PET coin).

## Testing Credentials

You can test the app with your existing user:
- Email: santhoshmrs2004@gmail.com
- Password: (your password)

After signing in, the app will:
1. Authenticate with Supabase Auth
2. Fetch your user profile
3. Fetch your wallet balance
4. Navigate to the appropriate dashboard (Admin or Customer based on role)

