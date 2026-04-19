# Void TD

A space-themed tower defense game built with Godot 4 and GDScript. Runs on desktop and iOS.

## Gameplay

Defend your base from 19 waves of enemies by placing towers on the grid. Enemies follow a fixed path — if they reach the base you lose lives. Survive the final boss on wave 20 to win, or keep going in **Endless Mode** with procedurally scaling difficulty.

Enemies spawn in randomized order and with variable spacing each wave, so no two waves play the same.

## Towers

| Tower | Cost | Damage | Range | Cap | Notes |
|-------|------|--------|-------|-----|-------|
| Laser Turret | $50 | 10 | 180 | — | Fast fire rate, single target. Visually upgrades at L2 and L3. |
| Plasma Cannon | $100 | 40 | 150 | 6 | AoE splash damage |
| Void-Seeker | $150 | 80 | 300 | 4 | Longest range, single target |
| Mecha Soldier | $300 | 150 | 220 | 4 | Heavy AoE, most powerful |
| Void Stunner | $125 | — | 160 | 5 | Pulses every 7s, slowing all enemies in range. Applies Void Rupture to bosses. |

**Maximum 30 towers total** on the field at once. The HUD shows your current count.

### Upgrades

Tap a placed tower to open the upgrade panel. Towers can be upgraded to level 3.

| Level | Damage | Range | Cost (Laser / Cannon / Missile / Mecha / Stunner) |
|-------|--------|-------|---------------------------------------------------|
| L1 | 1.0x | 1.0x | — |
| L2 | 1.6x | 1.3x | $50 / $100 / $150 / $300 / $125 |
| L3 | 2.5x | 1.6x | $100 / $200 / $300 / $600 / $250 |

Selling a tower refunds **50% of total invested** (base cost + all upgrades paid).

### Base Upgrades

Tap the base to open its upgrade panel. Each level adds damage reduction, decreasing lives lost when enemies reach the base (applies to all enemy types including bosses).

## Enemies

| Enemy | HP | Speed | Reward | Notes |
|-------|-----|-------|--------|-------|
| Void Scout | 65 | 200 | $5 | Basic fast enemy |
| Void Tanker | 600 | 60 | $45 | Heavy, costs 3 lives on exit |
| Void Herald (Boss) | 2000 | 40 | $90 | Stuns nearby towers every 3.5s, costs 4 lives on exit |
| Void Shade | 30 | 400 | $10 | Very fast, low HP |
| Void Sentinel | 350 | 75 | $70 | Periodically immune to damage |
| THE VOID (Mega Boss) | 5000 | 30 | $300 | Wave 20 final boss — armored phase, massive stun range |

Enemy **HP scales** each wave (up to 5.5x by wave 20). Enemy **speed also scales** gently (+2% per wave), so later waves demand tighter coverage.

## Controls

### Desktop
- **Left-click** a tower button (or press **1-4**), then click a tile to place
- **Tap** a placed tower to open the upgrade / sell panel
- **Tap** the base to open its upgrade panel
- **Space** to start the next wave

### Mobile (iOS)
- **Tap** a tower button, then tap a tile to place
- **Tap** a placed tower to upgrade or sell
- **Tap** the base to upgrade it
- **Cancel** button to deselect a tower type

### Common
- **REPEL ASSAULT** to begin the next wave
- **Speed: 1x / 2x** to toggle fast-forward
- **Pause** to pause

## Economy

- Start with **8 lives** and **$450**
- Earn credits by killing enemies
- **Wave-clear bonus** scales with progress: wave x $15
- **Streak bonus**: +$25 x streak for each consecutive clean wave (no lives lost)
- **+1 life** every 3 waves cleared
- Towers can be placed during waves or between waves

## Waves

19 scripted campaign waves + a final boss wave (wave 20), followed by procedurally generated **Endless Mode** with exponential scaling. Bosses first appear on wave 4. Mega Bosses appear in endless mode from wave 30 onward. Enemy spawn order and spacing are randomized each wave.

## Running the Game

Requires [Godot 4.3](https://godotengine.org/download/).

```
godot4 --path Void_TD
```
