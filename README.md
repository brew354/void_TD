# Void TD

A space-themed tower defense game built with Godot 4 and GDScript. Runs on desktop and iOS.

## Gameplay

Defend your base from 20 waves of void-spawned enemies by placing towers on the grid. Enemies follow a fixed path — if they reach the base you lose lives. Survive the final boss on wave 20 to win, or switch to **Endless Mode** with procedurally scaling difficulty.

Choose **Campaign** or **Endless** from the main menu. Customize your loadout, browse the shop, and redeem codes before jumping in.

## Towers

Pick up to 5 towers for your loadout. Six tower types are available (Tesla Tower must be purchased from the shop first):

| Tower | Cost | Damage | Range | Cap | Notes |
|-------|------|--------|-------|-----|-------|
| Laser Turret | $50 | 10 | 180 | — | Fast fire rate, single target. Visually upgrades at L2 and L3. |
| Plasma Cannon | $100 | 40 | 150 | 6 | AoE splash damage (60px radius) |
| Void-Seeker | $150 | 80 | 300 | 4 | Longest range, single target |
| Titan Mech | $300 | 150 | 220 | 4 | Heavy AoE splash (45px radius) |
| Void Stunner | $125 | — | 160 | 5 | Pulses every 7s, slowing enemies 60% for 2s. Bosses take 2x damage while slowed. |
| Tesla Tower | $800 | 45 | 180 | 3 | AoE electric (50px). L2 adds burn (15 dps for 2s). L3 adds stun (1s, non-bosses). |

**Maximum 30 towers total** on the field at once. The HUD shows your current count.

### Upgrades

Tap a placed tower to open the upgrade panel. Towers can be upgraded to level 3.

| Level | Damage | Range | Cost |
|-------|--------|-------|------|
| L2 | 1.6x | 1.3x | Same as tower base cost |
| L3 | 2.5x | 1.6x | 2x tower base cost |

Selling a tower refunds **50% of total invested** (base cost + all upgrades paid).

### Base Upgrades

Tap the base to open its upgrade panel. Each level adds damage reduction, decreasing lives lost when enemies reach the base.

## Enemies

| Enemy | HP | Speed | Reward | Lives | Notes |
|-------|-----|-------|--------|-------|-------|
| Void Scout | 65 | 200 | $5 | 1 | Basic fast enemy |
| Void Tanker | 600 | 60 | $45 | 3 | Slow and heavy |
| Void Herald (Boss) | 2000 | 40 | $90 | — | Stuns nearby towers every 5s |
| Void Shade | 30 | 400 | $10 | 1 | Fastest, lowest HP |
| Void Sentinel | 350 | 75 | $70 | 2 | Cycles shield on/off — immune to damage while shielded |
| THE VOID (Mega Boss) | 4250 | 30 | $300 | 4 | Armored phase absorbs 80% damage until HP threshold, then speeds up 2x |

Enemy **HP scales** each wave (up to 5.5x by wave 20). Enemy **speed also scales** slightly each wave.

## Controls

### Desktop
- **1–5** to select a tower from your loadout
- **Left-click** a tile to place the selected tower
- **Click** a placed tower to open the upgrade / sell panel
- **Click** the base to open its upgrade panel
- **Space** to start the next wave

### Mobile (iOS)
- **Tap** a tower button, then tap a tile to place
- **Tap** a placed tower to upgrade or sell
- **Tap** the base to upgrade it
- **Tap** a selected tower button again to deselect

### HUD
- **Start Wave** to begin the next wave
- **1x / 2x** to toggle fast-forward
- **Pause** to freeze the game

## Economy

- Start with **8 lives** and **$450**
- Earn credits by killing enemies
- **Wave-clear bonus**: wave number x $15
- **Streak bonus**: +$25 per consecutive wave cleared without losing a life
- **+1 life** every 3 waves cleared
- Campaign win: **+150 coins** | Defeat: **+50 coins**

## Shop & Cosmetics

Open the **Shop** from the main menu to spend coins:

- **Tesla Tower** (800 coins) — unlocks the 6th tower type for your loadout
- **Ducky Skin** (200 coins) — golden tint for the Laser Turret

Skins are purely cosmetic. You can also tint any tower with 9 palette colors from the inventory.

## Code Redemption

Open **Codes** from the main menu and enter a code to claim rewards (coins, skins, or tower unlocks). Each code has limited total uses and can only be redeemed once per player.

## Loadout

Open **Inventory** from the main menu to manage your loadout. Equip up to 5 towers — only equipped towers appear in your HUD during gameplay. You must keep at least 1 tower equipped.

## Waves

20 scripted campaign waves with a final boss (THE VOID) on wave 20. Bosses first appear on wave 4. In **Endless Mode**, waves are procedurally generated with exponential scaling, and THE VOID appears from wave 31 onward.

## Running the Game

Requires [Godot 4.3](https://godotengine.org/download/).

```
godot4 --path Void_TD
```
