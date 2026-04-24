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
  static const String adminEmail = 'admin';
  static const String adminPass = 'admin';

  /// Seeds the standard admin account for testing/system use
  Future<void> seedAdminAccount() async {
    try {
      // Check if admin already exists first
      // This prevents overwriting user-modified data (like Display Name) on every app start
      final existing = await _supabase
          .from('user')
          .select('id')
          .eq('email', adminEmail)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('user').insert({
          'email': adminEmail,
          'password': adminPass,
          'username': 'System Admin',
          'role': 'admin',
          'customer_verified': true,
          'appearance': 0, // 0: system
        });
        debugPrint('Admin account seeded successfully.');
      }
    } catch (e) {
      debugPrint('Admin seeding info: $e');
    }
  }

  /// Sign in with Email and Password (Hybrid System)
  Future<Map<String, dynamic>> signInWithPassword(String email, String password) async {
    try {
      // 1. Try the REAL official Supabase Auth first
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;
      if (user == null) throw 'Login failed';

      // Fetch synced data from public.user
      final userData = await _supabase
          .from('user')
          .select()
          .eq('id', user.id)
          .single();

      await _saveUserDataLocally(userData);
      return userData;
    } catch (e) {
      // 2. FALLBACK: Check your MANUAL table for test users like 'try@'
      final legacyUser = await _supabase
          .from('user')
          .select()
          .eq('email', email)
          .eq('password', password) // Manual plaintext check for testing
          .maybeSingle();

      if (legacyUser != null) {
        await _saveUserDataLocally(legacyUser);
        return legacyUser;
      }

      // If both fail, rethrow the original error
      rethrow;
    }
  }

  /// Sign up with Email and Password (Real System)
  Future<void> signUpWithPassword({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      // 1. First, check if they exist in your MANUAL table
      final existingManual = await _supabase
          .from('user')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (existingManual != null) {
        throw 'User already exists in the system. Please login.';
      }

      // 2. GHOST CLEANUP:
      // Call the database function to wipe them from auth.users if they are missing from public.user
      await _supabase.rpc('cleanup_ghost_user', params: {'email_to_check': email});

      // 3. Try the official Sign Up
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'password': password,
        },
      );

      final user = res.user;
      if (user != null) {
        // Sync the password to our custom 'user' table immediately.
        // Even if email confirmation is required, the public.user record is often created by a trigger
        // the moment auth.signUp is called. We update it here to ensure the password field isn't NULL.
        try {
          await _supabase.from('user').update({
            'password': password,
            'password_custom': true,
          }).eq('id', user.id);
          debugPrint('Manual password sync to public.user successful.');
        } catch (e) {
          // If this fails (e.g. RLS or trigger delay), we don't block the user.
          // The trigger might still catch it or they can set it later.
          debugPrint('Post-signup public.user sync info: $e');
        }
      }
    } on AuthException catch (e) {
      if (e.code == 'user_already_exists') {
        throw 'This email is already registered. Please login or use a different email.';
      }
      rethrow;
    }
  }

  /// Send Real Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.supabase.flutter://reset-callback/',
    );
  }

  /// Verify 6-digit OTP for password reset
  Future<void> verifyPasswordResetOTP(String email, String token) async {
    await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
    );
  }

  /// Update password (called after recovery redirect or manual reset)
  Future<void> updatePassword(String newPassword, {String? email}) async {
    // 1. Try to update the REAL official system if a session exists
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      // If session is missing (common for legacy test users like try@),
      // we ignore this and rely on the manual table update below.
      debugPrint('Supabase Auth Update skipped: $e');
    }

    // 2. Update the MANUAL table
    // Use the provided email if session is missing
    final authUser = _supabase.auth.currentUser;
    final String? targetId = authUser?.id;
    final String? targetEmail = email ?? authUser?.email;

    if (targetId != null) {
      await _supabase
          .from('user')
          .update({'password': newPassword})
          .eq('id', targetId);
    } else if (targetEmail != null) {
      // Fallback for legacy accounts (like try@) that don't have a Supabase Auth entry
      await _supabase
          .from('user')
          .update({'password': newPassword})
          .eq('email', targetEmail);
    } else {
      throw 'No user session or email found to update password.';
    }
  }

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

      // 4. PRE-CHECK: See if user exists in public.user BEFORE we authenticate.
      // We do this because our database trigger will automatically create the public record
      // the moment signInWithIdToken succeeds, which would trick us into thinking they are an existing user.
      final existingUserPre = await _supabase
          .from('user')
          .select()
          .or('google_uuid.eq.${googleUser.id},email.eq.${googleUser.email}')
          .maybeSingle();

      // 5. Authenticate with Supabase
      final AuthResponse res = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = res.user;
      if (user == null) throw 'Supabase Auth failed';

      if (existingUserPre == null) {
        // This is a NEW user - return Google metadata so the UI can decide next steps
        return GoogleSignInResult(
          googleMetadata: googleUser,
          isNewUser: true,
        );
      } else {
        // Existing user found (from before this call)
        // Update their info with latest Google details
        final updateRes = await _supabase.from('user').update({
          'id': user.id, // Upgrade to the real official Auth ID
          'google_uuid': googleUser.id,
          'google_username': googleUser.displayName,
          'google_email': googleUser.email,
          'google_profile_image': googleUser.photoUrl,
        }).eq('id', existingUserPre['id']).select().single();

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

    // IMPORTANT: Sync the password with Supabase Auth so traditional login works later
    await _supabase.auth.updateUser(UserAttributes(password: finalPassword));

    final userData = await _supabase.from('user').upsert({
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