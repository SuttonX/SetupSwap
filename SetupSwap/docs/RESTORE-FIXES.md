# Profile restoration fixes

User testing confirmed repeated desktop/gamepad switches preserve readable Questie tracker rows, correct ElvUI minimap shape, and TomTom waypoint requests without the missing persistence error.

TomTom: reconnect cached native settings and waypoint profiles before deferred consumer callbacks. AceDB removes defaults from the old profile when changing profiles; retained references must follow the newly selected profile.

Minimap: the startup helper observes mask changes before ElvUI loads. After settings restoration, the enabled ElvUI minimap skin uses its square mask. Older circular fallback captures no longer override that skin.

Questie: pooled linePool rows, Questie_Sizer, and descendants of Questie_BaseFrame are excluded from independent window capture/restoration. The main tracker anchor remains restorable. Existing captures are supported; resaving is optional.

Validation: 62 simulated-client checks plus 3 checks using the uploaded TomTom database libraries. User confirmed the final test build works in-game. SavedVariables: KEEP. Client: CLIENT RESTART. Replace both addon folders.
