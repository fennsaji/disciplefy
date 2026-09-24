# Arc 1 — image prompts & Google Flow video prompts

Scripts: [Arc1_Scripts_Hindi.md](./Arc1_Scripts_Hindi.md) ·
Curriculum: [Curriculum.md](./Curriculum.md) ·
Brand: [../Disciplefy_Brand_Visual_System.md](../Disciplefy_Brand_Visual_System.md)

Five content keyframes per reel plus the existing brand outro, then Flow prompts
to animate consecutive pairs into one continuous 50s piece.

---

## Read this before generating

### Timing — 5 content frames + the outro

Clips run 10 seconds. Five content keyframes plus the existing brand outro as
frame 06 gives **five** transitions:

```
01 → 02 → 03 → 04 → 05 → OUTRO
 10  + 10  + 10  + 10  + 10     = 50s
```

- **Clips 1–4 = 40s of content** (frames 01→05)
- **Clip 5 = 10s** carrying frame 05 into the outro

The scripts run 46–50s, so the closing line lands **over the outro transition**.
That is the intended shape, not a compromise — it puts the last sentence on the
brand frame, which is where a CTA belongs. Reel 4's
*"इस रिश्ते को परमेश्वर ने कैसे जोड़ा — यह आगे देखेंगे"* is the clearest case.

**Timing the voiceover:** the final beat of each script should begin at roughly
**00:40**, as clip 5 starts. Everything before it fits the four content clips at
about ten seconds a beat — which is how the beat maps below are grouped.

### Rules that apply to every frame

- **9:16 vertical, 2160×3840.** Compose for a centre-safe area — captions and
  the platform UI eat the top and bottom ~15%.
- **Never depict Jesus' face.** Hands, a back, a silhouette, a figure just out of
  frame, light standing in for presence. Two reasons: image models produce a
  Westernised Jesus that will not read to this audience, and an uncanny
  generated face destroys the reverence the brand is built on.
- **Never depict God the Father.** Light, sky, dawn — never a figure.
- **People must read as Indian/South Asian.** The voiceover is Hindi and the
  audience is Indian. State it in every prompt with people in it.
- **Warm grade always.** Golden-hour or low-key candle/lamp light. Warm shadows,
  gold highlights, gentle indigo in the darks. **No cold blue light** — it kills
  the brand.
- **Palette:** indigo `#4F46E5` / `#6366F1`, warm gold `#FFEEC0` / `#B8860B`,
  cream. No pure white, no pure black.
- **One subject, one light source, generous negative space,** shallow depth of
  field, subtle film grain. Never plastic-clean.
- **No clip-art crosses, no religious kitsch, no cheesy stock.** Restraint reads
  as premium.

### Negative prompt (paste into every generation)

```
cartoon, illustration, 3D render, CGI, plastic skin, HDR, oversaturated,
cold blue lighting, neon, lens flare artifacts, text, watermark, logo,
extra fingers, deformed hands, face of Jesus, depiction of God,
clip-art cross, stock-photo smile, crowded composition, busy background
```

---

## REEL 1 — यीशु कौन है?

Beat map: the polite compliment → what he actually claimed → before creation →
a child → he asks for trust, not respect.

**01 — the compliment**
```
Cinematic vertical 9:16 photograph. Two Indian men in their late twenties at a
roadside chai stall at dusk, mid-conversation, one speaking with an easy
dismissive shrug. Shot from slightly low, shallow depth of field, the speaker
soft in the background, a chipped glass of chai sharp in the foreground.
Warm practical tungsten light from a single hanging bulb, deep warm shadows,
gentle indigo in the darks. Documentary realism, unposed, subtle film grain.
Generous negative space above the heads.
```

**02 — what he actually claimed**
```
Cinematic vertical 9:16 photograph. Close overhead of an open Hindi Bible on a
dark worn wooden table, Devanagari text legible but not readable, a man's hand
resting at the edge of the page mid-thought. A single shaft of warm gold
window light rakes low across the paper, the rest of the frame falling into
deep warm shadow. Shallow depth of field, dust motes in the beam, soft paper
texture, film grain. Cream and gold against near-black.
```

**03 — before creation**
```
Cinematic vertical 9:16 photograph. Vast pre-dawn sky over a still landscape,
deep indigo gradient overhead giving way to the first warm gold at the horizon.
No people, no structures. Enormous negative space, the horizon line low in the
frame on the lower third. Atmospheric haze, soft grain, filmic and quiet.
Indigo #4F46E5 sky into warm gold #FFEEC0 at the edge.
```

