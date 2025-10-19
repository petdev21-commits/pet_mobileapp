# Pet Coin Mobile App

Flutter mobile application for the Pet Coin cryptocurrency platform.

## Features

- **Authentication**: Sign up and sign in with backend API
- **User Management**: Profile management and user search
- **Pet Coin Transactions**: Send, receive, and track Pet Coin transactions
- **Real-time Data**: Live Pet Coin price updates
- **Secure Storage**: JWT token and user data persistence

## Setup

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Backend Configuration

Update the API base URL in `lib/config/api_config.dart`:

```dart
static const String baseUrl = 'http://YOUR_IP_ADDRESS:3000/api';
```

**Important**: Replace `localhost` with your computer's actual IP address for mobile testing.

### 3. Backend Server

Make sure your Next.js backend server is running:

```bash
cd ../backend
npm install
npm run dev
```

The backend should be running on `http://localhost:3000`

### 4. Database Setup

Ensure your Supabase database is set up with the required tables:

- `users` table
- `transactions` table  
- `pet_coin_prices` table

### 5. Run the App

```bash
flutter run
```

## API Integration

The app connects to the Next.js backend API with the following endpoints:

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/register` - User registration

### User Management
- `GET /api/users/profile` - Get user profile
- `GET /api/users/search` - Search users

### Transactions
- `GET /api/transactions` - Get user transactions
- `POST /api/transactions` - Create transaction

### Pet Coin
- `GET /api/pet-coin/price` - Get current price
- `POST /api/pet-coin/price` - Update price (admin)

## File Structure

```
lib/
├── config/
│   └── api_config.dart          # API configuration
├── models/
│   └── user.dart               # User data models
├── services/
│   ├── api_service.dart        # API communication
│   └── auth_service.dart       # Authentication logic
├── signin.dart                 # Sign in page
├── signup.dart                 # Sign up page
└── main.dart                   # App entry point
```

## Dependencies

- `http`: HTTP client for API calls
- `shared_preferences`: Local storage for auth tokens
- `provider`: State management (optional)

## Development Notes

### Network Configuration

For mobile testing, you need to use your computer's IP address instead of `localhost`:

1. Find your IP address:
   - Windows: `ipconfig`
   - Mac/Linux: `ifconfig`

2. Update `api_config.dart`:
   ```dart
   static const String baseUrl = 'http://192.168.1.100:3000/api';
   ```

### CORS Configuration

The backend is configured with CORS headers to allow mobile app requests.

### Error Handling

The app includes comprehensive error handling for:
- Network connectivity issues
- API response errors
- Form validation
- Authentication failures

## Testing

1. Start the backend server
2. Update the API URL with your IP address
3. Run the Flutter app
4. Test sign up and sign in functionality

## Troubleshooting

### Common Issues

1. **Connection Refused**: Check if backend server is running
2. **CORS Errors**: Ensure backend CORS is configured
3. **Network Unreachable**: Use IP address instead of localhost
4. **Authentication Errors**: Check Supabase configuration

### Debug Steps

1. Check backend server logs
2. Verify API endpoints are accessible
3. Test API calls with Postman/curl
4. Check Flutter console for errors