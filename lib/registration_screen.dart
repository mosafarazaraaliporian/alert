import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import 'home_screen.dart';
import 'api_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _chatIdController = TextEditingController();
  String? _fcmToken;
  String? _deviceId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    print('=== Registration Screen InitState ===');
    _initializeData();
  }

  Future<void> _initializeData() async {
    print('=== Starting Data Initialization ===');
    await _getFCMToken();
    await _getDeviceId();
    print('=== Data Initialization Complete ===');
  }

  Future<void> _getFCMToken() async {
    print('=== Getting FCM Token ===');
    try {
      final messaging = FirebaseMessaging.instance;
      print('FirebaseMessaging instance created');
      
      // Request permission first
      print('Requesting notification permission...');
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      print('Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get token with longer timeout
        print('Getting FCM token...');
        final fcmToken = await messaging.getToken().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('FCM Token request timed out after 30 seconds');
            return null;
          },
        );
        
        print('FCM Token retrieved: $fcmToken');
        
        if (fcmToken != null && fcmToken.isNotEmpty) {
          setState(() {
            _fcmToken = fcmToken;
          });
          
          // Listen for token refresh
          messaging.onTokenRefresh.listen((newToken) {
            print('FCM Token refreshed: $newToken');
            setState(() {
              _fcmToken = newToken;
            });
            // Update token on server
            _updateTokenOnServer(newToken);
          });
        } else {
          print('FCM Token is null or empty');
          setState(() {
            _fcmToken = 'unavailable';
          });
        }
      } else {
        print('Notification permission denied');
        setState(() {
          _fcmToken = 'permission_denied';
        });
      }
    } catch (e, stackTrace) {
      print('=== ERROR getting FCM token ===');
      print('Error: $e');
      print('StackTrace: $stackTrace');
      setState(() {
        _fcmToken = 'error';
      });
    }
  }

  Future<void> _updateTokenOnServer(String newToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatId = prefs.getString('chat_id');
      final deviceId = _deviceId;
      
      if (chatId != null && deviceId != null) {
        await ApiService.registerUser(
          chatId: chatId,
          fcmToken: newToken,
          deviceId: deviceId,
        );
        print('✅ Token updated on server');
      }
    } catch (e) {
      print('⚠️ Failed to update token on server: $e');
    }
  }

  Future<void> _retryGetToken() async {
    setState(() {
      _fcmToken = null;
    });
    await _getFCMToken();
  }

  Future<void> _getDeviceId() async {
    print('=== Getting Device ID ===');
    try {
      final deviceInfo = DeviceInfoPlugin();
      String? deviceId;
      
      if (Platform.isAndroid) {
        print('Platform: Android');
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        print('Android Device ID: $deviceId');
      } else if (Platform.isIOS) {
        print('Platform: iOS');
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor;
        print('iOS Device ID: $deviceId');
      }
      
      setState(() {
        _deviceId = deviceId;
      });
      print('Device ID set successfully');
    } catch (e, stackTrace) {
      print('=== ERROR getting device ID ===');
      print('Error: $e');
      print('StackTrace: $stackTrace');
    }
  }

  Future<void> _handleNext() async {
    if (_chatIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Telegram Chat ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check FCM token status
    if (_fcmToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, getting notification token...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_fcmToken == 'error' || _fcmToken == 'unavailable') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please click Retry to get notification token'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_fcmToken == 'permission_denied') {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Notification Permission Required'),
          content: const Text(
            'This app needs notification permission to send you alerts. Please enable notifications in your device settings and try again.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
                _retryGetToken();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
      
      if (shouldContinue != true) return;
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Register with API
      print('=== Registering with API ===');
      final response = await ApiService.registerUser(
        chatId: _chatIdController.text.trim(),
        fcmToken: _fcmToken!,
        deviceId: _deviceId ?? 'unknown',
      );
      
      print('API Response: $response');

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_id', _chatIdController.text.trim());
      await prefs.setString('fcm_token', _fcmToken!);
      await prefs.setString('device_id', _deviceId ?? '');
      await prefs.setBool('is_registered', true);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to Home Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      print('=== Registration Error ===');
      print('Error: $e');
      
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Registration',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Chat ID Input
                TextField(
                  controller: _chatIdController,
                  decoration: InputDecoration(
                    labelText: 'Telegram Chat ID',
                    hintText: '@username',
                    prefixIcon: Icon(Icons.telegram, color: Colors.deepPurple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.deepPurple),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.deepPurple.withOpacity(0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                    ),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 24),
                
                // FCM Token Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications, color: Colors.deepPurple, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'FCM Token:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const Spacer(),
                          if (_fcmToken == 'error' || _fcmToken == 'unavailable')
                            TextButton.icon(
                              onPressed: _retryGetToken,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fcmToken == null 
                            ? 'Loading...'
                            : _fcmToken == 'error'
                                ? '⚠️ Error getting token'
                                : _fcmToken == 'unavailable'
                                    ? '⚠️ Token unavailable'
                                    : _fcmToken == 'permission_denied'
                                        ? '⚠️ Permission denied'
                                        : _fcmToken!.length > 50
                                            ? '${_fcmToken!.substring(0, 50)}...'
                                            : _fcmToken!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _fcmToken == 'error' || _fcmToken == 'unavailable' || _fcmToken == 'permission_denied'
                              ? Colors.orange
                              : isDark ? Colors.white70 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_fcmToken == 'error' || _fcmToken == 'unavailable' || _fcmToken == 'permission_denied')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '⚠️ Click Retry button to get notification token. Required for push notifications.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Device ID Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.phone_android, color: Colors.deepPurple, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Device ID:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _deviceId ?? 'Loading...',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                
                // Next Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _chatIdController.dispose();
    super.dispose();
  }
}
