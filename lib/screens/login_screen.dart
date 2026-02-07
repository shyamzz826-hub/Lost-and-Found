import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;
      if (user == null) return;

      // ✅ SAVE USER PROFILE (NAME + PHOTO) TO REALTIME DB
      await FirebaseDatabase.instance.ref('users/${user.uid}').update({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'lastLogin': ServerValue.timestamp,
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login failed. Try again.')));
    }
  }

  void _showAppInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Center(
                child: Text(
                  'Lost & Found',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 12),
              Divider(),
              Text('Version: 1.0.0'),
              SizedBox(height: 14),
              Text('Features', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('• Google Authentication'),
              Text('• Lost & Found Posts'),
              Text('• Image & Text Posts'),
              Text('• Search Posts'),
              Text('• My Posts (Edit/Delete)'),
              Text('• Real-time Chat'),
              Text('• Chat Inbox'),
              Text('• Firebase Realtime Sync'),
              SizedBox(height: 14),
              Text('Built With', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('• Flutter'),
              Text('• Firebase Authentication'),
              Text('• Firebase Realtime Database'),
              Text('• Firebase Storage'),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 96,
                      width: 96,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const Icon(
                        Icons.find_in_page,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Lost & Found',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Help items find their way back home',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 46),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.login, color: Colors.white),
                        label: const Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () => _signInWithGoogle(context),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'By continuing, you agree to our terms & privacy policy',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showAppInfo(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
