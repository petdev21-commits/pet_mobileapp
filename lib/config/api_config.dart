class ApiConfig {
  // Update this URL to match your backend server
  // For development, use your computer's IP address instead of localhost
  // Example: 'http://192.168.1.100:3000/api' (replace with your actual IP)
  static const String baseUrl = 'http://localhost:3000/api';
  
  // Alternative URLs for different environments
  static const String devUrl = 'http://localhost:3000/api';
  static const String prodUrl = 'https://your-production-domain.com/api';
  
  // Timeout settings
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
  
  // Get the appropriate URL based on environment
  static String get apiUrl {
    // You can add environment detection logic here
    // For now, using dev URL
    return devUrl;
  }
}
