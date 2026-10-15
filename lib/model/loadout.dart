// What a team brings to a game.
//
// Three slots per batter, always — one card per swing, three swings maximum,
// so cards and strikes stay in step. Clubs and items share those slots, and an
// empty slot simply means the baseline swing.
//
// The defence mirrors it: three rocks loaded against each opposing batter,
// chosen before the game. In play the thrower picks the ORDER of his three and
// picks a scheme freely at every pitch.
//
// Loadouts persist between games and are tweaked, not rebuilt.
import 'club.dart';
import 'item.dart';
import 'player.dart';
import 'rock.dart';

/// A thing a batter can carry in one of his three slots.
sealed class BatterCard {
  const BatterCard();
}

final class ClubCard extends BatterCard {
  const ClubCard(this.club);
  final Club club;
}

final class ItemCard extends BatterCard {
  const ItemCard(this.item);
  final Item item;
}

/// Slots per batter, and per opposing batter on defence. Not configurable.
const int slotsPerBatter = 3;

/// Men on a team. All five field; one of them catches.
const int playersPerTeam = 5;

class Team {
  Team({
    required this.name,
    required this.players,
    required this.catcherIndex,
    List<List<BatterCard?>>? batting,
    List<List<Rock?>>? throwing,
  }) : assert(players.length == playersPerTeam),
       batting =
           batting ??
           List.generate(
             playersPerTeam,
             (_) => List<BatterCard?>.filled(slotsPerBatter, null),
           ),
       throwing =
           throwing ??
           List.generate(
             playersPerTeam,
             (_) => List<Rock?>.filled(slotsPerBatter, null),
           );

  final String name;

  /// Batting order. Index 0 leads off.
  final List<Player> players;

  /// Which man crouches at the plate. Everyone fields — the catcher is the
  /// low-mobility post, so the mighty archetype goes here and costs the team
  /// almost nothing defensively.
  final int catcherIndex;

  /// batting[batterIndex][slot] — what our man carries.
  final List<List<BatterCard?>> batting;

  /// throwing[opposingBatterIndex][slot] — what we have loaded against theirs.
  final List<List<Rock?>> throwing;

  /// All five take the field. The catcher is listed first so he maps onto the
  /// catcher post, then the rest in batting order.
  List<Player> get fielders => [
    players[catcherIndex],
    for (var i = 0; i < players.length; i++)
      if (i != catcherIndex) players[i],
  ];

  /// How full the loadout is, 0..1. The visible progress bar of a run, and the
  /// single cleanest dial for opponent difficulty.
  double get fillRatio {
    final total = playersPerTeam * slotsPerBatter * 2;
    var filled = 0;
    for (final row in batting) {
      filled += row.whereType<BatterCard>().length;
    }
    for (final row in throwing) {
      filled += row.whereType<Rock>().length;
    }
    return filled / total;
  }
}
