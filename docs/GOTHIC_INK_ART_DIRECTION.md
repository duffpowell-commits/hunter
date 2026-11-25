# Hunter visual direction: Gothic Ink Realism (approved Nov 22, 2026)

This document refines `docs/style-guide.md`. The established 3D comic-ink look, character identities, gameplay silhouettes, and mobile constraints remain authoritative.

## Blend
- **Ink & Ash:** confident black contours, graphic shadow shapes, readable silhouettes.
- **Gothic Realism:** weathered architecture, physical grime, worn metal, cracked stone and wood, believable proportions. Use hand-painted broad shapes, not expensive photoreal materials.
- **Neon Occult:** vivid supernatural magenta/violet/crimson ONLY when a ritual, boss power, voice ability, or realm breach activates. Avoid persistent neon ambient lighting.

## Lighting states
1. **Exploration:** cold blue-gray ambient, charcoal shadows, sparse candle-gold pools. Occult emission normally OFF. Keep enemies readable at 720x1280.
2. **Combat:** same restrained world palette, stronger silhouettes, ink-like impact streaks and existing white hit flash; blood red for physical danger, orange for hero's established demonic accents.
3. **Occult event:** short, unmistakable magenta/violet glow at the source, optional nearby purple tint, then fade back to normal. Never make all ordinary church candles pink.

## Existing character canon (do not overwrite with the concept illustration)
- Hero remains the established lean, horned, black-hoodie half-demon with glowing orange forearm veins; the white-haired sword-bearing figure in the concept image is **not** a redesign approval.
- Brother Vesper Lyle is the established male cult preacher, with a distinctive candle halo and **no horns**. The floating female figure in the concept image is a mood reference only.
- Preserve the top-down 3D camera, 360-degree movement and shared skeleton/animation system.

## The Pews first playable art pass
- Replace simple pew blockouts with worn wood silhouettes and a few broad hand-drawn grain/crack marks.
- Add a readable cracked-stone aisle, candle clusters, broken stained-glass shapes, altar, and Vesper's candle halo.
- Keep mundane lights gold and blue-gray. Reserve magenta/violet emission for Vesper's sermon, flock, phase transition and finisher/portal moments.
- Make the gameplay silhouettes and telegraph symbols readable without depending on color.
- Do not let scenery obstruct the top-down combat camera.

## Godot 4.7 / Android implementation
- Compatibility renderer, GDScript only. Prefer StandardMaterial3D unshaded/emission where necessary and existing toon/outline techniques.
- Favor low-poly geometry, mesh reuse, baked/vertex colors and limited local lights. Avoid full-screen expensive post-processing, dense particles and per-object real-time shadows.
- Use small reusable textures and materials; target the existing draw-call/triangle budgets in standards.
- All visual changes require **real Godot-rendered** screenshots in `docs/renders/`, autoplay checks and green CI before merging.

## Acceptance checks
- Exploration screenshot: no dominant pink or purple lighting.
- Combat screenshot: silhouettes, telegraphs and hit feedback remain legible on a phone.
- Occult screenshot: visible violet/magenta spike only during an actual ability or phase event.
- Return to exploration: occult emission disappears after the event.
- Existing movement, combat, Pews autoplay, and Android build remain green.

## Next asset order
1. Pews altar + pews + cracked floor kit.
2. Vesper candle-halo mesh and ability telegraph effects.
3. Hero hoodie/forearm detail pass without changing the shared skeleton.
4. Zealot and Choir silhouettes.
5. Material palette reused in later realms.
