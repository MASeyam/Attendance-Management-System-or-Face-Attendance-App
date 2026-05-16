import 'dart:math';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import 'student_login_screen.dart';
import 'instructor_login_screen.dart';
import 'admin_login_screen.dart';

// ── Particle model ─────────────────────────────────────────────────────────────
class _Particle {
  final double baseX;  // 0–1 normalized
  final double baseY;
  final double phaseX; // phase offset for sinusoidal drift
  final double phaseY;
  final double driftX; // pixel amplitude
  final double driftY;
  final double radius;
  final double opacity;

  _Particle(Random rng)
      : baseX  = rng.nextDouble(),
        baseY  = rng.nextDouble(),
        phaseX = rng.nextDouble() * 2 * pi,
        phaseY = rng.nextDouble() * 2 * pi,
        driftX = 18 + rng.nextDouble() * 28,
        driftY = 18 + rng.nextDouble() * 28,
        radius = 1.5 + rng.nextDouble() * 1.5,
        opacity = 0.12 + rng.nextDouble() * 0.22;
}

// ── Particle painter ───────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Animation<double> animation;

  _ParticlePainter(this.particles, this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t     = animation.value;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final x = p.baseX * size.width  + sin(t * 2 * pi + p.phaseX) * p.driftX;
      final y = p.baseY * size.height + cos(t * 2 * pi + p.phaseY) * p.driftY;
      paint.color = Colors.white.withAlpha((p.opacity * 255).round());
      canvas.drawCircle(Offset(x, y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// ── Main screen ────────────────────────────────────────────────────────────────
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {

  // Particle animation
  late final AnimationController _particleCtrl;
  late final List<_Particle> _particles;

  // Glow pulse
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  // Typing animation
  static const _fullTagline = 'Your Academic World, At a Glance';
  String _displayText = '';
  bool _showCursor    = true;
  bool _typingDone    = false;
  Timer? _typingTimer;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();

    // Particles – 25 dots drifting sinusoidally (8 second cycle)
    final rng = Random();
    _particles = List.generate(25, (_) => _Particle(rng));
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Glow pulse – 2 second breathe cycle
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 18, end: 38).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Start typing after 800 ms (logo animation finishes)
    Future.delayed(const Duration(milliseconds: 800), _startTyping);
  }

  void _startTyping() {
    if (!mounted) return;
    int index = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) { t.cancel(); return; }
      if (index < _fullTagline.length) {
        setState(() => _displayText = _fullTagline.substring(0, ++index));
      } else {
        t.cancel();
        setState(() => _typingDone = true);
        _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
          if (!mounted) return;
          setState(() => _showCursor = !_showCursor);
        });
      }
    });
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _glowCtrl.dispose();
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  void _navigate(Widget screen) {
    Navigator.push(context, AppTheme.fadeRoute(screen));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: Stack(children: [
        // ── 1. Diagonal dark gradient background ──────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.6, 1.0],
              colors: [
                Color(0xFF0A0E27),
                Color(0xFF0F1C3F),
                Color(0xFF1E3A5F),
              ],
            ),
          ),
        ),

        // ── 2. Floating particles ─────────────────────────────────────────────
        CustomPaint(
          size: Size(size.width, size.height),
          painter: _ParticlePainter(_particles, _particleCtrl),
        ),

        // ── 3. Radial glow at center-top ─────────────────────────────────────
        Positioned(
          top: -80,
          left: size.width / 2 - 160,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x2E4C9BE8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── 4. Content ────────────────────────────────────────────────────────
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo with glow
                  FadeInDown(
                    duration: const Duration(milliseconds: 600),
                    child: AnimatedBuilder(
                      animation: _glowAnim,
                      builder: (_, child) => Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x1F4C9BE8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4C9BE8).withAlpha(
                                  (0.55 * 255).round()),
                              blurRadius: _glowAnim.value,
                              spreadRadius: _glowAnim.value * 0.15,
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0x594C9BE8),
                            width: 1.5,
                          ),
                        ),
                        child: child,
                      ),
                      child: const Icon(
                        Icons.remove_red_eye_rounded,
                        size: 52,
                        color: Color(0xFF4C9BE8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // App name
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    duration: const Duration(milliseconds: 600),
                    child: Text(
                      'ClassEye',
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Typing tagline
                  SizedBox(
                    height: 24,
                    child: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: _displayText,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xD94C9BE8),
                            letterSpacing: 0.3,
                          ),
                        ),
                        TextSpan(
                          text: _showCursor ? '|' : ' ',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF4C9BE8),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Divider — appears after typing
                  if (_typingDone)
                    FadeIn(
                      duration: const Duration(milliseconds: 400),
                      child: Container(
                        width: 60,
                        height: 1,
                        color: const Color(0x804C9BE8),
                      ),
                    )
                  else
                    const SizedBox(height: 1),

                  const SizedBox(height: 44),

                  // Role cards
                  FadeInLeft(
                    delay: const Duration(milliseconds: 1200),
                    duration: const Duration(milliseconds: 400),
                    child: _GlassPill(
                      icon: Icons.school_rounded,
                      iconColor: const Color(0xFF4C9BE8),
                      label: 'Student',
                      onTap: () => _navigate(const StudentLoginScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeInLeft(
                    delay: const Duration(milliseconds: 1400),
                    duration: const Duration(milliseconds: 400),
                    child: _GlassPill(
                      icon: Icons.cast_for_education_rounded,
                      iconColor: const Color(0xFF2ECC71),
                      label: 'Instructor',
                      onTap: () => _navigate(const InstructorLoginScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeInLeft(
                    delay: const Duration(milliseconds: 1600),
                    duration: const Duration(milliseconds: 400),
                    child: _GlassPill(
                      icon: Icons.admin_panel_settings_rounded,
                      iconColor: const Color(0xFFF39C12),
                      label: 'Administrator',
                      onTap: () => _navigate(const AdminLoginScreen()),
                    ),
                  ),

                  const SizedBox(height: 52),

                  // Bottom university text
                  FadeIn(
                    delay: const Duration(milliseconds: 2000),
                    duration: const Duration(milliseconds: 600),
                    child: Text(
                      'FUE — Faculty of Computers & Information Technology',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white.withAlpha(76),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Glassmorphism pill button ──────────────────────────────────────────────────
class _GlassPill extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _GlassPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  State<_GlassPill> createState() => _GlassPillState();
}

class _GlassPillState extends State<_GlassPill> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              width: width,
              height: 65,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withAlpha(38),
                  width: 1,
                ),
              ),
              child: Row(children: [
                const SizedBox(width: 20),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.iconColor.withAlpha(46),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.white.withAlpha(127)),
                const SizedBox(width: 20),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
