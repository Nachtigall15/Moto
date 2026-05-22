import 'package:flutter/material.dart';

/// Professionelles Dark-Theme im Navi-/Motorsport-Look:
/// tiefes Slate als Untergrund, ein klarer Sky-Blue als Hauptakzent
/// und warme Sekundär-/Tertiärtöne (Amber & Emerald) für gut
/// lesbare Marker und Statusmeldungen.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0EA5E9),
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF38BDF8),
    onPrimary: const Color(0xFF021726),
    primaryContainer: const Color(0xFF075985),
    onPrimaryContainer: const Color(0xFFE0F2FE),
    secondary: const Color(0xFFFBBF24),
    onSecondary: const Color(0xFF1A1100),
    secondaryContainer: const Color(0xFF78350F),
    onSecondaryContainer: const Color(0xFFFEF3C7),
    tertiary: const Color(0xFF34D399),
    onTertiary: const Color(0xFF052E1A),
    error: const Color(0xFFF87171),
    surface: const Color(0xFF0B1220),
    onSurface: const Color(0xFFE2E8F0),
    onSurfaceVariant: const Color(0xFFCBD5E1),
    outline: const Color(0xFF334155),
    outlineVariant: const Color(0xFF1F2937),
  );

  const elevated = Color(0xFF111A2E);
  const switchOffTrack = Color(0xFF1F2A3D);

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: elevated,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.22),
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: elevated,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.primary.withValues(alpha: 0.25),
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.18),
      valueIndicatorColor: scheme.primaryContainer,
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? scheme.onPrimary
            : scheme.onSurfaceVariant,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? scheme.primary
            : switchOffTrack,
      ),
      trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? scheme.primary
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      side: BorderSide(color: scheme.outline, width: 1.5),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: elevated,
      selectedColor: scheme.primary,
      labelStyle: TextStyle(color: scheme.onSurface, fontSize: 12),
      secondaryLabelStyle:
          TextStyle(color: scheme.onPrimary, fontSize: 12),
      side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: elevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
    ),
  );
}
