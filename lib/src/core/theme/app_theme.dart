import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design system for the app.
///
/// Both [light] and [dark] define the SAME set of component themes so
/// switching modes (see the toggle in NewShellScreen) doesn't leave half
/// the UI unstyled. Keep the two in sync when adding new component themes.
class AppTheme {
  static const _primary = Color(0xFF4F46E5); // Indigo
  static const _secondary = Color(0xFF06B6D4); // Cyan
  static const _tertiary = Color(0xFFF59E0B); // Amber

  // Public accessor — several screens (class picker, admin/fees menus)
  // reference the brand color directly for icon circles etc.
  static const Color primary = _primary;

  static const _radiusSm = 10.0;
  static const _radiusMd = 12.0;
  static const _radiusLg = 16.0;
  static const _radiusXl = 18.0;

  static ThemeData light() => _build(
        brightness: Brightness.light,
        scaffoldBackground: const Color(0xFFF7F8FC),
        surface: Colors.white,
        appBarBackground: _primary,
        onAppBar: Colors.white,
        borderColor: Colors.grey.withOpacity(0.15),
        mutedText: Colors.grey[600]!,
        dialogTitleColor: Colors.black87,
        snackBg: const Color(0xFF1F2937),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scaffoldBackground: const Color(0xFF111827),
        surface: const Color(0xFF1F2937),
        appBarBackground: const Color(0xFF1E1B4B),
        onAppBar: Colors.white,
        borderColor: Colors.white.withOpacity(0.12),
        mutedText: Colors.grey[400]!,
        dialogTitleColor: Colors.white,
        snackBg: const Color(0xFF374151),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffoldBackground,
    required Color surface,
    required Color appBarBackground,
    required Color onAppBar,
    required Color borderColor,
    required Color mutedText,
    required Color dialogTitleColor,
    required Color snackBg,
  }) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        secondary: _secondary,
        tertiary: _tertiary,
        brightness: brightness,
      ),
    );
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLg),
          side: BorderSide(color: borderColor),
        ),
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: onAppBar,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: onAppBar,
        ),
        iconTheme: IconThemeData(color: onAppBar),
        actionsIconTheme: IconThemeData(color: onAppBar),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMd)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: mutedText.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMd)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMd)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: _primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusSm)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMd)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: _primary,
        textColor: isDark ? Colors.white : Colors.black87,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusXl)),
        titleTextStyle: GoogleFonts.poppins(
            fontSize: 17, fontWeight: FontWeight.w600, color: dialogTitleColor),
        contentTextStyle: GoogleFonts.poppins(fontSize: 14, color: dialogTitleColor.withOpacity(0.8)),
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_radiusXl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusSm)),
        backgroundColor: snackBg,
        contentTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 13.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: isDark ? _secondary : _primary),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: _primary,
        unselectedItemColor: mutedText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: _primary.withOpacity(0.16),
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? _primary : mutedText);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? _primary : mutedText,
          );
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? _primary : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? _primary.withOpacity(0.4) : null),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? _primary : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? _primary : mutedText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(_radiusMd)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMd),
          borderSide: const BorderSide(color: _primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusMd),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
        ),
        labelStyle: GoogleFonts.poppins(color: mutedText, fontSize: 13.5),
        hintStyle: GoogleFonts.poppins(color: mutedText, fontSize: 13.5),
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.1),
        labelStyle: GoogleFonts.poppins(fontSize: 12.5, color: isDark ? Colors.white : Colors.black87),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(space: 1, thickness: 1, color: borderColor),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[900],
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMd)),
      ),
    );
  }

  // Semantic color constants used across cards/badges — same in both themes
  // so status colors (e.g. "present" green) stay recognizable regardless
  // of light/dark mode.
  static const attendanceColor = Color(0xFF10B981); // green
  static const absentColor = Color(0xFFEF4444); // red
  static const homeworkColor = Color(0xFF8B5CF6); // violet
  static const whatsappColor = Color(0xFF25D366); // WA green
  static const pendingColor = Color(0xFFF59E0B); // amber
  static const infoColor = Color(0xFF3B82F6); // blue
}
