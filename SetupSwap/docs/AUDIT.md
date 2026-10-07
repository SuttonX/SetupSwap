# SetupSwap pre-release audit — October 6, 2026

Reviewed all 11 Lua modules and both TOCs in the supplied 1.0.0 package.

## Corrections

- Block switching, capture, undo, and profile mutations while queued settings, bindings, chat, window restoration, or a Continue reload prompt is outstanding.
- Queue dependent bindings and layout work only after fallback SavedVariables restoration succeeds.
- Abort a fallback restore before applying variables if an expected native AceDB database is unavailable.
- Preserve saved snapshots, capture flags, and other serializable profile fields during legacy character-to-account migration. Preserve retry eligibility on migration failure.
- Return no automatic profile match when multiple profiles have identical enabled-addon lists. Select the intended profile manually.
- Apply the requested README wording in both copies.

## Verification

Nine simulated-client regression checks passed: migration; ambiguous detection; operation exclusion across each queued-work type; failed fallback staging; successful fallback; early restore; unready AceDB validation; binding rollback and success; deep serialization and cycle rejection.

All 11 Lua files parsed using the available Lua 5.4 library. Both TOCs reference existing files with exact case. No Lua 5.4-only syntax was introduced. The simulation does not reproduce WoW's secure execution, event ordering, addon callbacks, or persistence implementation; the actual WoW 3.3.5a client test was subsequently completed by the user.

## Final in-game check

1. With WoW closed, replace both addon folders and retain SavedVariables.
2. Switch desktop to gamepad and back. Verify addon selections, settings, positions, chat, keybindings, Questie, TomTom, and ORC.
3. Change a position and a keybinding in the active profile; save settings; switch away and back to verify capture.
4. If two profiles share addon selections, verify the editor does not select a profile automatically; choose the correct name before saving.
5. Confirm there are no unexpected reload prompts or Lua errors. Copy /ss log after testing.

Version remains 1.0.0 for the pending first release. Final user test: all behavior appeared to work as intended with no errors. Q/E secondary strafe bindings were unbound and saved in one profile, retained in the other, and restored independently on switches in both directions. This package has not been released on GitHub.
