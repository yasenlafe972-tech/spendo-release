import 'package:flutter/material.dart';

/// Spendo Design System Color Tokens.
/// High-precision obsidian dark theme matching Boro UI & modern FinTech standards.
class AppColors {
  AppColors._();

  // Backgrounds & Surfaces (Obsidian #0A0A0C)
  static const Color background = Color(0xFF0A0A0C);
  static const Color surface = Color(0xFF121215);
  static const Color surfaceCard = Color(0xFF121215);
  static const Color surfaceCardHover = Color(0xFF16161A);
  static const Color surfaceElevated = Color(0xFF16161A);
  static const Color surfaceCardBorder = Color(0xFF1E1E24);
  static const Color surfaceCardBorderActive = Color(0xFF2A2A34);
  static const Color surfaceCell = Color(0xFF16161A);
  static const Color surfaceCellBorder = Color(0xFF222229);

  // Spendo Primary Brand Accent (Electric Royal Blue #2563EB)
  static const Color spendoBlue = Color(0xFF2563EB);

  static const Color spendoBlueLight = Color(0xFF3B82F6);
  static const Color spendoBlueGlow = Color(0x332563EB);
  static const Color spendoBlueSurface = Color(0x1A2563EB);
  static const Color primaryAction = Color(0xFF2563EB);
  static const Color spendoMint = Color(0xFF60A5FA);
  static const Color spendoGlow = Color(0x332563EB);

  // Muted amber for pending transactions and warnings.
  static const Color electricYellow = Color(0xFFD6AD52);
  static const Color electricYellowGlow = Color(0x33D6AD52);
  static const Color electricYellowSurface = Color(0x1AD6AD52);
  static const Color warningYellow = Color(0xFFD6AD52);
  static Color warningFor(bool isDark) =>
      isDark ? warningYellow : const Color(0xFF966008);
  static Color successFor(bool isDark) =>
      isDark ? const Color(0xFF34D399) : const Color(0xFF087F5B);

  // Protected Utility Colors (Cash & WhatsApp strictly Green #10B981)
  static const Color cashGreen = Color(0xFF10B981);
  static const Color whatsappGreen = Color(0xFF10B981);
  static const Color successGreen = Color(0xFF10B981);
  static const Color spendoGreen = Color(0xFF2563EB); // Electric Royal Blue

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFD4D4D8);
  static const Color textMuted = Color(0xFF71717A);

  // Badges & Actions
  static const Color badgeBackground = Color(0xFF1B1B21);
  static const Color badgeBorder = Color(0xFF2C2C35);
  static const Color badgeText = Color(0xFFD4D4D8);

  // Monochrome Icons (Prototype Blended Tone)
  static const Color monoIcon = Color(0xFF52525B);
  static const Color monoIconHover = Color(0xFFD4D4D8);
  static const Color pinActive = Color(0xFFE4E4E7);
  static const Color pinInactive = Color(0xFF45454E);

  // Utility Colors
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color dangerRed = Color(0xFFEF4444);

  // Avatar & Icons
  static const Color avatarBackground = Color(0xFF17171B);
  static const Color avatarBorder = Color(0xFF25252D);
  static const Color iconMuted = Color(0xFF52525B);
  static const Color iconActive = Color(0xFFFFFFFF);
}
