# Dodging NPC

A small Roblox NPC behaviour: patrols a list of waypoints, idles briefly at each, and jumps to dodge any nearby projectile.

Three states — `patrol`, `idle`, `dodge` — driven by a single loop. Each projectile is dodged only once and then ignored, so the NPC won't get stuck panicking over the same part.

## Studio setup

Place [`src/DodgingNpc.server.lua`](src/DodgingNpc.server.lua) **inside an NPC model** in `workspace`. The model needs:

```
NpcName/                  (Model)
  Humanoid                (Humanoid)
    Animator              (Animator)
  HumanoidRootPart        (BasePart)
  Animations/             (Folder)
    Run                   (Animation)
    Idle                  (Animation)
  DodgingNpc              (Script — this file)
```

And in `workspace`:

```
workspace/
  waypoints/              (Folder of BaseParts named "1", "2", "3", ...)
  Projectiles/            (Folder — any BasePart inside is treated as a projectile)
```

The NPC visits waypoints in numeric order and loops back from the last to `"1"`.

## Tunables

Edit at the top of the script:

| constant | default | meaning |
| --- | --- | --- |
| `WAYPOINT_REACH_OFFSET` | `6` | Distance at which a waypoint counts as reached. |
| `IDLE_DURATION` | `2` | Seconds spent idling at each waypoint. |
| `DODGE_DISTANCE` | `20` | Projectile proximity that triggers a jump. |

## Behaviour

- **Patrol.** Pathfinds to the next waypoint and walks until within `WAYPOINT_REACH_OFFSET`. Plays the Run animation.
- **Idle.** Plays the Idle animation for `IDLE_DURATION` seconds, then resumes patrol.
- **Dodge.** Pre-empts every other state. The first time a projectile enters `DODGE_DISTANCE`, the NPC jumps and records the projectile so it isn't dodged again. Then falls back to patrol.

## License

MIT — see [LICENSE](LICENSE).
