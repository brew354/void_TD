# Void TD

A space-themed tower defense game built with Godot 4 and GDScript.

## Gameplay

Defend your base from waves of enemies by placing towers on the grid. Enemies follow a fixed path — if they reach the base you lose lives. Let the boss through and it's instant game over.

**10 waves** of increasing difficulty. Boss enemies appear on waves 3, 6, 9, and the finale (wave 10 sends two bosses).

## Towers

| Tower | Cost | Damage | Range | Notes |
|-------|------|--------|-------|-------|
| Laser | $50 | 10 | 180 | Fast fire rate, single target |
| Cannon | $100 | 40 | 150 | AoE splash damage |
| Missile | $150 | 80 | 300 | Longest range, highest damage |

### Upgrades

Towers can be upgraded up to level 3 between waves. Double-click a placed tower to open the upgrade panel.

| Level | Damage | Range | Cost (Laser / Cannon / Missile) |
|-------|--------|-------|----------------------------------|
| L1 | 1.0× | 1.0× | — |
| L2 | 1.6× | 1.3× | $25 / $50 / $75 |
| L3 | 2.5× | 1.6× | $50 / $100 / $150 |

Selling a tower refunds **50% of total invested** (base cost + upgrades paid).

## Enemies

| Enemy | HP | Speed | Reward | Notes |
|-------|-----|-------|--------|-------|
| Scout | 50 | Fast | $5 | Basic enemy |
| Tank | 500 | Slow | $40 | Heavy, costs 3 lives on exit |
| Boss | 2000 | Slow | $200 | Stuns nearby towers every 4s — instant game over if it exits |

Enemy HP and speed scale up each wave (up to 2.62× by wave 10).

## Controls

- **Left-click** a tower button, then left-click a tile to place
- **Double-click** a placed tower to open the upgrade / sell panel (between waves only)
- **Right-click** a placed tower to sell it instantly (50% of total invested)
- **START WAVE** to begin the next wave
- **Speed: 1x / 2x** to toggle fast-forward
- **Pause** to pause

## Economy

- Start with **$200**
- Earn credits by killing enemies
- **+$50 bonus** on wave completion
- Towers can be placed during waves

## Running the Game

Requires [Godot 4.3](https://godotengine.org/download/).

```
# Open the project
godot4 --path Void_TD

# Run headless tests
godot4 --headless --path Void_TD --script validate.gd
```
