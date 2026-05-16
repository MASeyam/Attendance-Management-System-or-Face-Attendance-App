import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/api_constants.dart';
import '../../core/theme.dart';
import 'add_instructor_screen.dart';

class InstructorListScreen extends StatefulWidget {
  const InstructorListScreen({super.key});

  @override
  State<InstructorListScreen> createState() => _InstructorListScreenState();
}

class _InstructorListScreenState extends State<InstructorListScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _all      = [];
  List<dynamic> _filtered = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res  = await http.get(Uri.parse(ApiConstants.instructors));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _all      = data['instructors'];
        _filtered = List.from(_all);
      } else {
        _error = data['message'] ?? 'Failed to load instructors';
      }
    } catch (_) {
      _error = 'Cannot reach server.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((i) {
        final name  = '${i['first_name']} ${i['last_name']}'.toLowerCase();
        final email = (i['email'] ?? '').toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    });
  }

  Future<void> _delete(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete $name? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res  = await http.delete(Uri.parse(ApiConstants.deleteInstructor(id)));
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Instructor deleted'),
              backgroundColor: AppColors.success),
        );
        _fetch();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? 'Delete failed'),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instructors')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
              context, AppTheme.slideRoute(const AddInstructorScreen()));
          _fetch();
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Instructor'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search by name or email',
              prefixIcon: Icon(Icons.search_rounded),
              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
        ),
        Expanded(child: _buildList()),
      ]),
    );
  }

  Widget _buildList() {
    if (_loading) return const AppShimmer(count: 8, itemHeight: 72);
    if (_error.isNotEmpty) return ErrorState(message: _error, onRetry: _fetch);
    if (_filtered.isEmpty) {
      return const EmptyState(
          icon: Icons.person_off_rounded, message: 'No instructors found.');
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      color: AppColors.accent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) {
          final ins = _filtered[i];
          return FadeInLeft(
            delay: Duration(milliseconds: 30 * i),
            duration: const Duration(milliseconds: 200),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accent.withAlpha(28),
                  child: Text(
                    '${ins['first_name'] ?? '?'}'[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                        color: AppColors.accent, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text('${ins['first_name']} ${ins['last_name']}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  '${ins['role'] ?? ''}  •  ${ins['email'] ?? ''}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: context.clrSubText),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger),
                  onPressed: () =>
                      _delete(ins['id'], '${ins['first_name']} ${ins['last_name']}'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
