# Shared layouts and action-bar-only saving

SetupSwap keeps TomTom's native saved arrow/block anchors in sync with
SetupSwap's restored window positions. It also releases the native per-character
window cache for these restored TomTom windows. Before a full settings capture,
the actual TomTom window anchors are saved into its active native profile.

Two position stores could disagree before this change, allowing a native TomTom
refresh to undo a generic window restore. Automated tests reproduce and cover
that conflict. User testing verified addon capture copying, both window layouts,
and the ElvUI skin before release approval. TomTom itself is unchanged and is not bundled.

**Save Action Bars / Macros** updates the active profile's current character/talent
spec placements. It preserves addon choices, character overrides, shared saved
settings, frame positions, chat, and other character/spec action bars. No reload
is needed. The profile must already be active and match the enabled addon set;
combat, vehicles, held cursor objects, and pending operations prevent capture.

The character override checkbox continues to affect only addon enable/disable
choices. **Save Addon Settings + Positions** still replaces the shared layout using
the current character's setup. Editing a tracked macro while SetupSwap is
enabled needs no recapture; moving it to a new action-bar slot does.

## Installation

SavedVariables: KEEP. Client: CLIENT RESTART.
Close WoW completely, back up WTF, and replace SetupSwap and !SetupSwapLoader
with the two folders at the ZIP root. Keep TomTom and all existing profiles.

## Druid/mage verification

1. On the druid, activate Desktop. Correct the TomTom arrow's position if the
   prior mage save replaced it. Keep character customization checked, with
   FormFreedom and NugComboBar as your overrides. Save Addon Settings + Positions once
   to establish the desired shared layout. Wait for all restore work to finish.
2. Log into the mage and explicitly run /ss desktop. Confirm the arrow appears
   in the druid's saved position before saving anything. Wait a few seconds,
   create a waypoint, and check it again. If it moves, copy /ss log immediately.
3. Move a mage macro or spell to a different slot. Use Save Action Bars / Macros.
   Verify there is no reload and no change to the TomTom arrow or chat layout.
4. Return to the druid and run /ss desktop. Confirm the arrow and druid's bars
   are unchanged and its two addon overrides remain enabled.
5. Establish the desired Gamepad layout on the druid using a full settings save
   once if necessary. On the mage, load Gamepad, arrange bars, and save bars only.
   Repeat Desktop/Gamepad switching on each character at least three times.
   Each profile should retain its shared arrow position and each character its
   own assignments. Check TomTom after setting/clearing waypoints and /reload.
6. Edit an ordinary blank-named macro's contents without saving. Verify all its
   saved placements still refer to that macro. Also check SmartTravel's dynamic
   macro in both profiles and your existing conditional macro placements.
7. If using dual spec, save bars only in the other spec and verify both specs.
   Check minimap shape, Questie tracker, addon states, settings, and chat.

Do not use a full settings save on the mage solely to save bar placements: a
full save intentionally updates shared settings and positions for that profile.
If step 2 fails, do not overwrite the shared capture; send the diagnostics from
that point so the live and native TomTom anchors can be compared.

Validation: 154 general regression checks, 706 UI geometry/skin checks, and eight native TomTom/AceDB checks
passed. Native checks use the supplied TomTom build's position persistence code
and AceDB library. The checklist above remains useful when validating a new client/addon combination.

## Relative window layout and individual addon copy

The editor derives control sizes, fonts, padding and row height from its container.
Text height is measured before the next section is placed. The save buttons have
an independent row. The addon list fills the remaining space above the footer,
with its visible row count and scrollbar step updated together. Screen/UI-scale
changes refit the window.

- Use `/ss ?` or `/ss help` to print all supported commands in chat.
- Use `/ss copynames` for a selectable popup listing short addon names and which
  profiles have captures for them. Names are generated from installed/captured
  addons; ambiguous names receive unique suffixes instead of guessing.
- Use `/ss copy ADDON FROM_PROFILE TO_PROFILE` to copy only that addon's saved
  settings and positions. For the reported case: `/ss copy tomtom gamepad desktop`,
  then `/ss desktop`. TomTom's captured options are copied too.
- Other addon captures, character overrides, enabled/disabled selections, global
  chat captures and native action bars are retained. The source is unchanged.
  Both profiles must exist; this copies snapshots, not live settings.

Additional verification:

1. Open /ss in both profiles and with character customization checked/unchecked.
   Confirm the scope text, legend, save buttons, list and footer do not overlap.
2. Change UI scale, reopen the window, and scroll to the last addon. Confirm the
   longer bars/macros button label fits and each button retains its function.
3. Run /ss ? and /ss copynames. Confirm the popup lists usable short names and
   remains selectable; Refresh refreshes that list, while /ss log opens logs.
4. Copy TomTom from Gamepad to Desktop, switch to Desktop, and check the arrow.
   Confirm other addon settings/positions and action bars have not changed.
5. Copy another captured addon between profiles using its listed short name.
   Switch to the target and verify settings/positions. Disabled addons stay
   disabled; they must be enabled to restore their settings.

## Split saves and compact ElvUI skin

Save Addon Settings + Positions captures addon settings, frame positions and chat
without reading native action slots or replacing saved action-bar snapshots.
Save Action Bars / Macros captures placements separately. Existing captures for
every character/spec are retained. Save both separately when setting up a new
profile. Macro contents continue to be managed by the client/addon that owns them.

The options window uses 65% of the screen height rather than 90%, with the same
relative layout. The heading reads SetupSwap vX.Y.Z from the TOC version; diagnostic
reports retain the complete addon version. ElvUI's native Skins handlers provide
the transparent frame and control appearance when ElvUI is loaded and ready.
ElvUI_AddOnSkins is not required, and no changes are made to either ElvUI addon.

Additional verification:

1. In Desktop with ElvUI, check the smaller window, title, native-looking controls
   and both save labels. Check hover tooltips, toggles, scrolling and close/reopen.
2. Change a bar placement, then save addon settings/positions only. Switch away
   and back: the previous saved assignment should return. Now change the placement
   and save action bars/macros: it should persist after switching.
3. On the mage, save addon settings/positions and confirm the druid's action bars
   still restore. Check TomTom as before. Shared addon settings remain shared.
4. In Gamepad without ElvUI, confirm the default WoW skin and the same compact
   layout. Repeat switching, copying settings/positions, /ss ?, and /ss copynames.
