// The item roster.
//
// Four items, all of which bend a rule rather than touching physics. That is
// what makes them explainable in one sentence with no numbers in it.
import '../model/item.dart';

class Items {
  static const peek = Item(
    id: 'peek',
    name: 'PEEK',
    blurb: 'See where their men stand before you pick a club.',
    effect: ItemEffect.spyDefence,
  );

  static const rob = Item(
    id: 'rob',
    name: 'ROB',
    blurb: 'A runner takes the next base.',
    effect: ItemEffect.stealBase,
  );

  static const hiRok = Item(
    id: 'hi_rok',
    name: 'HI-ROK',
    blurb: 'You go out. Your runner moves up.',
    effect: ItemEffect.sacrificeFly,
  );

  static const nokNoggin = Item(
    id: 'nok_noggin',
    name: 'NOK NOGGIN',
    blurb: 'Bonk the thrower. The pitch comes in slow.',
    effect: ItemEffect.slowPitch,
  );

  static const List<Item> all = [peek, rob, hiRok, nokNoggin];
}
