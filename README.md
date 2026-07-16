# XPM-8 — An 8v8 Versus Overhaul for XPMod (Left 4 Dead 2)

A personal Left 4 Dead 2 dedicated server project: converting [XPMod](https://xpmod.net) — an RPG-mechanics SourceMod plugin originally built around 4v4 Versus — into a fully working **8v8 Versus** experience, plus a set of custom progression features layered on top (Prestige ranks, player-selectable name tags, and Special Infected class balancing).

This repository is the server owner's own dedicated box: the XPMod plugin source, the [AnyBotManager](https://forums.alliedmods.net/showthread.php?t=298829) bot-population plugin, and the live server config, all in one place so changes to any of them can be tracked together.

> **This is a solo hobby project**, not a public mod release. The docs below describe what actually exists and how it actually gets built and deployed — nothing here is aspirational.

---

## Table of Contents

- [Description](#description)
- [Features](#features)
- [File Structure](#file-structure)
- [Build & Deployment](#build--deployment)
- [Installation / Setup](#installation--setup)
- [Usage](#usage)
- [Components / Modules](#components--modules)
- [Technologies Used](#technologies-used)
- [Screenshots / Demo](#screenshots--demo)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

---

## Description

[XPMod](https://xpmod.net) turns Left 4 Dead 2 into an RPG: players earn XP, level up, unlock per-character talents, and trigger active abilities via two bindable hotkeys. It was originally designed and balanced around 4v4 Versus.

This project's goal is running that same plugin on an **8v8 Versus** server instead — double the players per side — which exposed a long list of assumptions baked into the original code (hardcoded player-count math, bind-dispatch bugs that only show up with more Infected classes in play simultaneously, bot AI that never learned to path to the saferoom on its own, round-end logic that didn't reliably detect an 8-player wipe, and more). On top of the conversion, several new features were built specifically for this server: a **Prestige** rank system with its own icon set, a player-facing **Customize** menu for cosmetic name tags, and a **Special Infected class cap + reroll** system to stop, e.g., three Spitters spawning at once on an 8-player Infected team.

Everything in [Features](#features) and [Components / Modules](#components--modules) below was built, debugged, and live-tested directly against this server.

---

## Features

### 🎮 8v8 Bind System Overhaul
- Fixed a bind-dispatch bug where every Infected class's `Bind 2` silently did nothing.
- Fixed all 12 Infected `Bind1`/`Bind2` files checking a stale "3 saved class slots" array instead of the player's live, currently-spawned class — a desync that got worse the more Infected players (bots included) were on a team at once.
- Added missing "you don't have the talent for this" hint-text branches across every Survivor bind, so a bind press with no unlocked talent always gives feedback instead of failing silently.
- Fixed Ellis's ammo-resupply talent consuming all 3 bind charges per use instead of 1.
- Rebindable via `sm_xpmod_bind1` / `sm_xpmod_bind2` ConVars, with the original `xpmbind1`/`xpmbind2` commands always kept registered so existing player configs never break.
- Chat fallback (`!bind1`, `!bind2`, `!skill1`, `!skill2`) for anyone who hasn't bound a key.
- Debug logging throughout via the existing `xpmod_debug_mode` verbosity levels, replacing ad-hoc chat-spam debug prints.

### 🧟 Bot AI & Round Flow (8-player-aware)
- Bots on an empty Survivor team now path to the saferoom on their own instead of freezing at spawn.
- A stuck-bot watchdog (`TimerCheckStuckBotSurvivors`) detects bots that are moving but not making flow progress, and nudges the group forward or regroups stragglers toward the point survivor.
- Versus rounds now reliably end when survivors reach the saferoom or the whole team is downed/dead, even in cases the map's own logic and a third-party plugin (`checkpoint_pity.smx`) weren't catching consistently.
- Fixed a bot-population deadlock in AnyBotManager that could leave an 8v8 Infected team with **zero bots** and no way to refill, by correcting an early-return condition in its fill timer.

### ⭐ Prestige System
- Players who hit level 30 can Prestige: reset level/talents/loadout, permanently keep a Prestige rank shown next to their name.
- Ranks 1–10 show a plain, always-readable `P<n>` + emoji preset (`P1⭐` … `P10👑`); ranks 11–45 use custom Private-Use-Area icon codepoints rendered by a bundled custom font on the client.
- Prestige rank is now actually persisted to the database (previously loaded but never saved — a real pre-existing bug that was silently discarding everyone's prestige on reconnect).

### 🏷️ Customize Menu (Player Name Tags)
- A new **Customize** menu (Extras → Customize, unlocked at level 30) lets players pick a cosmetic tag shown next to their name, e.g. `[30][👑] PlayerName`.
- Includes emoji tags (👑 🎮 🎰 🎲 🎯 💀) open to everyone, plus `OWNER` / `ADMIN` tags restricted to actual SourceMod admins.
- Picking your currently-selected tag again clears it.

### ☣️ Special Infected Class Cap + Reroll
- Bot/Director-assigned Special Infected spawns are capped at 2 of any one class at a time (no more triple-Spitter rounds), enforced via a `left4dhooks` pre-spawn hook that redirects over-cap spawns to whichever class is least represented.
- A new `xpmreroll` console command lets a human player reroll their upcoming class while still a ghost.

### 🛠️ Admin & Dev Tools
- The server owner's SteamID granted full SourceMod admin.
- A "Dev: Max XP/Talents" button in the Admin Menu instantly maxes level and talents for live testing, without needing to grind.

### 🔌 Server Reliability Fixes
- Corrected GSLT token and `sv_allow_lobby_connect_only` misconfiguration that was blocking direct connects.
- MariaDB connection recovery after an unexpected shutdown.

---

## File Structure

```
XPM-8/
├── README.md                          # This file
├── XPMod-master/                      # The XPMod plugin itself (see its own README.md for base-mod docs)
│   ├── xpmod.sp                       # Plugin entry point (#includes every file below)
│   ├── xpmod.smx                      # Compiled plugin binary (built from source, see Build & Deployment)
│   ├── spcomp.exe / spcomp / spcomp64*# Bundled SourcePawn compiler
│   ├── win_xpmodcompile.bat           # Windows build script
│   ├── xpmodcompile.sh                # Linux build script
│   ├── include/                       # SourceMod + left4dhooks includes
│   ├── sql/database_creation.sql      # MySQL/MariaDB schema (users, bans, stats, prestige, etc.)
│   └── XPMod/
│       ├── GlobalVariables/           # Constants, ConVars, offsets, Prestige_Icons.sp, Custom_Tags.sp
│       ├── XP/                        # XP earning, leveling, RenamePlayerWithLevelTags
│       ├── Database/                  # MySQL persistence layer (Models/, User_Management.sp)
│       ├── Menus/                     # In-game menus (Menu_Main.sp incl. Customize, per-character menus)
│       │   ├── S/                     # Survivor menus
│       │   └── I/                     # Infected menus + Tank variants
│       ├── Talents/                   # Character ability implementations (S/ + I/)
│       ├── Binds/                     # Hotkey ability activation (Bind1/, Bind2/, Binds.sp)
│       ├── Timers/                    # Recurring timer logic (stuck-bot watchdog, SI display, etc.)
│       ├── Events/                    # Game event handlers (round end, death, incap, spawn)
│       └── Misc/                      # InfectedClassCap.sp, admin commands, debug tools, bot pathing
├── AnyBotManager/
│   └── ABM-master/
│       ├── README.md / CHANGELOG.md / LICENSE
│       └── addons/sourcemod/scripting/abm.sp   # Bot population management
├── l4d2server/                        # Live dedicated server files
│   ├── start_server.bat               # Server launch script (GSLT token, etc.)
│   └── left4dead2/
│       ├── cfg/server.cfg             # Server config (lobby-connect, rates, etc.)
│       └── addons/sourcemod/
│           ├── configs/               # admins_simple.ini, databases.cfg, etc.
│           └── plugins/               # Deployed compiled .smx files (xpmod.smx, abm.smx, ...)
├── XP Safedoor/                       # Related standalone plugin (checkpoint_pity.sp, safedoor.sp)
└── ACS/                                # Separate, unrelated plugin bundled in this repo
```

---

## Build & Deployment

**There is no automated CI/CD pipeline for this project** — no GitHub Actions, no build server. This is a single-developer hobby project where changes are compiled and deployed by hand on the machine that also runs the game server. If that's something you want to add later (e.g. a GitHub Actions workflow that runs `spcomp` on every push and fails the build on compiler errors/warnings), it's a reasonable next step, but it doesn't exist today — don't assume otherwise from this README.

The actual process, every time:

1. **Compile:**
   ```bash
   cd XPMod-master
   ./spcomp.exe xpmod.sp -oxpmod.smx      # Windows
   # or: ./xpmodcompile.sh                 # Linux
   ```
   Check the output for errors/warnings. At the time of writing, the only warnings are two pre-existing unused functions (`GetClientTop10Position`, `GetTop10Symbol`).

2. **Deploy:** copy the compiled binary into the live server's plugin folder:
   ```bash
   cp XPMod-master/xpmod.smx l4d2server/left4dead2/addons/sourcemod/plugins/xpmod.smx
   ```

3. **Reload:** either restart the server process, or use SourceMod's `sm plugins reload xpmod` from RCON/console if the server is already running.

4. Any AnyBotManager (`abm.sp`) changes go through the same compile → copy → reload cycle, targeting `addons/sourcemod/scripting/abm.sp` → compiled into `addons/sourcemod/plugins/`.

Database schema changes (e.g. adding a new column) are applied by hand directly against the running MariaDB instance — there are no migration files or a migration runner, just `ALTER TABLE` statements run manually and mirrored into `sql/database_creation.sql` for anyone setting the database up from scratch.

---

## Installation / Setup

1. **L4D2 Dedicated Server** — set up via SteamCMD, with a valid [Game Server Login Token (GSLT)](https://steamcommunity.com/dev/managegameservers) configured in `start_server.bat`.
2. **SourceMod** (1.10+) installed under `left4dead2/addons/sourcemod/`.
3. **left4dhooks** extension/plugin installed (required by `InfectedClassCap.sp`'s `L4D_OnSpawnSpecial` hook and other native calls throughout XPMod).
4. **AnyBotManager** (`abm.sp`) installed for bot population management in Versus.
5. **MariaDB / MySQL** — create the database and schema from `XPMod-master/sql/database_creation.sql`, then add the connection details to `addons/sourcemod/configs/databases.cfg`:
   ```
   "xpmod"
   {
       "driver"    "mysql"
       "host"      "127.0.0.1"
       "database"  "xpmod_db"
       "user"      "xpmod"
       "pass"      "<your password>"
   }
   ```
6. **Admin access** — add your SteamID to `addons/sourcemod/configs/admins_simple.ini` with the flags/immunity level you want.
7. **Server config** (`l4d2server/left4dead2/cfg/server.cfg`) — notably `sv_allow_lobby_connect_only 0` if you want players to be able to connect directly by IP rather than only via matchmaking lobby.
8. Compile and deploy the plugin per [Build & Deployment](#build--deployment) above, then launch via `start_server.bat`.

---

## Usage

**Binds** (rebindable, see `sm_xpmod_bind1`/`sm_xpmod_bind2`):
```
bind mouse4 xpmbind1
bind mouse5 xpmbind2
bind <key>  xpmreroll     ; reroll your Special Infected class while still a ghost
```
Chat fallback if you haven't bound a key: type `!bind1`, `!bind2`, `!skill1`, or `!skill2`.

**Menus** — type `!xpm` / use the default menu key SourceMod binds, or use the specific commands:
```
!xpmstats       ; your team's stats
!xpmbinduses    ; remaining bind charges
!buy            ; loadout menu
!banme          ; quick self-ban
```
From the main menu → **Extras**:
- **Prestige** (level 30+) — reset for a permanent rank icon next to your name.
- **Customize** (level 30+) — pick a cosmetic name tag.

**Admin commands** (require SourceMod admin access):
- Admin Menu → **Dev: Max XP/Talents** — instantly maxes your level/talents for testing.
- `sm_xpmod_debug_mode <0-4>` — set debug verbosity.

---

## Components / Modules

### Binds System (`XPMod/Binds/`)
`Binds.sp` registers `xpmbind1`/`xpmbind2` and dispatches to a per-character/per-class file (`Bind1/S/Bind1_<Name>.sp`, `Bind1/I/Bind1_<Class>.sp`, etc.) based on the player's team and currently-spawned character/class. Each file checks the player's unlocked talent level before firing its ability, and now always gives hint-text feedback when the ability isn't unlocked or is on cooldown, instead of failing silently. The Infected files check `g_iInfectedCharacter[iClient]` (the live, dispatch-validated class) rather than the older `g_iClientInfectedClass1/2/3` "saved slots" array, which could desync from what the player was actually currently playing.

### Prestige (`XPMod/GlobalVariables/Prestige_Icons.sp`, `XPMod/XP/XP_Management.sp`)
`PRESTIGE_ICONS[]` maps a 1-based prestige rank to a display string — plain `P<n>` + emoji for ranks 1-10, Private-Use-Area codepoints (rendered by a custom client-side font) for ranks 11-45. `GetPrestigeSymbol()` looks up (and cycles through) that table. `RenamePlayerWithLevelTags()` in `XP_Management.sp` builds the final `[<symbol>] <name>` (or `[<symbol>][<tag>] <name>` if a Customize tag is also set), computing the real assembled length against L4D2's 31-character name cap rather than an estimate, so a long symbol can't silently truncate mid-character. `PrestigePlayer()` resets a player's progress via the existing `ResetAll()` path, then restores the incremented prestige count and saves it.

### Custom Tags / Customize Menu (`XPMod/GlobalVariables/Custom_Tags.sp`, `XPMod/Menus/Menu_Main.sp`)
`CUSTOM_TAGS[]` holds the selectable tag strings; a parallel `CUSTOM_TAG_ADMIN_ONLY[]` marks which ones (currently `OWNER`, `ADMIN`) are restricted to admins. `CustomizeMenuDraw`/`CustomizeMenuHandler` in `Menu_Main.sp` render the picker (hiding admin-only tags from non-admins) and apply a selection by setting `g_iClientCustomTag[iClient]` and re-running `RenamePlayerWithLevelTags`.

### Special Infected Class Cap + Reroll (`XPMod/Misc/InfectedClassCap.sp`)
`CountLiveInfectedOfClass()` counts currently-alive Infected players of a given class; `PickInfectedClassUnderCap()` finds the least-populated class still under the cap. A `L4D_OnSpawnSpecial` hook (a `left4dhooks` forward, bot/Director-spawns only) redirects a spawn to a less-populated class if the requested one is already at the cap. `Command_InfectedReroll` (`xpmreroll`) lets a human player still in ghost state request a specific under-cap class for their own next life.

### Bot Pathing & Round Flow (`XPMod/Misc/ScriptCommands.sp`, `XPMod/Timers/Timers_Generic.sp`, `XPMod/Events/Events_Main.sp`)
`TimerCheckStuckBotSurvivors` periodically compares each bot survivor's position and flow progress against the furthest-along ("point") survivor, nudging stragglers to regroup or the whole team forward if collectively stalled. `ForceVersusRoundEndIfNeeded`/`CheckForVersusSurvivorWipe`/`AreAllSurvivorsDownOrDead` in `Events_Main.sp` detect saferoom-reached and full-team-wipe conditions and force the round to end via `left4dhooks`' `L4D_EndVersusModeRound` when the map/mode's own logic doesn't reliably do so.

### Database Layer (`XPMod/Database/`)
`Models/DB_Users.sp` defines the `users` table's column layout as index constants + a name array, consumed by `User_Management.sp`'s load/save queries so a single range (`DB_COL_INDEX_USERS_XP` .. `DB_COL_INDEX_PUSH_UPDATE_FROM_DB`) drives the SELECT column list. `prestige_points` and the newer `custom_tag_id` columns were both added to this pattern — the load side reads them into globals on connect, the save side writes them back on disconnect/interval saves.

### AnyBotManager Integration (`AnyBotManager/ABM-master/addons/sourcemod/scripting/abm.sp`)
Manages bot population to keep both 8-player teams filled. This session fixed a deadlock in its fill timer (`ADTimer`) where a specific combination of `g_MaxMates == 0` and a freeze flag could leave a team permanently under-filled with no path back to refilling, and removed a per-tick debug log line that was spamming the console.

---

## Technologies Used

| Technology | Role |
|---|---|
| [SourcePawn](https://wiki.alliedmods.net/SourcePawn) | Plugin implementation language |
| [SourceMod](https://www.sourcemod.net/) 1.10+ | Plugin runtime/API for the Source engine |
| [left4dhooks](https://forums.alliedmods.net/showthread.php?t=189949) | L4D2-specific natives/forwards (Director hooks, Versus round control, flow distance) |
| [AnyBotManager](https://forums.alliedmods.net/showthread.php?t=298829) | Bot population management for Versus |
| MariaDB / MySQL | Player data persistence (XP, level, talents, prestige, custom tags, bans, stats) |
| Steam GSLT | Dedicated server authentication with Steam |
| Windows Server | Hosting environment for this particular deployment |

---

## Screenshots / Demo

_Not yet included in this repository._ If you want to add some:

- Drop images under a new `docs/screenshots/` folder.
- Reference them here, e.g.:
  ```markdown
  ![Customize menu](docs/screenshots/customize-menu.png)
  ![Prestige confirmation](docs/screenshots/prestige-confirm.png)
  ```
- A short clip of the SI reroll or the stuck-bot nudge system in action would be the most useful demo material, since both are hard to describe in a still image.

---

## Contributing

This is a personal server project maintained by one person, not an open contribution project. That said, if you're poking around this repo and want to suggest a change:

1. Open an issue describing the bug or the change you have in mind before writing code — several "fixes" in this history turned out to depend on details of this specific server's config (8 players/team, specific ConVars, specific third-party plugins installed alongside XPMod).
2. Keep changes scoped — this codebase has a lot of near-identical per-character files (12 Bind files, 8 Survivor menus, 6 Infected talent files); a fix that applies to one usually needs to be checked against all its siblings rather than assumed to be universal.
3. Compile with `spcomp` and confirm zero new warnings/errors before proposing a change (see [Build & Deployment](#build--deployment)).

---

## License

The base **XPMod** plugin (`XPMod-master/`) is licensed under the **GNU General Public License v3.0** — see `XPMod-master/LICENSE`. Any modifications in this repository to XPMod's own source are derivative works of a GPLv3 project and remain governed by those same terms if redistributed.

**AnyBotManager** (`AnyBotManager/ABM-master/`) is licensed separately under **GPLv2+** by its original author — see `AnyBotManager/ABM-master/LICENSE`.

The server configuration files, and any genuinely new standalone files added for this project (e.g. `InfectedClassCap.sp`, `Custom_Tags.sp`, `Prestige_Icons.sp`), are not separately licensed here; treat them as covered by the same GPLv3 terms as the codebase they're integrated into, since they only function as part of it.

---

## Acknowledgments

- **XPMod** — originally created by **Chris Pringle** and **Ezekiel Keener**. See [xpmod.net](http://xpmod.net) and the upstream [`XPMod-master/README.md`](XPMod-master/README.md) for the base mod's full feature set and credits.
- **AnyBotManager** — originally created by **Victor "NgBUCKWANGS" Gonzalez**.
- **left4dhooks** — the AlliedModders / SirPlease community, whose extension makes the Special Infected class cap, Versus round-end control, and other Director-level hooks in this project possible.
- The 8v8 conversion, bug fixes, and every feature listed under [Features](#features) above were designed, implemented, tested, and deployed collaboratively across an extended pairing session between the server owner and Claude (Anthropic), working directly against the live dedicated server throughout.****
