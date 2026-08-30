import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/ceylon_theme.dart';
import 'driver_dashboard_screen.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    
    setState(() => _isLoading = true);
    
    // Simulate network request
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DriverDashboardScreen()),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverDashboardScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Google sign-in failed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google sign-in failed. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: CeylonSpiceTheme.darkBg,
      appBar: AppBar(
        backgroundColor: CeylonSpiceTheme.deepJungle,
        elevation: 0,
        title: Text(
          'Driver Portal',
          style: GoogleFonts.playfairDisplay(color: CeylonSpiceTheme.textPrimary),
        ),
        iconTheme: const IconThemeData(color: CeylonSpiceTheme.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height - MediaQuery.of(context).padding.top - kToolbarHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // ── Brand header ─────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [CeylonSpiceTheme.deepJungle, CeylonSpiceTheme.darkBg],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [CeylonSpiceTheme.saffron, CeylonSpiceTheme.cinnamon],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: CeylonSpiceTheme.saffron.withOpacity(0.35),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.directions_car, size: 36, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Driver Dashboard',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: CeylonSpiceTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to manage your tours',
                          style: GoogleFonts.lato(fontSize: 13, color: CeylonSpiceTheme.saffron),
                        ),
                      ],
                    ),
                  ),

                  // ── Form ─────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Email / Driver ID',
                                prefixIcon: const Icon(Icons.person_outline),
                                filled: true,
                                fillColor: CeylonSpiceTheme.darkCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Enter a valid ID or email' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                filled: true,
                                fillColor: CeylonSpiceTheme.darkCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CeylonSpiceTheme.cinnamon,
                                  foregroundColor: CeylonSpiceTheme.coconutCream,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: _isLoading ? null : _submit,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text(
                                        'Sign In',
                                        style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // ── Divider ──────────────────────────
                            Row(
                              children: [
                                const Expanded(child: Divider(color: Colors.white24)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'or',
                                    style: GoogleFonts.lato(
                                      color: Colors.white38,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider(color: Colors.white24)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // ── Continue with Google ─────────────
                            SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: CeylonSpiceTheme.textPrimary,
                                  side: const BorderSide(color: Colors.white24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: CeylonSpiceTheme.darkCard,
                                ),
                                onPressed: (_isLoading || _isGoogleLoading) ? null : _signInWithGoogle,
                                icon: _isGoogleLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white70,
                                        ),
                                      )
                                    : Image.network(
                                        'https://www.google.com/favicon.ico',
                                        height: 20,
                                        width: 20,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.g_mobiledata, size: 24),
                                      ),
                                label: Text(
                                  'Continue with Google',
                                  style: GoogleFonts.lato(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
