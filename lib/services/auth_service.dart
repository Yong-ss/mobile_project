import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/globals.dart';
import '../utils/theme_manager.dart';

/// Result model for Google Sign-In
class GoogleSignInResult {
  final Map<String, dynamic>? userData; // Existing user data in our 'user' table
  final GoogleSignInAccount? googleMetadata; // Raw Google info for new users
  final bool isNewUser;

  GoogleSignInResult({
    this.userData,
    this.googleMetadata,
    this.isNewUser = false,
  });
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get Client ID from .env
  String get _webClientId => dotenv.get('GOOGLE_WEB_CLIENT_ID');

  /// Sign in with Google and sync with custom 'user' table
  Future<GoogleSignInResult?> signInWithGoogle() async {
    try {
      // 1. Initialize Google Sign-In
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: _webClientId,
      );

      // Force account selection dialog every time
      await googleSignIn.signOut();

      // 2. Trigger native Google Sign-In flow
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      // 3. Obtain auth details
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      // 4. Authenticate with Supabase
      final AuthResponse res = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = res.user;
      if (user == null) throw 'Supabase Auth failed';

      // 5. Sync with custom 'user' table
      final existingUser = await _supabase
          .from('user')
          .select()
          .or('google_uuid.eq.${googleUser.id},email.eq.${googleUser.email}')
          .maybeSingle();

      if (existingUser == null) {
        // This is a NEW user - return Google metadata so the UI can decide next steps
        return GoogleSignInResult(
          googleMetadata: googleUser,
          isNewUser: true,
        );
      } else {
        // Existing user - Update their Google info and return their data
        final updateRes = await _supabase.from('user').update({
          'google_uuid': googleUser.id,
          'google_username': googleUser.displayName,
          'google_email': googleUser.email,
          'google_profile_image': googleUser.photoUrl,
        }).eq('id', existingUser['id']).select().single();

        // Save to Prefs
        await _saveUserDataLocally(updateRes);
        return GoogleSignInResult(userData: updateRes, isNewUser: false);
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Finalize a new Google registration (after optional password setup)
  Future<Map<String, dynamic>> finalizeGoogleRegistration({
    required GoogleSignInAccount googleMetadata,
    String? password,
  }) async {
    // Determine the user.id from Supabase Auth (already signed in)
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) throw 'Not authenticated with Supabase';

    // Auto-generate password if none provided
    final String finalPassword = (password == null || password.isEmpty)
        ? generateSecurePassword()
        : password;

    final userData = await _supabase.from('user').insert({
      'id': authUser.id,
      'username': googleMetadata.displayName ?? googleMetadata.email.split('@')[0],
      'email': googleMetadata.email,
      'password': finalPassword,
      'google_uuid': googleMetadata.id,
      'google_username': googleMetadata.displayName,
      'google_email': googleMetadata.email,
      'google_profile_image': googleMetadata.photoUrl,
      'is_seller': false,
      'customer_verified': true,
      'password_custom': (password != null && password.isNotEmpty),
      'appearance': 0, // 0: system, 1: light, 2: dark
    }).select().single();

    await _saveUserDataLocally(userData);
    return userData;
  }

  /// Generates a random 10-character alphanumeric password
  static String generateSecurePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(10, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _saveUserDataLocally(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userData['id']);
    await prefs.setString('user_email', userData['email']);
    await prefs.setString('user_name', userData['username']);
    currentUser = userData;
  }

  /// Sign out
  Future<void> signOut() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(clientId: _webClientId);
    await googleSignIn.signOut();
    await _supabase.auth.signOut();

    // Clear local state
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    currentUser = null;

    // Reset theme to system for auth screens
    await themeManager.resetToSystem();
  }
}