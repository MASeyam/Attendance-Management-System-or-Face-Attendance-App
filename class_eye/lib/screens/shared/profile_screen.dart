import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_constants.dart';
import '../../core/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _data = {};
  String _role = '';
  bool _changingPassword = false;
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('role') ?? '';
      _data = {
        'user_id':         prefs.getInt('user_id') ?? 0,
        'first_name':      prefs.getString('first_name') ?? '',
        'last_name':       prefs.getString('last_name')  ?? '',
        'full_name':       prefs.getString('full_name')  ?? '',
        'username':        prefs.getString('username')   ?? '',
        'email':           prefs.getString('email')      ?? '',
        'level':           prefs.getInt('level')         ?? 0,
        'group_name':      prefs.getString('group_name') ?? '',
        'gpa':             prefs.getDouble('gpa')        ?? 0.0,
        'instructor_role': prefs.getString('instructor_role') ?? '',
        'admin_role':      prefs.getString('admin_role')      ?? '',
      };
    });
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _changingPassword = true);
    try {
      final res = await http.put(
        Uri.parse(ApiConstants.changePassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id':      _data['user_id'],
          'role':         _role,
          'old_password': _oldPassCtrl.text,
          'new_password': _newPassCtrl.text,
        }),
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['success'] == true) {
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password changed successfully'),
              backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? 'Failed'),
              backgroundColor: AppColors.danger),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot reach server.'),
            backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  String get _displayName {
    if (_role == 'admin') {
      final full = _data['full_name'] as String;
      return full.isNotEmpty ? full : _data['username'];
    }
    return '${_data['first_name']} ${_data['last_name']}';
  }

  IconData get _roleIcon {
    switch (_role) {
      case 'student':    return Icons.person_rounded;
      case 'instructor': return Icons.menu_book_rounded;
      default:           return Icons.admin_panel_settings_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: Center(
              child: Column(children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent]),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withAlpha(70),
                          blurRadius: 14,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.transparent,
                    child: Icon(_roleIcon, size: 48, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 14),
                Text(_displayName,
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.clrText)),
                Text(_role.toUpperCase(),
                    style: GoogleFonts.poppins(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        fontSize: 12)),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: _InfoCard(role: _role, data: _data),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Text('Change Password',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.clrText)),
          ),
          const SizedBox(height: 14),
          FadeInUp(
            delay: const Duration(milliseconds: 250),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _passField(_oldPassCtrl, 'Current Password'),
                    const SizedBox(height: 14),
                    _passField(_newPassCtrl, 'New Password'),
                    const SizedBox(height: 14),
                    _passField(_confirmCtrl, 'Confirm New Password'),
                    const SizedBox(height: 18),
                    GradientButton(
                      label: 'Update Password',
                      icon: Icons.lock_reset_rounded,
                      loading: _changingPassword,
                      onTap: _changePassword,
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

  Widget _passField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String role;
  final Map<String, dynamic> data;
  const _InfoCard({required this.role, required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = <_Row>[];
    if (role == 'student') {
      rows.addAll([
        _Row('ID',    '${data['user_id']}'),
        _Row('Email', data['email']),
        _Row('Level', '${data['level']}'),
        _Row('Group', data['group_name']),
        _Row('GPA',   (data['gpa'] as double).toStringAsFixed(2)),
      ]);
    } else if (role == 'instructor') {
      rows.addAll([
        _Row('Email', data['email']),
        _Row('Role',  data['instructor_role']),
      ]);
    } else {
      rows.addAll([
        _Row('Username', data['username']),
        _Row('Email',    data['email']),
        _Row('Role',     data['admin_role']),
      ]);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: rows.asMap().entries.map((e) => Column(children: [
            if (e.key > 0) const Divider(height: 16),
            Row(children: [
              SizedBox(
                width: 90,
                child: Text(e.value.label,
                    style: GoogleFonts.poppins(
                        color: context.clrSubText, fontSize: 13)),
              ),
              Expanded(
                child: Text(e.value.value,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: context.clrText)),
              ),
            ]),
          ])).toList(),
        ),
      ),
    );
  }
}

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}
