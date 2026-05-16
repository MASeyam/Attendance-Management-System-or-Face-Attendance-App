import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_constants.dart';
import '../../core/theme.dart';
import '../instructor/instructor_dashboard_screen.dart';

class InstructorLoginScreen extends StatefulWidget {
  const InstructorLoginScreen({super.key});

  @override
  State<InstructorLoginScreen> createState() => _InstructorLoginScreenState();
}

class _InstructorLoginScreenState extends State<InstructorLoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading    = false;
  bool _obscure    = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.instructorLogin),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':    _emailCtrl.text.trim(),
          'password': _passCtrl.text,
        }),
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (res.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('role',            'instructor');
        await prefs.setInt   ('user_id',         data['id']);
        await prefs.setString('first_name',      data['first_name'] ?? '');
        await prefs.setString('last_name',       data['last_name']  ?? '');
        await prefs.setString('email',           data['email']      ?? '');
        await prefs.setString('instructor_role', data['role']       ?? '');
        await prefs.setInt   ('department_id',   data['department_id'] ?? 0);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          AppTheme.slideRoute(InstructorDashboardScreen(instructorId: data['id'])),
          (_) => false,
        );
      } else {
        _showError(data['message'] ?? 'Login failed');
      }
    } catch (_) {
      _showError('Cannot reach server. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, Color(0xFF2C5282)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeInDown(
                      duration: const Duration(milliseconds: 600),
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.menu_book_rounded,
                              size: 52, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Instructor Login',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Sign in to your account',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 36),
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      duration: const Duration(milliseconds: 500),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(230),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withAlpha(128)),
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: 'Instructor Email',
                                      hintText: 'firstname.lastname@fue.edu.eg',
                                      prefixIcon: Icon(Icons.email_outlined),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Enter your email';
                                      if (!v.contains('@')) return 'Enter a valid email';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passCtrl,
                                    obscureText: _obscure,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined),
                                        onPressed: () =>
                                            setState(() => _obscure = !_obscure),
                                      ),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.isEmpty) ? 'Enter your password' : null,
                                  ),
                                  const SizedBox(height: 24),
                                  GradientButton(
                                    label: 'LOGIN',
                                    icon: Icons.login_rounded,
                                    loading: _loading,
                                    onTap: _login,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
