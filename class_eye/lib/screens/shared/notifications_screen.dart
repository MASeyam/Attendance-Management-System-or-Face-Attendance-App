import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_constants.dart';
import '../../core/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _items = [];
  int _userId  = 0;
  String _role = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id') ?? 0;
    _role   = prefs.getString('role') ?? '';
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res  = await http.get(Uri.parse(ApiConstants.notifications(_userId, _role)));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _items = data['notifications'];
      } else {
        _error = data['message'] ?? 'Failed to load notifications';
      }
    } catch (_) {
      _error = 'Cannot reach server.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(int notifId, int index) async {
    try {
      await http.put(Uri.parse(ApiConstants.markNotificationRead(notifId)));
      if (mounted) setState(() => _items[index]['is_read'] = true);
    } catch (_) {}
  }

  int get _unreadCount => _items.where((n) => n['is_read'] != true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('Notifications'),
          if (!_loading && _unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$_unreadCount',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
      body: _loading
          ? const AppShimmer(count: 6, itemHeight: 80)
          : _error.isNotEmpty
              ? ErrorState(message: _error, onRetry: _fetch)
              : _items.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      message: 'No notifications yet.')
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      color: AppColors.accent,
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final n      = _items[i];
                          final isRead = n['is_read'] == true;
                          return FadeInRight(
                            delay: Duration(milliseconds: 40 * i),
                            duration: const Duration(milliseconds: 200),
                            child: AnimatedOpacity(
                              opacity: isRead ? 0.75 : 1.0,
                              duration: const Duration(milliseconds: 400),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isRead ? null : AppColors.accent.withAlpha(12),
                                  border: Border(
                                    left: BorderSide(
                                      color: isRead
                                          ? Colors.transparent
                                          : AppColors.accent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: isRead
                                        ? Colors.grey.shade200
                                        : AppColors.accent.withAlpha(30),
                                    child: Icon(
                                      Icons.notifications_rounded,
                                      color: isRead ? Colors.grey : AppColors.accent,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(n['title'] ?? '',
                                      style: GoogleFonts.poppins(
                                          fontWeight: isRead
                                              ? FontWeight.normal
                                              : FontWeight.w600,
                                          fontSize: 14,
                                          color: context.clrText)),
                                  subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                    Text(n['body'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: context.clrSubText)),
                                    const SizedBox(height: 4),
                                    Text(n['created_at'] ?? '',
                                        style: GoogleFonts.poppins(
                                            fontSize: 11, color: Colors.grey)),
                                  ]),
                                  isThreeLine: true,
                                  onTap: isRead
                                      ? null
                                      : () => _markRead(n['notification_id'], i),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