**04 — the child**
```
Cinematic vertical 9:16 photograph. Extreme close-up of an Indian mother's
hands cradling a newborn's bare feet, the infant's face out of frame. Warm
low candlelight from one side, deep soft shadows, skin warmly lit and textured.
Intimate, reverent, unposed. Shallow depth of field, heavy negative space in
the upper frame. No faces visible.
```

**05 — respect is not trust**
```
Cinematic vertical 9:16 photograph. A modest Indian home wall in warm lamplight,
a cluster of small framed portraits hung together, deliberately out of focus
and unreadable. In sharp foreground, a man's open upturned hand entering from
the lower frame, empty, palm up. Single warm light source from the left,
deep warm shadows, strong negative space. Quiet, not staged.
```

**06 — outro** (existing brand end card)

### Flow prompts — Reel 1

| Clip | Frames | Prompt |
|---|---|---|
| 1 | 01 → 02 | `Slow push in on the foreground chai glass as the conversation falls out of focus behind it; dissolve gently into the lit page of the open Bible. Camera drifts forward, never cuts. Warm tungsten shifting to warm gold. Calm, unhurried, no camera shake.` |
| 2 | 02 → 03 | `The shaft of gold light across the page widens and blooms until it fills the frame, then resolves into the pre-dawn horizon. A slow upward tilt. Light bloom transition, no hard cut. Deep indigo settles into the upper frame.` |
| 3 | 03 → 04 | `Slow descent from the vast sky down into intimate candlelight on the infant's feet. Scale collapses from enormous to tiny. Gentle downward drift, soft dissolve, the gold at the horizon becoming the candle flame.` |
| 4 | 04 → 05 | `Pull back slowly from the cradled feet; the candlelight becomes lamplight on a wall of framed portraits, which stay soft. An open upturned hand rises into the lower frame and holds. Slow, weighted, ends in stillness.` |
| 5 | 05 → outro | `Hold on the empty upturned hand as the warm light slowly rises and blooms, then dissolve into the brand outro. The bloom carries the transition — no cut, no move. Ends settled.` |

Final VO beat (*"यीशु आदर नहीं माँगते…"*) starts at ~00:40, over clip 5.

---

## REEL 2 — परमेश्वर कैसा है?

Beat map: vague guilt → the two false pictures → he sent Jesus → four concrete
scenes → holy *and* good.

**01 — vague guilt**
```
Cinematic vertical 9:16 photograph. An Indian woman in her thirties sitting
alone on the edge of a bed in a dim room at dusk, shoulders forward, looking
at nothing, hands loose in her lap. Single warm window light from behind and
left, her face mostly in soft shadow, expression unreadable rather than sad.
Deep warm shadows, indigo in the darkest areas. Shallow depth of field,
documentary stillness, film grain. Large negative space to her right.
```

**02 — the strict picture**
```
Cinematic vertical 9:16 photograph. A heavy closed wooden door in warm low
light, ornate and old, firmly shut, a thin line of warm gold light escaping
underneath it. Shot straight on, centred, oppressive symmetry. Deep warm
shadow dominating the frame, texture of grain and old paint. No people.
Quiet and slightly cold in mood despite the warm grade.
```

**03 — the indulgent picture**
```
Cinematic vertical 9:16 photograph. The same warm palette but loose and
formless: a soft empty hammock swaying in hazy golden afternoon light on a
verandah, everything slightly overexposed and washed out, edges blooming.
Pleasant, weightless, unserious. Shallow depth of field, heavy haze, no people,
no structure to the composition. Deliberately less resolved than the frames
around it.
```

**04 — he touched the leper**
```
Cinematic vertical 9:16 photograph. Two hands meeting in warm directional
light — one weathered, scarred and hesitant, the other steady, reaching in from
the upper frame. Faces entirely out of frame. Deep warm shadow surrounding,
a single warm gold key light on the point of contact. Skin texture, grain,
reverent and restrained. The contact point is the only sharp element.
```

**05 — holy and good**
```
Cinematic vertical 9:16 photograph. An overturned wooden table in an empty
stone courtyard at golden hour, scattered coins catching the low light, dust
suspended in the air. No people in frame. Long raking shadows, warm gold light
from the left, deep indigo shadow pooling. Still and charged, the aftermath of
something. Cinematic wide, strong negative space above.
```

