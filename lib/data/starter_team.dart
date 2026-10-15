// The team you begin with, and the one the first league throws at you.
//
// Mostly empty slots on purpose: an empty slot swings STIK and throws a plain
// ROK, so early games are two tribes swinging average at each other. How full
// the slots are is the cleanest single dial for opponent difficulty, and the
// visible progress bar of a run.
import '../model/club.dart';
import '../model/item.dart';
import '../model/loadout.dart';
import '../model/player.dart';
import '../model/rock.dart';
import 'clubs.dart';
import 'items.dart';
import 'rocks.dart';

class StarterTeams {
  static List<Player> _roster(String prefix) => [
    Player(id: '${prefix}1', name: 'Ug', archetype: Archetype.swift),
    Player(id: '${prefix}2', name: 'Bok', archetype: Archetype.steady),
    Player(id: '${prefix}3', name: 'Mun', archetype: Archetype.steady),
    Player(id: '${prefix}4', name: 'Grak', archetype: Archetype.mighty),
    Player(id: '${prefix}5', name: 'Nim', archetype: Archetype.swift),
  ];

  /// Fills the first [count] of the 15 batting slots and 15 throwing slots,
  /// so difficulty is one number.
  static Team build({
    required String name,
    required String prefix,
    required int clubsOwned,
    required int rocksOwned,
    List<Club> clubPool = const [Clubs.twig, Clubs.smak, Clubs.kwik],
    List<Rock> rockPool = const [Rocks.heavy, Rocks.bouncer, Rocks.spinLeft],
    List<Item> itemPool = const [Items.peek],
  }) {
    final team = Team(
      name: name,
      players: _roster(prefix),
      // The mighty man catches: the post that needs no legs.
      catcherIndex: 3,
    );

    var placed = 0;
    outer:
    for (var b = 0; b < playersPerTeam; b++) {
      for (var s = 0; s < slotsPerBatter; s++) {
        if (placed >= clubsOwned) break outer;
        // Every fourth card is an item, so items are present but not common.
        team.batting[b][s] = (placed % 4 == 3 && itemPool.isNotEmpty)
            ? ItemCard(itemPool[placed % itemPool.length])
            : ClubCard(clubPool[placed % clubPool.length]);
        placed++;
      }
    }

    placed = 0;
    outer2:
    for (var b = 0; b < playersPerTeam; b++) {
      for (var s = 0; s < slotsPerBatter; s++) {
        if (placed >= rocksOwned) break outer2;
        team.throwing[b][s] = rockPool[placed % rockPool.length];
        placed++;
      }
    }

    return team;
  }

  /// Day one: four cards against fifteen slots.
  static Team player() =>
      build(name: 'You', prefix: 'p', clubsOwned: 4, rocksOwned: 4);

  /// The bottom league throws about as little as you do.
  static Team rookieOpponent() =>
      build(name: 'Them', prefix: 'o', clubsOwned: 3, rocksOwned: 3);
}
