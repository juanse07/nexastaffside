import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Central theme configuration for the Nexa Staff application.
///
/// This class provides static methods to generate complete [ThemeData]
/// for both light and dark modes, ensuring consistent styling across
/// the entire application.
class AppTheme {
  AppTheme._();

  // Dimension constants (embedded for simplicity)
  static const double _radiusS = 4.0;
  static const double _radiusM = 8.0;
  static const double _radiusL = 12.0;
  static const double _radiusXl = 16.0;
  static const double _paddingXs = 4.0;
  static const double _paddingS = 8.0;
  static const double _paddingSm = 12.0;
  static const double _paddingM = 16.0;
  static const double _paddingL = 24.0;
  static const double _iconMl = 24.0;
  static const double _border = 1.0;
  static const double _borderThick = 2.0;
  static const double _borderThin = 0.5;
  static const double _buttonHeightM = 48.0;
  static const double _buttonMinWidth = 64.0;
  static const double _bottomNavHeight = 64.0;
  static const double _cardElevationM = 2.0;
  static const double _cardElevationL = 4.0;
  static const double _cardElevationXl = 8.0;

  /// Returns the light theme configuration
  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      colorScheme: _lightColorScheme(),
      scaffoldBackgroundColor: AppColors.backgroundWhite,
      appBarTheme: _lightAppBarTheme(),
      elevatedButtonTheme: _elevatedButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      floatingActionButtonTheme: _fabTheme(),
      inputDecorationTheme: _inputDecorationTheme(),
      cardTheme: _cardTheme(),
      chipTheme: _chipTheme(),
      dialogTheme: _dialogTheme(),
      bottomSheetTheme: _bottomSheetTheme(),
      bottomNavigationBarTheme: _bottomNavigationBarTheme(),
      navigationBarTheme: _navigationBarTheme(),
      tabBarTheme: _tabBarTheme(),
      drawerTheme: _drawerTheme(),
      listTileTheme: _listTileTheme(),
      iconTheme: _iconTheme(),
      primaryIconTheme: _primaryIconTheme(),
      dividerTheme: _dividerTheme(),
      snackBarTheme: _snackBarTheme(),
      progressIndicatorTheme: _progressIndicatorTheme(),
      switchTheme: _switchTheme(),
      checkboxTheme: _checkboxTheme(),
      radioTheme: _radioTheme(),
      sliderTheme: _sliderTheme(),
      tooltipTheme: _tooltipTheme(),
      badgeTheme: _badgeTheme(),
      menuTheme: _menuTheme(),
      popupMenuTheme: _popupMenuTheme(),
      splashColor: AppColors.primaryIndigo.withValues(alpha: 0.1),
      highlightColor: AppColors.primaryIndigo.withValues(alpha: 0.05),
      hoverColor: AppColors.primaryIndigo.withValues(alpha: 0.04),
      focusColor: AppColors.primaryIndigo.withValues(alpha: 0.12),
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  /// Returns the dark theme configuration
  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      colorScheme: _darkColorScheme(),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: _darkAppBarTheme(),
      elevatedButtonTheme: _elevatedButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      filledButtonTheme: _filledButtonTheme(),
      floatingActionButtonTheme: _fabTheme(),
      inputDecorationTheme: _darkInputDecorationTheme(),
      cardTheme: _darkCardTheme(),
      chipTheme: _darkChipTheme(),
      dialogTheme: _darkDialogTheme(),
      bottomSheetTheme: _darkBottomSheetTheme(),
      bottomNavigationBarTheme: _darkBottomNavigationBarTheme(),
      navigationBarTheme: _darkNavigationBarTheme(),
      tabBarTheme: _darkTabBarTheme(),
      drawerTheme: _darkDrawerTheme(),
      listTileTheme: _darkListTileTheme(),
      iconTheme: _darkIconTheme(),
      primaryIconTheme: _primaryIconTheme(),
      dividerTheme: _darkDividerTheme(),
      snackBarTheme: _darkSnackBarTheme(),
      progressIndicatorTheme: _progressIndicatorTheme(),
      switchTheme: _switchTheme(),
      checkboxTheme: _checkboxTheme(),
      radioTheme: _radioTheme(),
      sliderTheme: _sliderTheme(),
      tooltipTheme: _darkTooltipTheme(),
      badgeTheme: _badgeTheme(),
      menuTheme: _darkMenuTheme(),
      popupMenuTheme: _darkPopupMenuTheme(),
      splashColor: AppColors.primaryIndigo.withValues(alpha: 0.1),
      highlightColor: AppColors.primaryIndigo.withValues(alpha: 0.05),
      hoverColor: AppColors.primaryIndigo.withValues(alpha: 0.04),
      focusColor: AppColors.primaryIndigo.withValues(alpha: 0.12),
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  // ============ Color Schemes ============