**06 — outro** (existing brand end card)

### Flow prompts — Reel 2

| Clip | Frames | Prompt |
|---|---|---|
| 1 | 01 → 02 | `Slow push past the seated woman toward the wall beyond her, which resolves into the closed wooden door. She stays soft and unmoving. The thin line of gold light under the door brightens slightly as the camera settles. No cut.` |
| 2 | 02 → 03 | `The door dissolves and the frame loosens and blooms into hazy overexposed afternoon light on the swaying hammock. Transition should feel like focus being lost rather than a cut. Everything softens.` |
| 3 | 03 → 04 | `The haze contracts and hardens into a single warm key light; out of it, two hands reach toward each other and meet. Blur resolving into sharpness. Slow, deliberate, the moment of contact holds.` |
| 4 | 04 → 05 | `Pull back and rotate slightly from the joined hands to reveal the overturned table and scattered coins in the courtyard. Dust drifts through the light. The move is firm rather than gentle, and ends completely still.` |
| 5 | 05 → outro | `Dust settles slowly through the golden courtyard light, the frame growing quieter and warmer, then dissolves into the brand outro. Nothing moves but the dust.` |

Final VO beat (*"और यही दोनों बातें मिलकर…"*) starts at ~00:40, over clip 5.

---

## REEL 3 — आप कौन हैं

Beat map: who set your price → we've all absorbed a ranking → the first page
cuts it → every human, including the uncounted → your worth was never earned.

**01 — who set your price**
```
Cinematic vertical 9:16 photograph. Close on an Indian man's hands in his
forties holding a worn cloth wallet and a folded government ID card, the text
illegible, in warm low lamplight. Face out of frame. Hands working, slightly
calloused. Single warm light source, deep shadow, shallow depth of field,
film grain. Negative space above.
```

**02 — the ranking we absorbed**
```
Cinematic vertical 9:16 photograph. A queue of Indian people seen from behind
at golden hour, standing apart from one another along a plain wall, each
isolated in their own pool of warm light and shadow. No faces visible, all
backs to camera. Long shadows, warm dusty air, documentary realism. Strong
repeating rhythm in the composition, cinematic and unsentimental.
```

**03 — the first page**
```
Cinematic vertical 9:16 photograph. Extreme close-up of the opening page of a
Hindi Bible, the paper warm cream and slightly rough, a single beam of gold
morning light falling across the very first lines of Devanagari text. The rest
of the page and frame in deep warm shadow. Dust motes. Shallow depth of field,
paper fibre texture, reverent stillness.
```

**04 — the one nobody counts**
```
Cinematic vertical 9:16 photograph. An elderly Indian woman's face in warm
directional window light, deeply lined, dignified, looking directly into the
lens without performing. Plain dark background falling into warm shadow. Half
her face lit, half in soft shadow. Portrait, shallow depth of field, honest
and unglamorised. Golden key light. She fills the lower two-thirds of frame.
```

**05 — worth you did not earn**
```
Cinematic vertical 9:16 photograph. The same elderly woman's open hands resting
in her lap, palms up and empty, in warm low light. Face out of frame. Skin
texture and worn fabric, deep warm shadows, a single gold key light from the
upper left. Quiet, settled, nothing held. Heavy negative space.
```

**06 — outro** (existing brand end card)

### Flow prompts — Reel 3

| Clip | Frames | Prompt |
|---|---|---|
| 1 | 01 → 02 | `Pull back from the hands holding the ID card to reveal the queue of people along the wall at golden hour. Widening move, the foreground hands leaving frame. Long shadows lengthen slightly. Calm, observational.` |
| 2 | 02 → 03 | `Push through the queue toward the wall, which dissolves into the warm cream page of an open Bible. The gold light on the people becomes the beam across the page. Slow forward drift, soft dissolve.` |
| 3 | 03 → 04 | `The beam of gold light on the page lifts and becomes window light on the elderly woman's face. Gentle upward tilt and dissolve. She is already looking at the lens as she resolves. Unhurried, the moment lands and holds.` |
| 4 | 04 → 05 | `Slow tilt down from her face to her open empty hands in her lap. Light stays warm and constant. Nothing else moves. Ends completely still.` |
| 5 | 05 → outro | `Hold on her open empty hands as the gold key light warms and softens, then dissolve into the brand outro. Absolutely still. This reel's power is in holding on her — do not rush it.` |

