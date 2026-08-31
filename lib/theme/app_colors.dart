import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF5B4CE8);

  static const primaryDeep = Color(0xFF4B3FE4);

  static const accentViolet = Color(0xFF6C5CE7);

  static const accentPink = Color(0xFFD85CDE);

  /// Unified primary CTA — indigo → royal violet. Never magenta/pink.
  static const ctaStart = Color(0xFF4B3FE4);

  static const ctaMid = Color(0xFF5548E6);

  static const ctaEnd = Color(0xFF5B4CE8);

  static const navy = Color(0xFF102A5E);

  /// Card / sheet / dialog surface — always light.
  static const background = Color(0xFFFFFFFF);

  /// Deep space-navy canvas behind elevated white cards. Never pure black.
  static const canvasDeep = Color(0xFF071426);

  static const canvas = Color(0xFF0C1B33);

  /// Luminous steel core of the compact central halo.
  static const canvasHaloCore = Color(0xFFD4E4F2);

  /// Illuminated mid-field — visibly lighter than [canvasDeep] in screenshots.
  static const canvasGlow = Color(0xFF8AADC8);

  static const canvasBlueSheen = Color(0xFF3E6F9A);

  static const canvasIndigo = Color(0xFF5A4A8C);

  /// Cool steel tint for card ambient halos.
  static const cardHalo = Color(0xFF1A3A5C);

  /// Outer vignette — navy, not black.
  static const canvasVignette = Color(0xFF050A16);

  /// Alias used by Home / Investigation / Trust canvases.
  static const workspaceBackground = canvas;

  /// Light surface for Capture workspace only — not the space field.
  static const captureSurface = Color(0xFFF3F6FB);

  /// Primary white card face — very slightly warm.
  static const card = Color(0xFFFFFEFC);

  /// Cool-grey offset layer under stacked cards — a thin document slip.
  static const cardStack = Color(0xFFE4EAF3);

  static const cardStackDeep = Color(0xFFD3DCE8);

  /// Atmospheric card surface — midpoint of [canvasHaloCore] and [canvasGlow]
  /// (halo-to-mid-field stops in the SpaceCanvas glow gradient).
  /// Canonical shared sky-blue / atmospheric field color.
  static const canvasAtmosphere = Color(0xFFAFC9DD);

  /// Journey tab fills — distinct space-grey tones of the canvas family.
  static const journeyTabCapture = Color(0xFF141C28);

  static const journeyTabOrganize = Color(0xFF1C2838);

  static const journeyTabInvestigate = Color(0xFF253244);

  static const journeyTabTrust = Color(0xFF2E3C54);

  /// Evidence Inspector elevated surface — lighter Space Grey than [canvasDeep].
  static const inspectorSurface = Color(0xFF243044);

  /// Capture Now tiles — five densities of the same halo → Space Grey field.
  /// Photo samples the brighter halo core; File samples the cooler mid-field.
  static const captureTilePhoto = Color(0xFFCBDDED);

  static const captureTileVideo = Color(0xFFB6CEE1);

  static const captureTileVoice = canvasAtmosphere;

  static const captureTileNote = Color(0xFF9BBAD1);

  static const captureTileFile = Color(0xFF759CBB);

  /// Capture tiles sitting on a white parent card.
  static const captureTile = canvasAtmosphere;

  /// Capture Now outline — same cool family as [borderAccent], ~50% lighter.
  static const captureTileBorder = Color(0xFFE2E8F4);

  static const surfaceMuted = Color(0xFFF4F7FF);

  /// Titles sitting directly on the space canvas.
  static const onCanvas = Color(0xFFF3F6FB);

  static const onCanvasSecondary = Color(0xFFC4CDE0);

  static const border = Color(0xFFE4E7EC);

  /// Soft navy-tinted border for premium section accents (not loud).
  static const borderAccent = Color(0xFFC5D0E8);

  static const divider = Color(0xFFE5E7EB);

  static const textPrimary = Color(0xFF102A5E);

  static const textSecondary = Color(0xFF5A6478);

  static const textMuted = Color(0xFF5C6370);

  static const onPrimary = Color(0xFFFFFFFF);

  static const shadow = Color(0x29000000);

  static const shadowLight = Color(0x14000000);

  static const primaryShadow = Color(0x594B3FE4);

  static const success = Color(0xFF16A34A);

  static const warning = Color(0xFFF59E0B);

  /// Capture timeline — primary chronology connectors ("what happened").
  static const timelineChronology = Color(0xFFF59E0B);

  /// Capture timeline — supporting evidence connectors ("supports what happened").
  static const timelineSupporting = Color(0xFF3B82F6);

  /// Investigate → Connections: system-generated traces.
  /// Electric violet / indigo — calm, intelligent, not a general UI accent.
  static const connectionSystem = Color(0xFF6F5BFF);

  /// Investigate → Connections: investigator-made traces (My Connections).
  /// Blazing orange with the established fire-aura for user manipulation.
  static const connectionMine = Color(0xFFFF6A1A);

  static const danger = Color(0xFFDC2626);

  /// Archived incident card — muted rose, not error or disabled.
  static const archivedSurface = Color(0xFFF7EEF0);

  static const archivedBorder = Color(0xFFE4D0D4);

  static const strengthWeak = Color(0xFFDC2626);

  static const strengthFair = Color(0xFFF59E0B);

  static const strengthGood = Color(0xFF3B82F6);

  static const strengthStrong = Color(0xFF16A34A);

  static const strengthTrack = Color(0xFFE4E7EC);
}
