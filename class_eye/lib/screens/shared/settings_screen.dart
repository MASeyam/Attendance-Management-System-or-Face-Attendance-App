import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../auth/role_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _followSystem = true;
  bool _isDark       = false;

  @override
  void initState() {
    super.initState();
    final mode = themeNotifier.value;
    _followSystem = mode == ThemeMode.system;
    _isDark       = mode == ThemeMode.dark;
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    themeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', switch (mode) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      AppTheme.slideRoute(const RoleSelectionScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        _sectionHeader(context, 'Appearance'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            SwitchListTile(
              title: Text('Follow Device Theme',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: context.clrText)),
              subtitle: Text(
                  'Automatically match your system theme',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: context.clrSubText)),
              secondary: Icon(Icons.brightness_auto_rounded,
                  color: context.clrAccent),
              activeColor: context.clrAccent,
              value: _followSystem,
              onChanged: (v) {
                setState(() => _followSystem = v);
                _saveTheme(v ? ThemeMode.system : (_isDark ? ThemeMode.dark : ThemeMode.light));
              },
            ),
            if (!_followSystem) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: _ThemeChoice(
                      icon: Icons.light_mode_rounded,
                      label: 'Light',
                      selected: !_isDark,
                      onTap: () {
                        setState(() => _isDark = false);
                        _saveTheme(ThemeMode.light);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ThemeChoice(
                      icon: Icons.dark_mode_rounded,
                      label: 'Dark',
                      selected: _isDark,
                      onTap: () {
                        setState(() => _isDark = true);
                        _saveTheme(ThemeMode.dark);
                      },
                    ),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        _sectionHeader(context, 'Account'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: Text('Logout',
                style: GoogleFonts.poppins(
                    color: AppColors.danger, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.danger),
            onTap: _logout,
          ),
        ),
        _sectionHeader(context, 'About'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            ListTile(
              leading: Icon(Icons.info_outline_rounded, color: context.clrAccent),
              title: Text('App Version',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500, color: context.clrText)),
              trailing: Text('1.0.0',
                  style: GoogleFonts.poppins(color: context.clrSubText)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.school_rounded, color: context.clrAccent),
              title: Text('ClassEye — AMS',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500, color: context.clrText)),
              subtitle: Text('Future University in Egypt',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: context.clrSubText)),
            ),
          ]),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
            color: context.clrSubText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.clrAccent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withAlpha(25) : context.clrBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? accent : context.clrBorder, width: 1.5),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? accent : context.clrSubText, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? accent : context.clrSubText)),
        ]),
      ),
    );
  }
}
