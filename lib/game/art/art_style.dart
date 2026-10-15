// Which way the game is drawn.
//
// Two directions are live and neither is settled, so the renderer carries
// both rather than one being commented out. Everything that draws a person
// or the ground reads this.
import 'package:flutter/foundation.dart';

enum ArtStyle {
  /// Sprites on a 14-row grid, drawn for the size they are used at.
  pixel,

  /// Flat television-cartoon: one heavy outline, solid fills, big eyes.
  cartoon;

  String get label => switch (this) {
    ArtStyle.pixel => 'PIXEL',
    ArtStyle.cartoon => 'CARTOON',
  };

  ArtStyle get next =>
      this == ArtStyle.pixel ? ArtStyle.cartoon : ArtStyle.pixel;
}

/// The style in force. A notifier so the HUD can flip it mid-game and
/// everything repaints — comparing two directions from memory is useless.
final ValueNotifier<ArtStyle> artStyle = ValueNotifier(ArtStyle.cartoon);
