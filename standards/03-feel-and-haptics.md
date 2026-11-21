# Game feel and haptics (standards 1 and 10)

- **Every hit gets all five:** hit-stop (~60 ms freeze on both fighters), screen shake, a sound,
  a particle burst, and a phone buzz. Bigger hits = more of each.
- **Haptics:** a buzz on every hit, scaled by power; respects the Vibration setting.

Godot today: `Feel.impact(pos, power, parent)` + `Character3D.hit()` / `hit_stop()`.
Check: `FEEL PASS`.
