import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Your Supabase configuration (same as web app)
  static const String supabaseUrl = 'https://wwagbszbokxhqosintyb.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind3YWdic3pib2t4aHFvc2ludHliIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk1NjI4NTksImV4cCI6MjA3NTEzODg1OX0.K9MQ2WH80Jhbm9lQyZXVDmgcET_srWzChUaK_3OO76c';

  // Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // Get Supabase client
  static SupabaseClient get client => Supabase.instance.client;
}
