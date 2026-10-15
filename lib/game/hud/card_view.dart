// One card, drawn as a stone tablet.
//
// Chipped corners and a grey slab rather than a rounded rectangle, because
// the whole game's look hangs off these and a card is the thing the player
// stares at most.
import 'package:flutter/material.dart';

import '../../model/club.dart';
import '../../model/item.dart';
import '../../model/rock.dart';
import '../../model/tier.dart';

enum TabletKind { club, item, rock, empty }

class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.title,
    required this.kind,
    required this.blurb,
    required this.tier,
    required this.enabled,
    required this.onTap,
    this.spent = false,
  });

  CardView.club(
    Club c, {
    super.key,
    required this.enabled,
    required this.onTap,
    this.spent = false,
  }) : title = c.name,
       kind = TabletKind.club,
       blurb = c.blurb,
       tier = c.tier;

  CardView.item(
    Item i, {
    super.key,
    required this.enabled,
    required this.onTap,
    this.spent = false,
  }) : title = i.name,
       kind = TabletKind.item,
       blurb = i.blurb,
       tier = i.tier;

  CardView.rock(
    Rock r, {
    super.key,
    required this.enabled,
    required this.onTap,
    this.spent = false,
  }) : title = r.name,
       kind = TabletKind.rock,
       blurb = r.blurb,
       tier = r.tier;

  const CardView.empty({
    super.key,
    required this.title,
    required this.blurb,
    required this.enabled,
    required this.onTap,
    this.spent = false,
  }) : kind = TabletKind.empty,
       tier = Tier.stone;

  final String title;
  final TabletKind kind;
  final String blurb;
  final Tier tier;
  final bool enabled;
  final bool spent;
  final VoidCallback onTap;

  Color get _edge => switch (tier) {
    Tier.stone => const Color(0xFF7E8078),
    Tier.copper => const Color(0xFFA2603A),
    Tier.bronze => const Color(0xFFBE9A46),
  };

  String get _kindLabel => switch (kind) {
    TabletKind.club => 'CLUB',
    TabletKind.item => 'THING',
    TabletKind.rock => 'ROCK',
    TabletKind.empty => '',
  };

  @override
  Widget build(BuildContext context) {
    final dim = !enabled || spent;
    return Opacity(
      opacity: dim ? 0.34 : 1,
      child: GestureDetector(
        onTap: enabled && !spent ? onTap : null,
        child: Container(
          width: 108,
          padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
          decoration: BoxDecoration(
            color: kind == TabletKind.empty
                ? const Color(0xFF2A2724)
                : const Color(0xFF4A453F),
            border: Border.all(color: _edge, width: 1.6),
            // Chipped, not rounded.
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              topRight: Radius.circular(9),
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_kindLabel.isNotEmpty)
                Text(
                  _kindLabel,
                  style: TextStyle(
                    color: _edge,
                    fontSize: 8,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFEDE7DA),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                blurb,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFEDE7DA).withValues(alpha: 0.55),
                  fontSize: 9.5,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
