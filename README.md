# SetupSwap

![SetupSwap featured artwork](SetupSwap/docs/SetupSwap-featured.png)

**Your addons, your layout, your abilities—ready for the way you want to play.**

SetupSwap saves reusable setups for **World of Warcraft: Wrath of the Lich King 3.3.5a**.  Each profile can remember which addons are enabled, their captured settings and positions, your chat layout, and the abilities assigned to your action bars.  Switch from the settings window, a slash command, or the minimap button to bring that setup back.

Move from your desktop to handheld remote play on the couch.  Swap a questing interface for a focused raid layout.  Keep the same addon in several profiles with different settings and positions.  Set it up once, save it, and return to it when you need it - all without ever logging out of the game.

## A setup for every way you play

- **Desktop to couch:** Instantly swap between a mouse and keyboard desktop setup or a ConsolePort controller setup, with different addons, window positions, chat layouts, and ability arrangements.
- **A restore point for your current setup:** save settings before experimenting with addon options, window positions, chat, or abilities.  Reapply that same profile to return to the saved setup; you can use SetupSwap without switching to a different profile.
- **Questing and leveling:** enable your quest tracker, navigation tools, and leveling helpers, with room to read objectives and explore.
- **Raids and dungeons:** disable questing addons you do not need and enable your encounter tools, raid utilities, and group interface.  Restore the questing setup when the run ends.
- **PvP and arenas:** maintain a separate selection of combat tools, screen layouts, and ability arrangements for competitive play.
- **Farming, gathering, and the auction house:** bring up the maps, trackers, crafting tools, and trading addons that suit the task.
- **Different roles or activities:** build setups for healing, tanking, damage, casual play, or a cleaner screen for screenshots.  Activation is manual, so you choose when to switch.
- **The same addon, different preferences:** an addon shared by two profiles can have different captured settings, visible windows, and positions in each.  Your navigation window can sit neatly in a desktop layout and move out of the way of controller bars in another.

SetupSwap does not provide remote streaming or controller input itself.  It remembers the interface setups you use with those tools.  ConsolePort and the addons mentioned above are examples, not required dependencies.

## What a profile can remember

| Part of your setup | What SetupSwap saves |
| --- | --- |
| Addon selection | Enabled and disabled addons, including enabled load-on-demand modules |
| Addon settings | Detected serializable SavedVariables and supported native addon profiles |
| Window layouts | Detected addon frame positions and supported layout settings |
| Chat | Blizzard chat window configuration and positions |
| Action bars | Spells, items, existing macros, companions, equipment sets, and empty slots, saved separately for each character and talent spec |

Settings capture discovers addon data automatically rather than requiring a hand-written integration for every addon.  It supports ordinary SavedVariables, recognized AceDB databases, and detected movable frames.  There is no artificial byte, entry, or nesting limit on capture; available game memory and serializable data still set practical limits.

Profiles are **account-wide** and available to your other characters.  You can also use a profile for addon selection alone by leaving settings restoration disabled.

## Customize addons for one character

Profiles keep their shared names across your account. Select `desktop`, check **Customize addons for this specific character**, choose that character's addons, and click **Save overrides**. For example, enable HealBot only on your healer's desktop setup while your mage keeps the shared desktop selection. Switch normally with `/ss desktop`, `/ss gamepad`, or the minimap button; SetupSwap applies the current character's overrides automatically.

Only differences from the shared selection are saved, keyed by realm and character. Addons without an override inherit later shared changes. These choices apply to both talent specs. The window shows **Shared addon selection** or **Character overrides: realm/character**, and changed addons are marked **[override]**. Uncheck the option and save to remove this character's overrides and return to the shared selection. **Save shared** edits the account selection; other characters' overrides remain intact.

The character option affects addon selection only. Addon settings, positions, and chat remain shared per profile. Ability assignments remain separate per character and talent spec. Saving settings on another character replaces that profile's shared settings snapshot.

`/ss save NAME` saves current enabled addons as character overrides when that character already has overrides for the named profile; otherwise it saves the shared selection. Creating character overrides uses the checkbox in the editor.

## Installation

