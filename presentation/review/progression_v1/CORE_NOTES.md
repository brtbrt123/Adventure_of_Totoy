# Core interface follow-up

ExploreSnapshot and its hero snapshot do not expose current/max Edge. The presentation keeps its Edge text as `--`; it must not inspect core.player or invent values. Please expose current/max Edge in the documented snapshot if that gauge is meant to display exploration Edge.

Dash cooldown presentation uses observed snapshot cooldown values. A snapshot cooldown maximum would make the fill accurate immediately after restoring a partially spent cooldown, without presentation history.

No core/data files were changed. The pending compact HUD proposal must retain these interface limits.