Final VO beat (*"जिसने आपको बनाया…"*) starts at ~00:40, over clip 5.

---

## REEL 4 — पाप असल में क्या है

Beat map: your day on a screen → sin as a list → not a ledger, a relationship →
David's worst day → the break is relational.

**01 — your day on a screen**
```
Cinematic vertical 9:16 photograph. An Indian man in his thirties alone in a
dark room, face lit only by the cold-warm glow of a phone screen held close,
his expression caught mid-thought and slightly exposed. Shot close, shallow
depth of field, the room falling into deep indigo shadow around him. The
screen light is warm-neutral, never blue. Film grain, documentary honesty,
negative space above his head.
```

**02 — sin as a list**
```
Cinematic vertical 9:16 photograph. Close on a handwritten Hindi list in a
cheap ruled notebook in warm lamplight, several lines struck through, the
handwriting legible as script but the words not readable. A pen resting.
Single warm light source, deep shadow at the edges, paper texture and grain.
Clinical and small against a large dark frame.
```

**03 — the ledger that does not balance**
```
Cinematic vertical 9:16 photograph. An old brass two-pan balance scale on a
dark wooden surface in warm low light, visibly tipped and unbalanced, a few
coins in one pan. Deep warm shadows, a single gold key light catching the
brass edge. Still life, cinematic, heavy negative space. Beautiful object,
uncomfortable meaning.
```

**04 — David's worst day**
```
Cinematic vertical 9:16 photograph. A man's silhouette kneeling alone on a flat
rooftop at night, seen from behind and far off, city lamplight warm and sparse
below, deep indigo sky above. Face and features entirely unreadable. Enormous
negative space, tiny figure low in frame. Still, quiet, not theatrical.
Warm practical lights, filmic grain.
```

**05 — a relationship, not a ledger**
```
Cinematic vertical 9:16 photograph. Two empty chairs facing each other in warm
low lamplight in a plain Indian interior, one chair pushed back and turned
slightly away. No people. Deep warm shadows, a single light source between
them, the space between the chairs the true subject. Still, quiet, and
slightly aching. Strong negative space, shallow depth of field.
```

**06 — outro** (existing brand end card)

### Flow prompts — Reel 4

| Clip | Frames | Prompt |
|---|---|---|
| 1 | 01 → 02 | `The phone glow on the man's face lowers and becomes lamplight on a handwritten notebook page. Slow downward tilt, he leaves frame. Light shifts from screen-neutral to warm tungsten. No cut.` |
| 2 | 02 → 03 | `Drift sideways from the notebook to the brass balance scale on the same dark surface, the scale settling visibly further out of balance as the camera arrives. Slow lateral move, one continuous light source.` |
| 3 | 03 → 04 | `Pull back and up from the scale until the warm interior becomes night air, resolving on the distant kneeling silhouette on the rooftop. A large opening-out move. Scale expands from tiny object to wide night. Deep indigo enters the frame.` |
| 4 | 04 → 05 | `Descend slowly from the rooftop figure into a warm lamplit interior, settling on two empty chairs facing each other. The move is quiet and inevitable. Ends still, holding on the space between the chairs.` |
| 5 | 05 → outro | `Light rises a little on the empty chair, the space between the two chairs holding, then dissolves into the brand outro. Slow and unresolved — this reel ends on a question.` |

Final VO beat (*"इस रिश्ते को परमेश्वर ने कैसे जोड़ा — यह आगे देखेंगे"*) starts at
~00:40, over clip 5. This is the arc's clearest CTA moment — the forward-pointer
lands on the brand frame.

---

## Continuity across the arc

These four reels should read as one family at a glance:

- **The recurring signature is light behaving like revelation** — a beam finding
  a page, a key light finding a point of contact, light rising on a hand. Every
  reel has one.
- **Every reel ends on stillness, and three of the four end on hands or an empty
  space.** Keep that rhyme; it is what makes them a set.
- **The palette walk is the same each time:** warm tungsten or gold interior →
  a widening into indigo → back to a warm intimate close. Reels 1 and 4 do this
  most explicitly.
- **Reel 3 is the only one with a face looking into the lens.** That is
  deliberate — it is the reel about a person's worth, and it should feel
  different from the other three.
- **Hold the last frame of every reel an extra beat** before the end card. The
  brand's motion rule is that calm *is* the identity.
