# Action-bar assignments

Save and restore different ability arrangements when switching between desktop, gamepad, or custom profiles.

Save settings & positions now captures native player action slots alongside the existing settings, layouts, chat, and keybindings. Each profile retains separate snapshots per realm/character and active talent spec. The player slots include form-bar pages and the extra player page; possession slots 121–132 and separate pet controls are excluded.

Captured actions: spells with exact rank/identity, items, existing macros with matching name/body/scope, companions, equipment sets, and empty slots. Missing or unsupported entries leave their destination unchanged and appear in /ss log. No macros are created or edited. Restore waits for combat, vehicle/possession, held cursor objects, bindings, and required settings reloads. Switching or saving is blocked while restoration owns queued work. Placement failure attempts rollback of every attempted slot; rollback errors are reported if the client refuses it.

Profiles with no action-bar snapshot keep the current bars. Save each existing profile again to opt into this feature. Saving on one character/spec preserves the other action-bar snapshots for that profile. Addon settings remain subject to their existing capture scope; this change does not make all addon settings character-specific.

## Install and verify

Client: CLIENT RESTART. Keep SavedVariables. Close WoW and replace both SetupSwap and !SetupSwapLoader folders. Back up WTF with WoW closed before the first test, because native action assignments are server-persisted and are not covered by a WTF backup alone. The addon includes the pre-switch action snapshot in /ss undo, but that recovery still depends on the client accepting restoration.

1. Activate desktop. Arrange ElvUI abilities, including at least two different spell placements, an empty slot, and an existing macro. Save settings & positions.
2. Switch to gamepad. Arrange ConsolePort abilities differently on the base, LT, RT, and LT+RT bars. Save settings & positions.
3. Switch desktop → gamepad → desktop several times. Verify abilities, empty slots, macros, positions, chat, and the previously tested Q/E bindings restore together.
4. For a druid, check Cat/Prowl, Bear, and caster bars in both profiles; check modifier layers in each form. These use native player slots and need actual client testing.
5. Change one assignment, save the active profile, and confirm it persists after switching away and back and after logging out/in.
6. If using dual spec, save distinct arrangements in the second spec for both profiles. Switch profiles in each spec and verify each retains its own assignments. No automatic spec switching is performed.
7. An old profile without a recaptured settings snapshot should leave abilities unchanged. Another character without a saved snapshot should also keep their bars.
8. Check /ss log. If slots were skipped or the client refused a restore, copy the report. Leave combat/vehicles and put down cursor objects before saving. A switch restore already queued waits until those conditions clear.

Automated verification uses a simulated client and Lua 5.4 parsing. It covers capture, spellbook/macro reordering, missing actions, empty slots, exclusion of possession slots, rollback, exact ranks, character/spec isolation, retained snapshots, early/fallback staging, cursor/combat guards, and undo. It does not reproduce WoW's secure execution, server synchronization, or interactions with real ElvUI/ConsolePort callbacks. The release passed user testing in-game with desktop and gamepad profile switching.
