import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class IssueDetailScreen extends StatelessWidget {
  final Map<String, dynamic> issue;
  const IssueDetailScreen({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    final status     = issue['status'] ?? 'pending';
    final isPending  = status == 'pending';
    final isAccepted = status == 'accepted';
    final verdictColor = isPending
        ? AppColors.warning
        : isAccepted
            ? AppColors.success
            : AppColors.danger;

    return Scaffold(
      appBar: AppBar(title: const Text('Issue Detail')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: _InfoCard(title: 'Session', children: [
              _Row(label: 'Course',    value: issue['course_name']   ?? ''),
              _Row(label: 'Session',   value: issue['session_start'] ?? ''),
              _Row(label: 'Submitted', value: issue['submitted_at']  ?? ''),
            ]),
          ),
          const SizedBox(height: 12),
          FadeInDown(
            delay: const Duration(milliseconds: 80),
            child: _InfoCard(title: 'Your Message', children: [
              Text(issue['reason'] ?? '',
                  style: GoogleFonts.poppins(
                      fontSize: 14, height: 1.6, color: context.clrText)),
            ]),
          ),
          const SizedBox(height: 12),
          FadeInDown(
            delay: const Duration(milliseconds: 160),
            child: _InfoCard(title: 'Doctor Response', children: [
              if (isPending)
                _VerdictBadge(
                  icon: Icons.hourglass_top_rounded,
                  label: 'Awaiting response',
                  color: AppColors.warning,
                )
              else ...[
                _VerdictBadge(
                  icon: isAccepted
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  label: isAccepted ? 'Accepted' : 'Declined',
                  color: verdictColor,
                ),
                if ((issue['instructor_reply'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: verdictColor.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: verdictColor.withAlpha(50)),
                    ),
                    child: Text(
                      issue['instructor_reply'] ?? '',
                      style: GoogleFonts.poppins(
                          fontSize: 14, height: 1.6, color: context.clrText),
                    ),
                  ),
                ],
                if ((issue['handled_at'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Responded on: ${issue['handled_at']}',
                    style: GoogleFonts.poppins(
                        color: context.clrSubText, fontSize: 11),
                  ),
                ],
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _VerdictBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _VerdictBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.poppins(
                color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

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
          width: 80,
          child: Text('$label:',
              style: GoogleFonts.poppins(
                  color: context.clrSubText, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: context.clrText)),
        ),
      ]),
    );
  }
}
