import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

// ── Static color palette ───────────────────────────────────────────────────────
class AppColors {
  // Light mode (also used as semantic constants)
  static const Color primary       = Color(0xFF1E3A5F);
  static const Color accent        = Color(0xFF4C9BE8);
  static const Color success       = Color(0xFF2ECC71);
  static const Color warning       = Color(0xFFF39C12);
  static const Color danger        = Color(0xFFE74C3C);
  static const Color background    = Color(0xFFF5F7FA);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color textPrimary   = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);

  // Dark mode
  static const Color darkBackground    = Color(0xFF0D1117);
  static const Color darkSurface       = Color(0xFF161B22);
  static const Color darkCard          = Color(0xFF21262D);
  static const Color darkBorder        = Color(0xFF30363D);
  static const Color darkPrimary       = Color(0xFF4C9BE8);
  static const Color darkAccent        = Color(0xFF58A6FF);
  static const Color darkTextPrimary   = Color(0xFFE6EDF3);
  static const Color darkTextSecondary = Color(0xFF8B949E);
}

// ── Theme-aware color extension on BuildContext ────────────────────────────────
extension AppColorsExt on BuildContext {
  bool get _dk => Theme.of(this).brightness == Brightness.dark;

  Color get clrPrimary  => _dk ? AppColors.darkPrimary  : AppColors.primary;
  Color get clrAccent   => _dk ? AppColors.darkAccent   : AppColors.accent;
  Color get clrBg       => _dk ? AppColors.darkBackground : AppColors.background;
  Color get clrSurf     => _dk ? AppColors.darkSurface  : AppColors.surface;
  Color get clrCard     => _dk ? AppColors.darkCard     : AppColors.surface;
  Color get clrBorder   => _dk ? AppColors.darkBorder   : const Color(0xFFE5E7EB);
  Color get clrText     => _dk ? AppColors.darkTextPrimary   : AppColors.textPrimary;
  Color get clrSubText  => _dk ? AppColors.darkTextSecondary : AppColors.textSecondary;
}

// ── Theme factory ──────────────────────────────────────────────────────────────
class AppTheme {
  // ─── Light theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: GoogleFonts.poppins().fontFamily,
    textTheme: GoogleFonts.poppinsTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: GoogleFonts.poppins(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    cardTheme: const CardTheme(
      color: AppColors.surface,
      elevation: 2,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size.fromHeight(52),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: AppColors.primary),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 2)),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 14),
      hintStyle: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 14),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.primary),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
    chipTheme: ChipThemeData(
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.poppins(fontSize: 13),
      secondaryLabelStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE5E7EB), thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentTextStyle: GoogleFonts.poppins(fontSize: 13),
    ),
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.poppins(
          color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      contentTextStyle:
          GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 14),
    ),
  );

  // ─── Dark theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.darkPrimary,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
    ).copyWith(
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      surfaceContainerHighest: AppColors.darkCard,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    fontFamily: GoogleFonts.poppins().fontFamily,
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 1,
      shadowColor: AppColors.darkBorder,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      actionsIconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      titleTextStyle: GoogleFonts.poppins(
          color: AppColors.darkTextPrimary, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardTheme(
      color: AppColors.darkCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppColors.darkBorder, width: 0.8),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size.fromHeight(52),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: AppColors.darkBorder),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.darkBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.darkBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkAccent, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 2)),
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: GoogleFonts.poppins(color: AppColors.darkTextSecondary, fontSize: 14),
      hintStyle: GoogleFonts.poppins(color: AppColors.darkTextSecondary, fontSize: 14),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.darkAccent,
      unselectedItemColor: AppColors.darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.primary),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.darkAccent,
      foregroundColor: Colors.white,
    ),
    chipTheme: ChipThemeData(
      selectedColor: AppColors.darkPrimary,
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.poppins(fontSize: 13),
      secondaryLabelStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
    ),
    dividerTheme: DividerThemeData(color: AppColors.darkBorder, thickness: 0.8),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentTextStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.darkTextPrimary),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: AppColors.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.poppins(
          color: AppColors.darkTextPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      contentTextStyle:
          GoogleFonts.poppins(color: AppColors.darkTextSecondary, fontSize: 14),
    ),
  );

  // Backward-compat alias
  static ThemeData get theme => lightTheme;

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':   return AppColors.success;
      case 'absent':    return AppColors.danger;
      case 'disputed':
      case 'issued':
      case 'pending':   return AppColors.warning;
      case 'accepted':
      case 'resolved':
      case 'handled':   return AppColors.success;
      case 'declined':  return AppColors.danger;
      case 'open':
      case 'active':    return AppColors.success;
      case 'closed':
      case 'completed': return const Color(0xFF9CA3AF);
      case 'scheduled': return AppColors.accent;
      default:          return AppColors.textSecondary;
    }
  }

  static PageRouteBuilder<T> slideRoute<T>(Widget screen) =>
      PageRouteBuilder<T>(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );

  static PageRouteBuilder<T> fadeRoute<T>(Widget screen) =>
      PageRouteBuilder<T>(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
}

// ── Reusable gradient button ───────────────────────────────────────────────────
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final bool loading;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.height = 52,
    this.loading = false,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        if (!widget.loading) widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [AppColors.darkPrimary, AppColors.darkAccent]
                  : [AppColors.primary, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(77),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.loading
              ? const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5)))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Shimmer list placeholder ───────────────────────────────────────────────────
class AppShimmer extends StatelessWidget {
  final int count;
  final double itemHeight;

  const AppShimmer({super.key, this.count = 5, this.itemHeight = 90});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkCard : Colors.grey.shade300,
      highlightColor: isDark ? AppColors.darkBorder : Colors.grey.shade100,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: count,
        itemBuilder: (_, __) => Container(
          height: itemHeight,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ── Status chip ────────────────────────────────────────────────────────────────
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.clrPrimary.withAlpha(18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: context.clrPrimary.withAlpha(120)),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.poppins(color: context.clrSubText, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.danger.withAlpha(20), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 48, color: AppColors.danger),
            ),
            const SizedBox(height: 20),
            Text(message,
                style: GoogleFonts.poppins(
                    color: context.clrSubText, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drawer tile (for navy drawers — always white text) ────────────────────────
class DrawerNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool selected;
  final Color? iconColor;

  const DrawerNavTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.selected = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = iconColor ?? AppColors.accent;
    return ListTile(
      iconColor: selected ? activeColor : Colors.white70,
      textColor: selected ? activeColor : Colors.white,
      selectedTileColor: Colors.white.withAlpha(22),
      selected: selected,
      leading: Icon(icon),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 14)),
      onTap: onTap,
    );
  }
}
