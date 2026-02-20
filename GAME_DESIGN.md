# Elemental Ninja Duels - Game Design Document

## Overview

**Game Name:** Elemental Ninja Duels
**Platform:** Roblox
**Genre:** Competitive 1v1 Arena Fighter
**Inspired By:** The Strongest Battlegrounds
**Art Style:** Slightly cartoony Roblox style — bright but not goofy, clean VFX, clear ability telegraphs

## Core Identity

- 1v1 arena duels
- No transformations
- No stat grinding — pure skill
- Clean hit detection
- Cooldown-based abilities
- Fast matches (2-4 minutes)

## Core Game Loop

1. Join lobby
2. Choose elemental ninja
3. Queue for 1v1 match
4. Fight best of 3 rounds
5. Gain rank points
6. Unlock cosmetics
7. Repeat

---

## Combat System (Balanced Pacing)

### Philosophy
- Short bursts of action with small neutral pauses
- Mind games and cooldown tracking
- Punish windows after commitments
- Skill ceiling high, entry barrier medium

### Controls

| Action | Input | Notes |
|--------|-------|-------|
| M1 Combo | Click/Tap | 4-hit chain, 4th hit has knockback |
| Ability Q | Q key | Quick ability (6-8s cooldown) |
| Ability E | E key | Medium ability (10-12s cooldown) |
| Ability R | R key | Heavy ability (14-16s cooldown) |
| Ultimate | F key | Charged by dealing damage |
| Block | Hold right-click | Reduces 70% damage, drains stamina |
| Dash | Double-tap direction | 1.5s cooldown, costs stamina |

### Combat Rules
- Every ability has startup frames, recovery frames, and counterplay
- Blocking too long drains stamina
- Heavy abilities can break block
- Ultimate meter charges from dealing damage (not time-based)
- All stats are equal across characters — abilities define playstyle, not power

---

## V1 Character Roster

### Flame Shadow (Fire Element)
**Playstyle:** Aggressive / Combo pressure
**Color:** Red / Orange

| Ability | Name | Description |
|---------|------|-------------|
| M1 | Katana Combo | 4-hit chain |
| Q | Fire Dash | Quick dash forward with flame trail, light damage |
| E | Flame Slash | Wide arc slash that burns over time |
| R | Inferno Trap | Fire bomb that explodes after 1.5 seconds |
| F | Crimson Cyclone | Spinning flame attack that launches opponent |

### Mist Blade (Water Element)
**Playstyle:** Speed + Evasion
**Color:** Blue / Cyan

| Ability | Name | Description |
|---------|------|-------------|
| M1 | Dual Blade Combo | 4-hit chain |
| Q | Water Step | Short teleport dash |
| E | Tidal Slice | Fast long-range wave slash |
| R | Mist Veil | Temporary blur effect (harder to hit) |
| F | Raging Current | Multi-hit dash combo |

### Storm Fist (Lightning Element)
**Playstyle:** Burst damage / Stun pressure
**Color:** Yellow / Electric Blue

| Ability | Name | Description |
|---------|------|-------------|
| M1 | Lightning Punch Combo | 4-hit chain |
| Q | Thunder Jab | Fast stun strike |
| E | Lightning Strike | Bolt from sky (aimed skillshot) |
| R | Static Field | Small AOE that slows opponent |
| F | Storm Breaker | Massive slam + lightning explosion |

### Shadow Fang (Shadow Element)
**Playstyle:** Counter / Mind games
**Color:** Purple / Dark Grey

| Ability | Name | Description |
|---------|------|-------------|
| M1 | Fast Dagger Combo | 4-hit chain |
| Q | Shadow Step | Teleport behind opponent (short range) |
| E | Dark Spike | Shadow spikes from ground |
| R | Counter Guard | Blocks next attack and auto-strikes |
| F | Nightfall Execution | Cinematic heavy strike finisher |

---

## Arena Design

- Small, symmetrical circular dojo platform
- Floating slightly above void
- Subtle elemental banners
- No random hazards, no power-ups, no RNG
- Spectator platform around edges
- Clean skybox
- Invisible walls to prevent falling

---

## Match System

- **Format:** Best of 3 rounds
- **Round Length:** 2-3 minutes max
- **Win Condition:** First to 2 round wins
- **Between Rounds:** Health resets, positions reset, brief freeze
- **Spawn Protection:** 2 seconds at round start

---

## Ranking System

| Rank | Order |
|------|-------|
| Bronze | 1 |
| Silver | 2 |
| Gold | 3 |
| Platinum | 4 |
| Diamond | 5 |
| Master | 6 |
| Grand Ninja | 7 |

- Win = gain rank points
- Lose = lose rank points
- ELO-style system

---

## Monetization (Cosmetics Only)

**Sell:**
- Ninja skins
- Katana/weapon skins
- Custom aura colors
- Custom finisher animations
- Ranked nameplates/borders
- Spectator emotes
- Element recolors
- Kill effects

**Never sell:**
- Damage boosts
- Cooldown reduction
- Stat advantages

---

## V1 Development Phases

### Phase 1: Core Combat (Build First!)
1. Basic movement
2. Health system
3. M1 combo system (4-hit chain)
4. Simple hit detection (raycast)
5. Knockback physics
6. Block mechanic

### Phase 2: Add Flame Shadow
- Fire Dash (Q)
- Flame Slash (E)
- Inferno Trap (R)
- Crimson Cyclone (F / Ultimate)

### Phase 3: 1v1 Match System
- Queue system
- Teleport 2 players to arena
- Round system (best of 3)
- Health reset each round
- Win counter

### Phase 4: Add Mist Blade
- Clone ability framework
- Swap moves + VFX
- Balance test

### Phase 5: Ranked Mode
- ELO-style point system
- Rank icons
- Win streak bonuses
- Matchmaking queue

### Phase 6: Polish
- Spawn protection
- Arena bounds
- Anti-exploit (server validates damage + cooldowns)
- Sound effects
- UI polish

---

## Future Scalability

- New elemental ninja every season
- New arena skins/themes
- Ranked seasons with resets
- Cosmetic battle pass
- Spectator tournaments
- Replay system
