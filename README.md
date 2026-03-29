# Void TD

A space-themed tower defense game built with Godot 4 and GDScript.

## Gameplay

Defend your base from 20 waves of enemies by placing towers on the grid. Enemies follow a fixed path — if they reach the base you lose lives. Survive all 20 waves to win, or keep going in **Endless Mode**.

Enemies spawn in randomized order and with variable spacing each wave, so no two waves play the same.

## Towers

| Tower | Cost | Damage | Range | Cap | Notes |
|-------|------|--------|-------|-----|-------|
| Laser Turret | $50 | 10 | 180 | — | Fast fire rate, single target. Visually upgrades at L2 and L3. |
| Plasma Cannon | $100 | 40 | 150 | 6 | AoE splash damage |
| Void-Seeker | $150 | 80 | 300 | 4 | Longest range, single target |
| Mecha Soldier | $300 | 150 | 220 | 4 | Heavy AoE, most powerful |
| Freeze Tower | $125 | — | 160 | 5 | Pulses every 7s, slowing all enemies in range to 40% speed for 2s |

**Maximum 30 towers total** on the field at once. The HUD shows your current count.

The **Freeze Tower** is a static crystal structure — no rotating barrel. Its range is always shown on the map. Upgrades increase its pulse area.

### Upgrades

Double-click a placed tower to open the upgrade panel. Towers can be upgraded to level 3.

| Level | Damage | Range | Cost (Laser / Cannon / Missile / Mecha / Freeze) |
|-------|--------|-------|--------------------------------------------------|
| L1 | 1.0× | 1.0× | — |
| L2 | 1.6× | 1.3× | $50 / $100 / $150 / $300 / $125 |
| L3 | 2.5× | 1.6× | $100 / $200 / $300 / $600 / $250 |

Selling a tower refunds **50% of total invested** (base cost + all upgrades paid).

## Enemies

| Enemy | HP | Speed | Reward | Notes |
|-------|-----|-------|--------|-------|
| Void Scout | 65 | 200 | $5 | Basic fast enemy |
| Void Tanker | 600 | 60 | $45 | Heavy, costs 3 lives on exit |
| Void Herald (Boss) | 2000 | 40 | $90 | Stuns nearby towers every 3.5s |
| Void Shade | 30 | 400 | $10 | Very fast, low HP |
| Void Sentinel | 350 | 75 | $70 | Periodically immune to damage |
| THE VOID (Mega Boss) | 5000 | 30 | $300 | Wave 20 only — armored phase, massive stun range |

Enemy **HP scales** each wave (up to 8× by wave 20). Enemy **speed also scales** gently (+2% per wave, up to ~40% faster by wave 19), so later waves demand tighter coverage.

## Controls

- **Left-click** a tower button, then left-click a tile to place
- **Double-click** a placed tower to open the upgrade / sell panel
- **Right-click** a placed tower to sell it instantly (50% refund)
- **REPEL ASSAULT** to begin the next wave
- **Speed: 1x / 2x** to toggle fast-forward
- **Pause** to pause

## Economy

- Start with **$300**
- Earn credits by killing enemies
- **Wave-clear bonus** scales with progress: wave × $8 (wave 1 = $8, wave 10 = $80, wave 19 = $152)
- **Streak bonus**: +$25 × streak for each consecutive clean wave (no lives lost)
- Towers can be placed at any time — during waves, between waves, or while paused

## Waves

20 scripted campaign waves followed by procedurally generated **Endless Mode**. Bosses first appear on wave 4 and become more numerous in later waves. Enemy spawn order and spacing are randomized each wave.

## Running the Game

Requires [Godot 4.3](https://godotengine.org/download/).

```
# Open the project
godot4 --path Void_TD

# Run headless tests
godot4 --headless --path Void_TD --script validate.gd
```