[Download SetupSwap.zip](https://github.com/SuttonX/SetupSwap/releases/latest/download/SetupSwap.zip)

1. Fully close WoW.
2. Extract **SetupSwap.zip**.
3. Place both **SetupSwap** and **!SetupSwapLoader** in `Interface/AddOns`.
4. Enable both addons and log in.

The included startup helper allows settings to be restored early during profile switches.  No separate addon download is required.  For updates, replace both folders and keep your SavedVariables.

## Save your first complete setup

1. Open `/ss` or left-click the minimap button.
2. Enter a profile name and choose its addons.  **Use current** populates addons currently enabled by the player, including enabled modules that are not loaded in memory.
3. Click **Save shared** (or **Save overrides** for a character selection).  This saves **only the enabled/disabled addon list**.  It does not capture settings, positions, chat, or action bars.
4. Click **Switch + Reload** to activate that profile.  A newly named profile also offers to enable its addons immediately.
5. Arrange the UI and abilities.  Configure the addons and chat the way you want them.
6. Reopen SetupSwap and click **Save settings & positions**.  This captures the setup, including action-bar assignments, using a reload to flush addon settings.

**Saving or selecting a profile in the editor does not activate it.  Switch to it before saving its settings.**

Repeat for your other setups.  Save settings again after changing positions, addon configuration, chat, or action-bar assignments.

## Switch your way

- **Settings window:** select a profile, then click **Switch + Reload**.
- **Quick command:** type `/ss desktop`, `/ss gamepad`, or `/ss` followed by your saved profile name.
- **Minimap menu:** right-click the minimap button and choose a saved profile.

The editor automatically selects a profile whose saved addon list matches the currently enabled addons.  **Select profile** brings another profile up for editing; it does not switch to it.

Switches normally aim to finish with **one reload**.  When early restoration is unavailable, a **Continue Reload** prompt provides the second-reload fallback.  UI hangups after switching can usually be resolved with an additional `/reload` command.  Switching and settings capture must happen outside combat.

## Clear choices before a settings overwrite

When **Save settings & positions** detects that the selected profile or edited addon list differs from the enabled addons, it offers:

- **Save + Switch:** save the displayed addon list and activate it.  Arrange that setup, then save its settings separately.
- **Overwrite:** deliberately capture the current in-game setup into the selected existing profile, keeping its saved addon list and without switching profiles.
- **Cancel:** leave everything unchanged.

If two profiles have identical addon selections, profile detection cannot automatically identify the current profile.  Choose the correct name from the list before saving settings.

## Adding or removing addons

After installing a new addon, update and save the addon list in each profile that should use it.  **Switch to that profile**, configure the addon and ability placement, and then save settings again.  An addon missing from an older profile's list is disabled when that profile is activated.

Questie tracker rows and resize handles remain managed by Questie; SetupSwap restores the main tracker position without reanchoring its internal components. Older captures remain usable without resaving.

Deleted addons are ignored when matching the installed addon list.  SetupSwap does not install addons or recreate deleted addon folders.

## Commands and reporting

| Command | Action |
| --- | --- |
| `/ss` | Open the settings window |
| `/ss` *name* | Activate a saved profile |
| `/ss list` | List saved profiles |
| `/ss new` *name* | Create an addon-list profile from current enabled states |
| `/ss save` *name* | Save current enabled states to a profile |
| `/ss command` *name* *shortcut* | Assign an optional direct shortcut, such as `/desk` |
| `/ss log` | Open a selectable, copyable diagnostic report |
| `/ss undo` | Restore the last settings backup for the current character |

`/setupswap` is also available.  Existing slash commands from other addons are not replaced.

For an issue report, include the SetupSwap version, affected addons, reproduction steps, and the text from **`/ss log`**.  It includes capture details and restore results without requiring a separate error-catching addon.

## Compatibility and capture scope

Addon settings capture includes selected addons that are loaded.  Open any desired load-on-demand modules before saving their settings.  Unsupported data, cyclic tables, and settings that cannot be discovered or serialized are reported rather than guaranteed to restore.  Ordinary SavedVariables may contain addon history or data as well as preferences.

SetupSwap does not capture, restore, or save native WoW keybindings. Old SetupSwap keybinding snapshots are discarded without changing your current bindings. ConsolePortBindingSet and ConsolePortLoaderBinding are excluded from settings capture and from restoring older snapshots. Controller override bindings remain managed by their owning addons. Captured addon settings can still contain an addon's own binding configuration. Action-bar assignments are captured separately; existing macros are matched by name, contents, and account/character scope, without creating or editing macros.

SetupSwap is a setup manager, not a filesystem backup.  Keep a backup of your WTF folder with WoW closed before making major configuration changes.

## Separate ability arrangements for desktop and gamepad

Arrange your abilities for ElvUI or Blizzard bars in your desktop profile, then click **Save settings & positions**.  Switch to your gamepad profile, arrange abilities for ConsolePort, and save again.  Switching profiles restores the corresponding native action slots; the two interfaces do not need matching visible bars.

Each profile keeps a separate action-bar snapshot for each character and talent spec.  Save each spec separately.  Older profiles and character/spec combinations without a saved snapshot leave your bars unchanged.  Save settings again to add action bars to an existing profile.

Unavailable spells, missing items, deleted or edited macros, and unsupported actions leave their destination slots unchanged and are reported in `/ss log`.  Spell ranks are matched exactly.  Pet, vehicle, and possession controls are excluded.  Save outside combat and vehicles, with nothing on the cursor.  `/ss undo` includes the action-bar backup for the current character/spec.

## Related projects

- [ConsolePortLK Enhanced](https://github.com/SuttonX/ConsolePortLK-Enhanced): an improved version of the ConsolePort backport for WotLK 3.3.5a.
- [FormFreedom](https://github.com/SuttonX/FormFreedom): automatic druid form cancellation for supported actions.

These are separate, optional projects and are not bundled with SetupSwap.

Created by **SuttonX**.  Released under the **MIT license**.
