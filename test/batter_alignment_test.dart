// The batter has to stand level with the plate.
//
// With the timing meter gone the swing is timed BY EYE off the rock, and
// the simulation scores a perfect swing at the instant the rock reaches
// depth 0. Draw the batter further out than that and the two stop being the
// same moment: at 1.2 paces they were 174ms apart, which is wider than
// every club's window bar one, and the game was literally unhittable while
// every number in the simulation was correct.
//
// Nothing else catches this. It is not a crash, the balance tools do not
// see it because they drive the controller directly, and on screen it just
// looks like you are bad at the game.
import 'package:flutter_test/flutter_test.dart';

import 'package:caveman_baseball/data/clubs.dart';
import 'package:caveman_baseball/game/caveman_baseball_game.dart';
import 'package:caveman_baseball/game/ground.dart';
import 'package:caveman_baseball/game/match_controller.dart';
import 'package:caveman_baseball/sim/fielder_spec.dart';
import 'package:caveman_baseball/sim/game_rules.dart';

void main() {
  // The rock travels from the thrower's post to the plate over the flight,
  // at a constant rate, so depth converts straight into time.
  final throwerDepth = Schemes.line.thrower.depth;
  double msAt(double depth) =>
      (depth / throwerDepth) * GameRules.pitchFlightSeconds * 1000;

  final tightest = Clubs.all
      .map((c) => GameRules.timingWindow)
      .reduce((a, b) => a < b ? a : b);

  test('swinging when the rock is level with the batter is ON TIME', () {
    final errorMs = msAt(CavemanBaseballGame.batterY).abs();
    expect(
      errorMs,
      lessThan(tightest * 1000 * 0.25),
      reason:
          'the batter is drawn ${CavemanBaseballGame.batterY} paces off the '
          'plate, which is ${errorMs.toStringAsFixed(0)}ms of timing error '
          'before the player has done anything. The tightest club window is '
          '+/-${(tightest * 1000).round()}ms.',
    );
  });

  test('it is inside every club window, not just the generous ones', () {
    final errorMs = msAt(CavemanBaseballGame.batterY).abs();
    for (final club in Clubs.all) {
      expect(
        errorMs,
        lessThan(GameRules.timingWindow * 1000),
        reason:
            '${club.name} (+/-${(GameRules.timingWindow * 1000).round()}ms) '
            'cannot absorb a ${errorMs.toStringAsFixed(0)}ms built-in error',
      );
    }
  });

  test('he stands beside the plate, in his own heights', () {
    // Absolute paces are meaningless here: figures shrink as the camera
    // pushes in, so a fixed offset would leave a small batter stranded a
    // long way from the plate with a club that cannot reach it. What has
    // to hold is the RATIO.
    final inHeights =
        CavemanBaseballGame.batterX / CavemanBaseballGame.drawnHeight;
    expect(inHeights, lessThan(-0.3), reason: 'standing on the plate');
    expect(inHeights, greaterThan(-0.9), reason: 'too far off the plate');
  });

  test('his club still reaches the plate at any figure scale', () {
    // The club extends 0.62 of a drawn height from the hand, and the hand
    // sits a little out from his centre. If the reach ever fell short of
    // the offset, a perfectly timed swing would pass behind the rock.
    for (final h in [
      Ground.figureHeightTight,
      Ground.figureHeightWide,
      0.8,
      6.0,
    ]) {
      final drawn = h * 1.04;
      final offset = (CavemanBaseballGame.batterSideInHeights * drawn).abs();
      final reach = 0.62 * drawn;
      expect(
        reach,
        greaterThan(offset),
        reason: 'at figure height $h the club falls short of the plate',
      );
    }
  });

  test('the rock meets the bat at the moment a swing scores', () {
    // The second half of the same bug, and the one that survived the
    // first fix. A rock drawn sinking toward the ground crosses the bat's
    // height at the wrong moment, and the player swings at what they see.
    // It used to cross 214ms early and arrive at the batter's ankles.
    final dc = MatchController.contactDepth;
    final rockY = Ground.y(dc) - CavemanBaseballGame.rockLift(dc, throwerDepth);
    final offBy = (rockY - CavemanBaseballGame.batHeight).abs();
    final ms =
        offBy /
        Ground.squash /
        throwerDepth *
        GameRules.pitchFlightSeconds *
        1000;
    expect(
      offBy,
      lessThan(0.05),
      reason:
          'the rock passes the bat ${offBy.toStringAsFixed(2)} units '
          'off, which is ${ms.toStringAsFixed(0)}ms of timing error the '
          'player can neither see nor correct for',
    );
  });

  test('contact is IN FRONT of the plate, toward the thrower', () {
    expect(MatchController.contactDepth, greaterThan(0));
    // Far enough in front to make a late swing the miss, near enough that
    // it is still a swing at the plate and not a lunge.
    expect(MatchController.contactDepth, lessThan(1.5));
  });

  test('he is on the third-base side, which is a right-hander', () {
    expect(
      CavemanBaseballGame.batterX,
      isNegative,
      reason: 'positive x is the first-base side — the LEFT-hander box',
    );
  });
}
