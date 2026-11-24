# Style guide: LOCKED (Duff, Nov 20 2026): ink and blood, on real-time 3D

Duff picked ink and blood, and said "full range of movement" (2D animated stills rejected). So the look is a comic-ink horror style rendered on 3D models.

References (docs/art/ink-3d/):
- `full_movement_3d_ink_test.mp4`: the approved motion and shading test. Duff: "Excellent". Stand-in robot model, real 360° run + punches + hit flash + death.
- `ink_sprites_lineup.jpg`: concept art for the hero, zealot and Gus (Foxboard Forge). Use it for character design and colours, not as in-game sprites.
- `ink_ingame_mockup.png`: screen layout and scale (hero about 1/9 of screen height).

## Rendering rules
- Toon shading: 2 or 3 hard light bands, no smooth gradients, no PBR shine. One key light from upper left, plus ambient.
- Outlines: thick black, constant width on screen (about 3 px at 720x1280). Inverted hull pushed in clip space, or a screen-space edge pass.
- Flat colours. Big solid-black shadow shapes are fine; no textures with fine noise.
- Hero rim light: orange (#FF6A1A) on the side away from the key light, so the black-clad hero never sinks into dark floors.
- Hits: the victim flashes pure white for 3 frames, then yellow spark lines, 60 ms hit-stop, small screen shake.
- Floors and props: dark, desaturated, low-poly, with hand-drawn crack lines. Characters must be the brightest-reading things on screen.

## Palette
- Base: ink black #0D0C0C, charcoal #2B2A2E, bone white #EEEAE0, blood red #B01818.
- Hero accent: demon orange #FF6A1A (veins, rim light, horn tips).
- One accent per realm: Pews candle gold #D4A028, Casino red #D21E3C, Quarry ember orange #E8641E, Ballroom violet #7A3CC8, Nursery sick yellow #C8C83C, Price & Partners cold white #DCE6F0.
- Gameplay colours still go through `UI.key()` with shape cues (colorblind rule).

## Characters
- Low-poly humanoids (under ~5k tris), one shared skeleton so the shared animation library drives everyone.
- Silhouette first: each boss reads at phone size from its outline alone (Vesper's candle halo, Gus's round belly and coin, Rook's iron mask and bulk, Ines's rapier and gown, Hollis's hunch and insect cloud).
- Hero: lean, black hoodie, torn jeans, two short black horns, one forearm cracked with glowing orange veins. Corruption adds horn length, vein spread and a redder rim light.
- Concept art comes from Foxboard Forge (job ids `dh-*`). Rules: no named IP in prompts, no private info (Forge prompts are public; Duff's likeness is OK since Nov 24). Fixes from tasks/lessons.md: Rook keeps his iron mask, Vesper has no horns.

## UI
- 2D, flat, black panels with bone-white text, using `ui.gd` helpers. Voice dialogue boxes show a 2D ink portrait (Forge art) beside the text.
