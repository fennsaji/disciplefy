# Google Flow — direction guide

Applies to every `Visual_Prompts.md` from **Season 1 · Arc 3** onward. Arcs 1–2
are released and keep their original prompts.

The concept, the painting device and the rules (no face of Jesus, no God the
Father, no caste in appearance, no text in images) are unchanged — see
[Season1/Arc1/Visual_Prompts.md](./Season1/Arc1/Visual_Prompts.md). This guide
fixes **how** the prompts are written, because the earlier prompts were too thin:
Flow guessed where people faced, where the camera stood and how it moved, and the
clips drifted.

---

## 1. Adults only

Google Flow refuses minors. Every person in every frame is an adult.

- No children, teenagers, babies or school-age characters — present day or painted.
- Don't use the words *child, kid, boy, girl, baby, infant, son, daughter, teen,
  student* or an age under 20 anywhere in a prompt, **even in a negative**. The
  filter reads the whole prompt.
- Every frame's style line ends with *"Every person in frame is an adult."*
- A family scene is adult relatives. A Bible scene that involves a baby is shown
  through the adults and the setting (the light over the manger, Mary's and
  Joseph's backs), never the baby.

## 2. Every frame states its geography

Flow never sees the rest of the reel — only the prompt and the attached images.
So each frame prompt now opens with four fixed lines:

```
CAMERA: shot size, lens, height, where the camera stands and what it looks toward.
SET: the place, and where its fixed landmarks sit in the frame (stage, door, window, wall).
BLOCKING: for each person — where they stand, which way the body faces, where the head turns, what the eyes look at, what the hands do.
LIGHT: where the key light comes from and what it is (tube-light, lamp, dusk sky).
```

then a continuity line, then style and negative.

- **Facing is always explicit and anchored to a landmark**, never to "the
  camera" alone: *"facing the stage at the far end of the hall — backs to camera"*,
  or *"camera stands beside the stage looking back down the hall, so the
  worshippers face the lens."* A congregation always faces the stage; a dinner
  faces the thali; two friends face each other.
- **Screen sides are fixed per reel** (*screen-left / screen-right*) and never flip
  between frames — the 180° rule. If Sunil is screen-left in frame 01 he is
  screen-left in frame 05.
- **Wardrobe and props are repeated word-for-word** in every frame of the reel.

## 3. Every clip is directed, not described

Each clip prompt has five parts:

```
TRANSITION: CONTINUOUS / CUT-OUT / PAINT BLOOM / PAINT FADE / HOLD (see §4)
CAMERA: start framing (= first frame) → the one move → end framing (= last frame). Speed and rig.
ACTION: three beats — opening / middle / landing — who moves, which way, how fast.
LOCKS: what must NOT change — who keeps facing where, who stays still, screen sides.
AUDIO: the ambient bed only.
```

then the motion style and negative.

- **One camera move per clip**, named in film terms: slow dolly in, pull back,
  pan left, tilt down, arc right, crane up, follow from behind. Slow and steady,
  gimbal-smooth. Never "the camera moves around".
- **The two frames must be one move apart.** If the camera axis turns more than
  about 90°, or the location changes, the clip is a CUT-OUT, not a bridge.
- **Background people get a lock too** (*"the worshippers stay facing the stage
  and keep still; nobody turns toward the camera"*). Unlocked extras are where
  most of the drift came from.
- **No audible speech.** Characters may talk with their lips, but the audio line
  always says *no dialogue, no music, no singing* — the voiceover is laid in the
  edit and Flow's own audio would fight it.

## 4. Transition types

| Type | When | How to generate |
|---|---|---|
| **CONTINUOUS** | Same place, camera moves less than ~90° | *Frames to Video* with both frames attached. |
| **CUT-OUT** | Location or camera axis changes | *Frames to Video* with **only the first frame**. The action ends with a motivated exit (walks out of frame, turns away, closes the book). Hard-cut to the next clip, which starts on the next frame. |
| **PAINT BLOOM** | Page → painting | Both frames attached. Camera pushes into the page; paper grain turns into brushwork. Fallback: hard cut on the page close-up. |
| **PAINT FADE** | Painting → room | Both frames attached. Slow push into the painting's light, which fades into the room's matching light. Fallback: cross-dissolve in the edit. |
| **HOLD** | Last clip → outro | *Frames to Video* with **only frame 05**. Near-still slow push. Dissolve into the brand outro **in the edit** — never ask Flow to morph a photo into a graphic. |

## 5. Clip length

The timing grid gives each clip a 10s slot. If Flow returns a shorter clip, use
*Extend* on the same shot or slow it slightly in the edit — don't fill the gap
with a new generation; the landing frame matters more than the length.

## 6. Shared lines

Every prompt already carries these; listed here for reference.

**Frame style**
```
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16. Every person in frame is an adult.
```
**Frame negative**
```
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, people facing the wrong way, people looking into the lens, duplicated people, mirrored layout.
```
**Painting style** (painted frames)
```
Warm painterly illustration in the tradition of Indian Christian art: gouache texture, soft visible brushwork, rich ochre, deep indigo and gold, gently stylised figures, first-century Judean setting. Vertical 9:16. Every figure is an adult. Match the painting style reference exactly.
```
**Painting negative**
```
Negative: photograph, photoreal, 3D render, CGI, glossy digital art, anime, cartoon, face of Jesus shown, depiction of God the Father, halo glow effect, text, watermark, extra fingers, deformed hands, busy background, figures facing the viewer.
```
**Clip style**
```
Photoreal, warm golden grade, subtle film grain, natural human motion at real-world speed, gimbal-smooth camera, one continuous shot, no cuts.
```
**Clip negative**
```
Negative: morphing faces, identity change, people turning to face the camera, people reversing direction, people appearing or vanishing, rubber limbs, extra fingers, sliding feet, camera shake, whip pan, sudden zoom, fast cuts, cold blue light, text, subtitles, watermark, cartoon.
```