  static ColorScheme _lightColorScheme() {
    return ColorScheme.light(
      primary: AppColors.primaryIndigo,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryPurple,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.secondaryPurple,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryPurple,
      onSecondaryContainer: Colors.white,
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.surfaceRed,
      onErrorContainer: AppColors.error,
      surface: AppColors.backgroundWhite,
      onSurface: AppColors.textDark,
      surfaceContainerHighest: AppColors.surfaceLight,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.borderLight,
      shadow: Colors.black.withValues(alpha: 0.1),
      scrim: Colors.black.withValues(alpha: 0.5),
      inverseSurface: AppColors.backgroundDark,
      onInverseSurface: AppColors.textLight,
      inversePrimary: AppColors.primaryIndigo,
    );
  }

  static ColorScheme _darkColorScheme() {
    return ColorScheme.dark(
      primary: AppColors.primaryIndigo,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryPurple,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.secondaryPurple,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryPurple,
      onSecondaryContainer: Colors.white,
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorDark,
      onErrorContainer: Colors.white,
      surface: AppColors.backgroundDark,
      onSurface: AppColors.textLight,
      surfaceContainerHighest: AppColors.backgroundDarkSecondary,
      onSurfaceVariant: AppColors.textLightSecondary,
      outline: AppColors.borderDark,
      outlineVariant: AppColors.borderMedium,
      shadow: Colors.black.withValues(alpha: 0.3),
      scrim: Colors.black.withValues(alpha: 0.7),
      inverseSurface: AppColors.backgroundWhite,
      onInverseSurface: AppColors.textDark,
      inversePrimary: AppColors.primaryIndigo,
    );
  }

  // ============ App Bar Themes ============

