# Bowling — Rules

The authoritative source of truth for this game. If the implementation
conflicts with this document, fix the implementation.

## 1. Objective

Knock down as many pins as possible over 10 frames. The player with the
highest total score wins.

## 2. Setup

- 2 players. Mode A: human vs an AI bowler. Mode B: 2 humans, pass-and-play.
- Every frame starts with a full rack of 10 pins.
- Each player has their own 10-frame score sheet.

## 3. Turn order

- Players alternate whole frames: Player 1 bowls their full frame
  (1–3 balls), then Player 2 bowls their full frame.
- Within a frame, the same player keeps throwing until the frame is done.

## 4. Legal moves

- While aiming, the player may drag left/right to adjust the ball's start
  position on the lane.
- A throw is made by flicking up: flick speed sets power, sideways flick
  velocity at release sets curve (spin).
- A throw is legal only during the aim phase; during ball roll, pin
  scatter, and the result pause, input is locked out.

## 5. Illegal moves

- Throwing outside the aim phase is ignored (no throw happens).
- Aim values are clamped to the lane (0.05–0.95), power to 0.35–1.0,
  curve to −0.35–0.35; out-of-range gestures clamp, never break the game.

## 6. Captures

- Not applicable. Pins knocked by the ball (direct hits or chain
  reactions through neighboring pins) count as pins down.

## 7. Special rules

- Strike (frames 1–9): all 10 pins on ball 1 ends the frame immediately.
- Spare (frames 1–9): all 10 pins across both balls ends the frame.
- 10th frame: ball 1 strike → fresh rack for ball 2. Ball 2 strike
  (after a ball-1 strike) or ball 1+2 spare → fresh rack for ball 3.
  Ball 1 strike then ball 2 non-strike → ball 3 continues on the
  pins left from ball 2 (no fresh rack).
- Three balls maximum in the 10th frame.

## 8. Scoring

- Frames 1–9: open frame = pins knocked. Spare = 10 + pins on the next
  ball. Strike = 10 + pins on the next two balls.
- 10th frame: total pins knocked across its balls, no bonuses.
- A strike/spare bonus is only awarded once the bonus balls exist;
  the cumulative display waits for them.
- Maximum possible score: 300.

## 9. Winning conditions

- After both players complete 10 frames, the highest score wins.
- If a human beats the AI, the human wins (the AI takes its loss
  gracefully).

## 10. Draw conditions

- Equal final scores = a draw. Both players share the trophy screen.

## 11. AI strategy

Three difficulties, all fully visible (the AI aims, lines up, and
throws with on-screen narration — never silently auto-plays):
- Easy: sloppy aim (often misses the pocket), soft inconsistent power,
  random curve.
- Medium: aims near the pocket with some drift, solid power, mild curve.
- Hard (Pro): threads the pocket tightly, clean powerful throws,
  minimal curve error.

## 12. Edge cases

- Gutter throw (0 pins): legal, scores 0, turn passes normally.
- Ball 1 strike in the 10th followed by two gutter balls: frame scores 10.
- A throw that knocks pins after the frame is already decided is
  impossible — the frame-end check runs before every throw.
- Pausing mid-roll freezes the engine timers; resume continues the
  exact same throw. The watchdog recovers any phase found without a
  live timer, so no stuck states are possible.

## 13. Test cases

1. Perfect game: 12 strikes → 300.
2. All spares (5+5) with final 5 → 150.
3. All gutters → 0.
4. 10th frame X, X, X → 30 for the frame.
5. 10th frame X, 7, 2 → 19 for the frame (no fresh rack after ball 2).
6. 10th frame 7, /, X → 20 for the frame (fresh rack for ball 3).
7. Strike in frame 9 with X, 5, 5 in the 10th → frame 9 scores 25.
8. Human throw during pin scatter → ignored, no double-throw.
9. Pause during ball roll → resume continues the same throw.
10. AI turn → narration banners appear, aim indicator drifts, ball
    throws visibly; the game never advances silently.
