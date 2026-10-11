# Character addon overrides validation

Release validation: user testing confirmed shared desktop choices apply to the mage while the druid retains its FormFreedom and NugComboBar overrides after switching gamepad to desktop. No additional errors were reported. Native keybinding removal passed automated checks but was not separately tested in-game.

Native WoW keybinding capture and restoration have been removed. Existing SetupSwap binding snapshots and queued binding restores are discarded without applying them. ConsolePortBindingSet and ConsolePortLoaderBinding are excluded from settings capture/restoration, including older snapshots. Addons can still manage their own bindings when enabled or use other binding options stored inside their settings.

Profiles retain their shared names and account addon selections. Customize addons for this specific character saves only addon-selection differences for the current realm/character. Both talent specs use those addon choices. Abilities retain their separate character/spec snapshots. Addon settings, window positions and chat are still shared per profile.

## Installation

SavedVariables: KEEP. Client: CLIENT RESTART. Close WoW, back up WTF, and replace both SetupSwap and !SetupSwapLoader addon folders. Do not delete your existing profiles. Keep a pre-test WTF backup if you want to return to a release that restores old keybinding snapshots.

## Test checklist

1. On the healer, select desktop. Check Customize addons for this specific character. Enable HealBot and click Save overrides, then Switch + Reload. Verify HealBot is enabled and the editor displays the character scope and [override] marker.
2. Switch desktop to gamepad and back. HealBot should follow only the healer's saved desktop choice. Confirm abilities still restore.
3. Log into the mage and run /ss desktop. Its bars should remain unchanged unless already captured for that character/spec. It should use the shared addon list and should not inherit the healer's HealBot override.
4. On the mage, edit a different addon with the character checkbox unchecked and Save shared. Return to the healer: that shared change should carry over while its HealBot override remains.
5. On the healer, uncheck the character option and save. The list resets to shared choices; switching should use them. Other characters' overrides must remain intact.
6. Give desktop and gamepad different native WoW keybindings, then switch and save settings. SetupSwap should no longer replace native bindings. ConsolePort can still apply its own controller bindings when it loads.
7. Verify Save + Switch retains the character option, Use current respects the selected scope, and reopening the editor displays the saved scope correctly.
8. Check /ss log for errors and verify existing chat/layout restoration.

Automated checks simulate client behavior and parse Lua; actual WoW UI and addon callbacks require in-game testing.
