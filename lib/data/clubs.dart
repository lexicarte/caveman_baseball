// The club roster.
//
// Names are placeholders except the three that are settled; nothing in the
// simulation reads them. Five clubs plus the baseline swing you get for free
// when a slot is empty.
import '../model/club.dart';

class Clubs {
  /// Mid range, any angle. A real card with a real name — it is simply the
  /// one every tribe already owns, and what an empty slot swings.
  static const stik = Club(
    id: 'stik',
    name: 'STIK',
    blurb: 'Mid range, any angle. No card needed.',
    range: ClubRange.mid,
    route: ClubRoute.ground,
    power: 1.00,
    // maxSpray is now past the 48-degree foul line ON PURPOSE: the EDGE of
    // the timing window has to be a foul ball. Swing at the earliest or the
    // latest moment the club allows and you slice it out of play, which is
    // what being that early or that late means in baseball. The fraction of
    // the window that stays fair (48 / maxSpray) is now the club's real
    // directional character.
    maxSpray: 58,
    sideBite: 0.78,
    spread: 0.044, // the club everyone owns, and the most dependable
  );

  static const twig = Club(
    id: 'twig',
    name: 'TWIG',
    blurb: 'Short. Easy to place, goes nowhere.',
    range: ClubRange.short,
    route: ClubRoute.ground,
    power: 0.72,
    maxSpray: 62,
    sideBite: 0.82,
    spread: 0.040,
  );

  static const smak = Club(
    id: 'smak',
    name: 'SMAK',
    blurb: 'Long, over their heads. Lands and dies.',
    range: ClubRange.long,
    route: ClubRoute.air,
    // Deliberately below the ground clubs. An air ball cannot be cut off on
    // its way — only where it lands — so it must pay for that safety in
    // power, or it is never a bad pick and the loadout choice collapses.
    power: 0.95,
    maxSpray: 56,
    sideBite: 0.75,
    carry: 30,
    spread: 0.066, // in the air, so more at the mercy of the strike
  );

  /// Long on the ground: runs the gauntlet, keeps rolling for extra bases.
  static const kwik = Club(
    id: 'long_grounder',
    name: 'KWIK',
    blurb: 'Long and low. Anyone in its line gets a crack at it.',
    range: ClubRange.long,
    route: ClubRoute.ground,
    // Below WUNDERBAT on purpose: with the wall at 38 both were pressing
    // against it, which made the longest club and the wild one land in the
    // same place and hid WUNDERBAT's spread entirely.
    power: 1.12,
    maxSpray: 54,
    sideBite: 0.72,
    spread: 0.045,
  );

  /// Enormous, and only in one direction. Low side bite is the whole point.
  static const wunderbat = Club(
    id: 'wunderbat',
    name: 'WUNDERBAT',
    blurb: 'Furthest of all, straight only. Useless off the line.',
    range: ClubRange.veryLong,
    route: ClubRoute.ground,
    // Reaches the wall on almost any swing, so its band is tiny. That is
    // fine — "it always gets there" is what this club is. Its variation
    // lives in the angle instead, where a low side bite makes anything off
    // the line feeble.
    power: 1.55,
    maxSpray: 50,
    // Was 0.30, which made a mis-timed WUNDERBAT die six paces from the
    // plate — not "feeble off the line" but visibly broken. sideBite is
    // the FLOOR on a swing's power (powerFactor = sideBite at the edge of
    // the window), so it is the number that decides how bad the worst
    // contact looks.
    sideBite: 0.46,
    spread: 0.044, // wild: you never quite know how far it goes
  );

  // TAP (the bunt) was cut 2026-10-03. With a catcher on the plate it scored
  // 0.00 against every scheme — he fields it and throws it out with most of a
  // second to spare. TWIG already beat a deep defence (0.95) and the catcher
  // does not touch that, so the bunt was a near-duplicate even before him. If
  // a bunt comes back it needs a genuinely different identity; the sacrifice
  // role is already HI-ROK's.

  static const List<Club> all = [stik, twig, smak, kwik, wunderbat];

  /// Everything except the free swing — the cards you can actually own.
  static const List<Club> collectable = [twig, smak, kwik, wunderbat];
}