  static AppBarTheme _lightAppBarTheme() {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      backgroundColor: AppColors.navySpaceCadet,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: Colors.white, size: _iconMl),
      actionsIconTheme: IconThemeData(color: Colors.white, size: _iconMl),
      titleTextStyle: TextStyle(
        fontFamily: GoogleFonts.inter().fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: -0.2,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
    );
  }

  static AppBarTheme _darkAppBarTheme() {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      backgroundColor: AppColors.backgroundDarkSecondary,
      foregroundColor: AppColors.textLight,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: AppColors.textLight, size: _iconMl),
      actionsIconTheme: IconThemeData(color: AppColors.textLight, size: _iconMl),
      titleTextStyle: TextStyle(
        fontFamily: GoogleFonts.inter().fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
        letterSpacing: -0.2,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
    );
  }

  // ============ Button Themes ============

  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.primaryIndigo.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: _paddingL, vertical: _paddingSm),
        minimumSize: const Size(_buttonMinWidth, _buttonHeightM),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusM),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryIndigo,
        padding: const EdgeInsets.symmetric(horizontal: _paddingM, vertical: _paddingSm),
        minimumSize: const Size(_buttonMinWidth, _buttonHeightM),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusM),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryIndigo,
        side: const BorderSide(color: AppColors.primaryIndigo, width: _border),
        padding: const EdgeInsets.symmetric(horizontal: _paddingL, vertical: _paddingSm),
        minimumSize: const Size(_buttonMinWidth, _buttonHeightM),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusM),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme() {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryIndigo,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: _paddingL, vertical: _paddingSm),
        minimumSize: const Size(_buttonMinWidth, _buttonHeightM),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusM),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    );
  }

  static FloatingActionButtonThemeData _fabTheme() {
    return const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryIndigo,
      foregroundColor: Colors.white,
      elevation: 6,
      focusElevation: 8,
      hoverElevation: 8,
      highlightElevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(_radiusXl)),
      ),
    );
  }

  // ============ Input Decoration Themes ============

  static InputDecorationTheme _inputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: _paddingM, vertical: _paddingSm),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        borderSide: const BorderSide(color: AppColors.border, width: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        borderSide: const BorderSide(color: AppColors.border, width: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        borderSide: const BorderSide(color: AppColors.primaryIndigo, width: _borderThick),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        borderSide: const BorderSide(color: AppColors.error, width: _border),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        borderSide: const BorderSide(color: AppColors.error, width: _borderThick),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        borderSide: const BorderSide(color: AppColors.borderLight, width: _border),
      ),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      floatingLabelStyle: const TextStyle(color: AppColors.primaryIndigo),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
      prefixIconColor: AppColors.iconMuted,
      suffixIconColor: AppColors.iconMuted,
    );
  }

  static InputDecorationTheme _darkInputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.backgroundDarkSecondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: _paddingM, vertical: _paddingSm),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        borderSide: const BorderSide(color: AppColors.borderDark, width: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        borderSide: const BorderSide(color: AppColors.borderDark, width: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        borderSide: const BorderSide(color: AppColors.primaryIndigo, width: _borderThick),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        borderSide: const BorderSide(color: AppColors.error, width: _border),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        borderSide: const BorderSide(color: AppColors.error, width: _borderThick),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        borderSide: const BorderSide(color: AppColors.borderMedium, width: _border),
      ),
      labelStyle: const TextStyle(color: AppColors.textLightTertiary),
      floatingLabelStyle: const TextStyle(color: AppColors.primaryIndigo),
      hintStyle: const TextStyle(color: AppColors.textLightTertiary),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
      prefixIconColor: AppColors.iconMuted,
      suffixIconColor: AppColors.iconMuted,
    );
  }

  // ============ Card Theme ============

  static CardThemeData _cardTheme() {
    return CardThemeData(
      elevation: _cardElevationM,
      color: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusL),
        side: const BorderSide(color: AppColors.borderLight, width: _borderThin),
      ),
      margin: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
    );
  }

  static CardThemeData _darkCardTheme() {
    return CardThemeData(
      elevation: _cardElevationM,
      color: AppColors.backgroundDarkSecondary,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusL),
        side: const BorderSide(color: AppColors.borderDark, width: _borderThin),
      ),
      margin: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
    );
  }

  // ============ Chip Theme ============

  static ChipThemeData _chipTheme() {
    return ChipThemeData(
      backgroundColor: AppColors.surfaceLight,
      deleteIconColor: AppColors.textMuted,
      disabledColor: AppColors.borderLight,
      selectedColor: AppColors.oceanBlue.withValues(alpha: 0.15),
      secondarySelectedColor: AppColors.oceanBlue.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: const TextStyle(fontSize: 14),
      brightness: Brightness.light,
      elevation: 0,
      pressElevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        side: const BorderSide(color: AppColors.border, width: _borderThin),
      ),
    );
  }

  static ChipThemeData _darkChipTheme() {
    return ChipThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      deleteIconColor: AppColors.textLightTertiary,
      disabledColor: AppColors.borderDark,
      selectedColor: AppColors.primaryIndigo.withValues(alpha: 0.2),
      secondarySelectedColor: AppColors.primaryIndigo.withValues(alpha: 0.2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: const TextStyle(fontSize: 14, color: AppColors.textLight),
      brightness: Brightness.dark,
      elevation: 0,
      pressElevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusM),
        side: const BorderSide(color: AppColors.borderDark, width: _borderThin),
      ),
    );
  }

  // ============ Dialog Theme ============

  static DialogThemeData _dialogTheme() {
    return DialogThemeData(
      backgroundColor: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      elevation: _cardElevationXl,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusXl),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
      contentTextStyle: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
      actionsPadding: const EdgeInsets.all(_paddingM),
      iconColor: AppColors.iconPrimary,
    );
  }

  static DialogThemeData _darkDialogTheme() {
    return DialogThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: _cardElevationXl,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusXl),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
      ),
      contentTextStyle: const TextStyle(fontSize: 16, color: AppColors.textLightSecondary),
      actionsPadding: const EdgeInsets.all(_paddingM),
      iconColor: AppColors.iconPrimary,
    );
  }

  // ============ Bottom Sheet Theme ============

  static BottomSheetThemeData _bottomSheetTheme() {
    return const BottomSheetThemeData(
      backgroundColor: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      elevation: _cardElevationXl,
      modalBackgroundColor: AppColors.backgroundWhite,
      modalElevation: _cardElevationXl,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
    );
  }

  static BottomSheetThemeData _darkBottomSheetTheme() {
    return const BottomSheetThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: _cardElevationXl,
      modalBackgroundColor: AppColors.backgroundDarkSecondary,
      modalElevation: _cardElevationXl,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
    );
  }

  // ============ Bottom Navigation Bar Theme ============

  static BottomNavigationBarThemeData _bottomNavigationBarTheme() {
    return const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceWhite,
      elevation: 8,
      selectedItemColor: AppColors.oceanBlue,
      unselectedItemColor: AppColors.textMuted,
      selectedIconTheme: IconThemeData(size: _iconMl, color: AppColors.oceanBlue),
      unselectedIconTheme: IconThemeData(size: _iconMl, color: AppColors.textMuted),
      selectedLabelStyle: TextStyle(fontSize: 12, color: AppColors.oceanBlue),
      unselectedLabelStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
      type: BottomNavigationBarType.fixed,
      enableFeedback: true,
    );
  }

  static BottomNavigationBarThemeData _darkBottomNavigationBarTheme() {
    return const BottomNavigationBarThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      elevation: 8,
      selectedItemColor: AppColors.primaryIndigo,
      unselectedItemColor: AppColors.textLightTertiary,
      selectedIconTheme: IconThemeData(size: _iconMl, color: AppColors.primaryIndigo),
      unselectedIconTheme: IconThemeData(size: _iconMl, color: AppColors.textLightTertiary),
      selectedLabelStyle: TextStyle(fontSize: 12, color: AppColors.primaryIndigo),
      unselectedLabelStyle: TextStyle(fontSize: 12, color: AppColors.textLightTertiary),
      type: BottomNavigationBarType.fixed,
      enableFeedback: true,
    );
  }

  // ============ Navigation Bar Theme ============

  static NavigationBarThemeData _navigationBarTheme() {
    return NavigationBarThemeData(
      backgroundColor: AppColors.surfaceWhite,
      elevation: 0,
      height: _bottomNavHeight,
      indicatorColor: AppColors.oceanBlue.withValues(alpha: 0.1),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontSize: 12, color: AppColors.oceanBlue);
        }
        return const TextStyle(fontSize: 12, color: AppColors.textMuted);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(size: _iconMl, color: AppColors.oceanBlue);
        }
        return const IconThemeData(size: _iconMl, color: AppColors.textMuted);
      }),
    );
  }

  static NavigationBarThemeData _darkNavigationBarTheme() {
    return NavigationBarThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      elevation: 0,
      height: _bottomNavHeight,
      indicatorColor: AppColors.primaryIndigo.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontSize: 12, color: AppColors.primaryIndigo);
        }
        return const TextStyle(fontSize: 12, color: AppColors.textLightTertiary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(size: _iconMl, color: AppColors.primaryIndigo);
        }
        return const IconThemeData(size: _iconMl, color: AppColors.textLightTertiary);
      }),
    );
  }

  // ============ Tab Bar Theme ============

  static TabBarThemeData _tabBarTheme() {
    return TabBarThemeData(
      labelColor: AppColors.primaryIndigo,
      unselectedLabelColor: AppColors.textMuted,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.primaryIndigo, width: _borderThick),
      ),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.divider,
      overlayColor: WidgetStateProperty.all(AppColors.primaryIndigo.withValues(alpha: 0.1)),
    );
  }

  static TabBarThemeData _darkTabBarTheme() {
    return TabBarThemeData(
      labelColor: AppColors.primaryIndigo,
      unselectedLabelColor: AppColors.textLightTertiary,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.primaryIndigo, width: _borderThick),
      ),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.dividerDark,
      overlayColor: WidgetStateProperty.all(AppColors.primaryIndigo.withValues(alpha: 0.1)),
    );
  }

  // ============ Drawer Theme ============

  static DrawerThemeData _drawerTheme() {
    return const DrawerThemeData(
      backgroundColor: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      elevation: _cardElevationXl,
      width: 280,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(_radiusXl),
          bottomRight: Radius.circular(_radiusXl),
        ),
      ),
    );
  }

  static DrawerThemeData _darkDrawerTheme() {
    return const DrawerThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: _cardElevationXl,
      width: 280,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(_radiusXl),
          bottomRight: Radius.circular(_radiusXl),
        ),
      ),
    );
  }

  // ============ List Tile Theme ============

  static ListTileThemeData _listTileTheme() {
    return ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minVerticalPadding: 8,
      iconColor: AppColors.iconMuted,
      textColor: AppColors.textDark,
      titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textDark),
      subtitleTextStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusM),
      ),
    );
  }

  static ListTileThemeData _darkListTileTheme() {
    return ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minVerticalPadding: 8,
      iconColor: AppColors.iconMuted,
      textColor: AppColors.textLight,
      titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textLight),
      subtitleTextStyle: const TextStyle(fontSize: 14, color: AppColors.textLightSecondary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusM),
      ),
    );
  }

  // ============ Icon Themes ============

  static IconThemeData _iconTheme() {
    return const IconThemeData(color: AppColors.textDark, size: _iconMl);
  }

  static IconThemeData _darkIconTheme() {
    return const IconThemeData(color: AppColors.textLight, size: _iconMl);
  }

  static IconThemeData _primaryIconTheme() {
    return const IconThemeData(color: AppColors.iconPrimary, size: _iconMl);
  }

  // ============ Divider Theme ============

  static DividerThemeData _dividerTheme() {
    return const DividerThemeData(color: AppColors.divider, thickness: 1, space: 16);
  }

  static DividerThemeData _darkDividerTheme() {
    return const DividerThemeData(color: AppColors.dividerDark, thickness: 1, space: 16);
  }

  // ============ Snackbar Theme ============

  static SnackBarThemeData _snackBarTheme() {
    return SnackBarThemeData(
      backgroundColor: AppColors.textDark,
      contentTextStyle: const TextStyle(color: Colors.white),
      elevation: _cardElevationL,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusM)),
      behavior: SnackBarBehavior.floating,
      actionTextColor: AppColors.primaryIndigo,
    );
  }

  static SnackBarThemeData _darkSnackBarTheme() {
    return SnackBarThemeData(
      backgroundColor: AppColors.backgroundDarkSecondary,
      contentTextStyle: const TextStyle(color: AppColors.textLight),
      elevation: _cardElevationL,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusM)),
      behavior: SnackBarBehavior.floating,
      actionTextColor: AppColors.primaryIndigo,
    );
  }

  // ============ Progress Indicator Theme ============

  static ProgressIndicatorThemeData _progressIndicatorTheme() {
    return const ProgressIndicatorThemeData(
      color: AppColors.primaryIndigo,
      linearTrackColor: AppColors.borderLight,
      circularTrackColor: AppColors.borderLight,
    );
  }

  // ============ Switch Theme ============

  static SwitchThemeData _switchTheme() {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primaryIndigo;
        return AppColors.borderMedium;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryIndigo.withValues(alpha: 0.5);
        }
        return AppColors.borderLight;
      }),
      overlayColor: WidgetStateProperty.all(AppColors.primaryIndigo.withValues(alpha: 0.1)),
    );
  }

  // ============ Checkbox Theme ============

  static CheckboxThemeData _checkboxTheme() {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primaryIndigo;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      overlayColor: WidgetStateProperty.all(AppColors.primaryIndigo.withValues(alpha: 0.1)),
      side: const BorderSide(color: AppColors.border, width: _borderThick),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusS)),
    );
  }

  // ============ Radio Theme ============

  static RadioThemeData _radioTheme() {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primaryIndigo;
        return AppColors.border;
      }),
      overlayColor: WidgetStateProperty.all(AppColors.primaryIndigo.withValues(alpha: 0.1)),
    );
  }

  // ============ Slider Theme ============

  static SliderThemeData _sliderTheme() {
    return const SliderThemeData(
      activeTrackColor: AppColors.primaryIndigo,
      inactiveTrackColor: AppColors.borderLight,
      thumbColor: AppColors.primaryIndigo,
      overlayColor: Color(0x1AFFC107),
      valueIndicatorColor: AppColors.primaryIndigo,
      valueIndicatorTextStyle: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
    );
  }

  // ============ Tooltip Theme ============

  static TooltipThemeData _tooltipTheme() {
    return TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.textDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(_radiusS),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: _paddingSm, vertical: _paddingXs),
      margin: const EdgeInsets.all(_paddingS),
      preferBelow: true,
      verticalOffset: _paddingS,
      waitDuration: const Duration(milliseconds: 500),
    );
  }

  static TooltipThemeData _darkTooltipTheme() {
    return TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.backgroundDarkSecondary,
        borderRadius: BorderRadius.circular(_radiusS),
        border: Border.all(color: AppColors.borderDark, width: _borderThin),
      ),
      textStyle: const TextStyle(color: AppColors.textLight, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: _paddingSm, vertical: _paddingXs),
      margin: const EdgeInsets.all(_paddingS),
      preferBelow: true,
      verticalOffset: _paddingS,
      waitDuration: const Duration(milliseconds: 500),
    );
  }

  // ============ Badge Theme ============

  static BadgeThemeData _badgeTheme() {
    return const BadgeThemeData(
      backgroundColor: AppColors.error,
      textColor: Colors.white,
      smallSize: 6,
      largeSize: 16,
      textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  // ============ Menu Theme ============

  static MenuThemeData _menuTheme() {
    return MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.backgroundWhite),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(_cardElevationL),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: _paddingS)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusM)),
        ),
      ),
    );
  }

  static MenuThemeData _darkMenuTheme() {
    return MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.backgroundDarkSecondary),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(_cardElevationL),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: _paddingS)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusM)),
        ),
      ),
    );
  }

  // ============ Popup Menu Theme ============

  static PopupMenuThemeData _popupMenuTheme() {
    return PopupMenuThemeData(
      color: AppColors.backgroundWhite,
      surfaceTintColor: Colors.transparent,
      elevation: _cardElevationL,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusM)),
      textStyle: const TextStyle(fontSize: 14, color: AppColors.textDark),
    );
  }

  static PopupMenuThemeData _darkPopupMenuTheme() {
    return PopupMenuThemeData(
      color: AppColors.backgroundDarkSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: _cardElevationL,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusM)),
      textStyle: const TextStyle(fontSize: 14, color: AppColors.textLight),
    );
  }
}
