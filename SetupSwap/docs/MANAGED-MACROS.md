# Native and addon-managed macro tracking

SetupSwap tracks native macro lifecycles and supports stable identities for addon-managed macros. SmartTravel is supported without changes and is not bundled.

## Identity and restoration

GetActionInfo reports native macro indices on action bars. The client's macros-cache.txt contains separate Blizzard persistence IDs, which are not exposed by these Lua calls. SetupSwap uses native API indices for placement and maintains its own persistent tracking identities across observed macro edits and deletions. It does not read Blizzard's internal IDs or access the WTF file in-game.

Ordinary macros are tracked separately by native slot and account/character scope, even when every name is one space and every icon is a question mark. EditMacro, CreateMacro and DeleteMacro are observed with secure post-hooks; original client functions are not replaced. UPDATE_MACROS is reconciled after those hooks. Changes to commands, names and icons retain a tracked identity. Observed deletions invalidate it, and new macros get new identities. Unique stored fingerprints follow index shifts; ambiguous changes are not guessed. Multiple bar positions referring to one macro share its identity, while each placement remains saved independently. SetupSwap never creates or edits macros.

Tracking is stored in SetupSwapAccountDB. Account macro tracking is shared; character macro tracking is keyed by realm/character. Action-bar profiles retain their existing character/spec isolation. The current macro index is resolved again immediately before pickup and rollback. Deleted/missing identities are skipped and reported in /ss log; an old index is not blindly reused. Placement failure retains the existing rollback safeguards.

Keep SetupSwap enabled when modifying macros. Without access to native persistence IDs, macro deletion/replacement while SetupSwap is disabled or changes made directly to WTF files cannot always be distinguished from edits after login. Identical macros whose indices change without an observable native operation may require recapture rather than guessing.

## Existing captures

Legacy entries have no tracking ID. At login, current-character snapshots are adopted only when exact saved name/body/scope uniquely identifies a live ordinary macro. A changed or ambiguous old blank-named macro cannot safely be adopted. Arrange that profile and Save settings & positions once. Subsequent ordinary edits need no profile save.

## SmartTravel and other addons

SmartTravel's managed macro is recognized by an exact stable ownership comment in its leading comment preamble, including when #showtooltip precedes that line in existing SmartTravel macros. Its current body is preserved. Missing or duplicate managed identities in the same name/scope are skipped rather than guessing, even if one was previously tracked. Separate account and character versions are not confused.

Other addons editing ordinary native macros are covered by the same tracking mechanism. Addons needing stable managed identity across recreation can use these exact ownership comments:

```
# DO NOT EDIT - Dynamic macro managed by AddonName
# DO NOT EDIT - Managed by AddonName
# SetupSwap-ManagedMacro: AddonName/macroKey
```

The first two forms identify one logical managed macro per name/scope. The last form supports distinct keys. SmartTravel's older `# DO NOT EDIT - SmartTravel` comment is recognized as well. Owner/key identifiers start with a letter and contain letters, digits, underscores or hyphens, up to 64 characters. Partial, embedded executable text, and conflicting ownership comments are not recognized.

An addon can register its own existing stable comment each session after SetupSwap loads and before bar restoration:

```lua
local ok, reason = SetupSwap:RegisterManagedMacro(
    'OtherAddon', 'travel', '# OtherAddon travel macro')
```

Registered headers must be one exact # comment, with unique owner/key identity; conflicting registrations are refused. Macro names and scope still form part of managed identity. Arbitrary Lua is not executed to identify macros. Standalone custom secure buttons remain controlled by their addon; native macros that /click those buttons can be tracked normally. SetupSwap does not recreate arbitrary custom buttons.

## Installation and verification

SavedVariables: KEEP. Client: CLIENT RESTART. Close WoW, back up WTF, and replace both SetupSwap and !SetupSwapLoader folders. Keep the current SmartTravel installation. Native keybinding management remains removed, as in the released SetupSwap version.

1. Activate Desktop. Put SmartTravel in its intended slot and at least two different ordinary blank-named/question-mark macros in other slots. Use one conditional macro in several slots. Save settings & positions once.
2. Activate Gamepad, arrange these macros in different slots, and Save settings & positions once.
3. Edit the commands of both ordinary blank-named macros without resaving settings. Switch back and forth repeatedly. Each position must contain the correct macro with its NEW contents. All placements of one conditional macro must reference the same macro and retain the conditionals.
4. Change an ordinary macro's name/icon and repeat. No recapture should be needed while SetupSwap tracks the edit.
5. Trigger SmartTravel changes by mounting/dismounting, swimming, indoor/outdoor transitions or modifiers. Switch repeatedly; its placements must retain the managed macro and current travel action/tooltip.
6. Optional: create a temporary blank-named macro, capture it, delete it, then create a replacement with the same name/icon. Its old saved position must be skipped, with a report in /ss log. New placements require a deliberate save. This destructive lifecycle is also covered by automated checks.
7. Optional: a second managed macro with the same ownership/name/scope should produce Ambiguous macro and leave the destination unchanged. Remove the temporary duplicate afterward.
8. Check logging out/in and /reload, another character/spec, addon overrides, minimap shape, Questie tracker and TomTom waypoints. Inspect any errors with /ss log.

Automated regression coverage includes native macro lifecycle hooks, blank names/icons, editing, renaming and reorder, deleted/recreated macros, multiple placements, dynamic bodies, marker boundaries, duplicates, scopes, legacy adoption, rollback, and existing SetupSwap behavior. The macro tracking update passed in-game profile switching verification before release.
