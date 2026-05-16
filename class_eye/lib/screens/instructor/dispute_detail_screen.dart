import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_constants.dart';
import '../../core/theme.dart';

class IssueDetailScreen extends StatefulWidget {
  final Map<String, dynamic> issue;
  const IssueDetailScreen({super.key, required this.issue});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  final _replyCtrl  = TextEditingController();
  bool _submitting  = false;
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _confetti.dispose();
    super.dispose();
  }

  bool get _isPending =>
      (widget.issue['status'] ?? '') == 'pending';

  Future<void> _respond(String verdict) async {
    setState(() => _submitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final myId  = prefs.getInt('user_id') ?? 0;
      final issueId = widget.issue['issue_id'] ?? widget.issue['dispute_id'];
      final res = await http.put(
        Uri.parse(ApiConstants.handleIssue(issueId)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'verdict':          verdict,
          'instructor_reply': _replyCtrl.text.trim(),
          'handled_by':       myId,
        }),
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['success'] == true) {
        _confetti.play();
        await Future.delayed(const Duration(milliseconds: 2200));
        if (!mounted) return;
        Navigator.pop(context);
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d          = widget.issue;
    final status     = d['status'] ?? 'pending';
    final isAccepted = status == 'accepted';
    final verdictColor = isAccepted ? AppColors.success : AppColors.danger;

    return Scaffold(
      appBar: AppBar(title: const Text('Issue Detail')),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 28,
              gravity: 0.1,
              colors: const [
                AppColors.success, AppColors.accent,
                AppColors.warning,  Colors.pinkAccent,
              ],
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Student info ──────────────────────────────────────────────
              FadeInDown(
                duration: const Duration(milliseconds: 400),
                child: _InfoCard(title: 'Student', children: [
                  _Row(label: 'Name', value: d['student_name'] ?? ''),
                  _Row(label: 'ID',   value: '${d['student_id'] ?? ''}'),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Session info ──────────────────────────────────────────────
              FadeInDown(
                delay: const Duration(milliseconds: 80),
                child: _InfoCard(title: 'Session', children: [
                  _Row(label: 'Course',    value: d['course_name']   ?? ''),
                  _Row(label: 'Date',      value: d['session_start'] ?? ''),
                  _Row(label: 'Submitted', value: d['submitted_at']  ?? ''),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Student message ───────────────────────────────────────────
              FadeInDown(
                delay: const Duration(milliseconds: 160),
                child: _InfoCard(title: 'Student Message', children: [
                  Text(d['reason'] ?? '',
                      style: GoogleFonts.poppins(
                          fontSize: 14, height: 1.6, color: context.clrText)),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Response section ──────────────────────────────────────────
              if (_isPending) ...[
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: _InfoCard(title: 'Your Response (optional)', children: [
                    TextFormField(
                      controller: _replyCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Add a note for the student…',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                FadeInUp(
                  delay: const Duration(milliseconds: 260),
                  child: Row(children: [
                    Expanded(
                      child: _VerdictButton(
                        label: 'Accept',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                        loading: _submitting,
                        onTap: () => _respond('accepted'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _VerdictButton(
                        label: 'Decline',
                        icon: Icons.cancel_rounded,
                        color: AppColors.danger,
                        loading: _submitting,
                        onTap: () => _respond('declined'),
                      ),
                    ),
                  ]),
                ),
              ] else ...[
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: _InfoCard(title: 'Your Response', children: [
                    // Verdict badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: verdictColor.withAlpha(22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: verdictColor.withAlpha(80)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          isAccepted
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: verdictColor, size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAccepted ? 'Accepted' : 'Declined',
                          style: GoogleFonts.poppins(
                              color: verdictColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ]),
                    ),
                    if ((d['instructor_reply'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: verdictColor.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: verdictColor.withAlpha(50)),
                        ),
                        child: Text(d['instructor_reply'] ?? '',
                            style: GoogleFonts.poppins(
                                fontSize: 14, height: 1.6,
                                color: context.clrText)),
                      ),
                    ],
                    if ((d['handled_at'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Handled at: ${d['handled_at']}',
                          style: GoogleFonts.poppins(
                              color: context.clrSubText, fontSize: 12)),
                    ],
                  ]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Verdict button ────────────────────────────────────────────────────────────
class _VerdictButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _VerdictButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  State<_VerdictButton> createState() => _VerdictButtonState();
}

class _VerdictButtonState extends State<_VerdictButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        if (!widget.loading) widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: widget.color.withAlpha(77),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: widget.loading
              ? const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(widget.icon, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(widget.label,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ]),
        ),
      ),
    );
  }
}

// ── Shared info-card widgets ──────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 13,
                  color: AppColors.accent, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 10),
          ...children,
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 90,
          child: Text('$label:',
              style: GoogleFonts.poppins(
                  color: context.clrSubText, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.clrText)),
        ),
      ]),
    );
  }
}
