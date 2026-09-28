# Arc 1 — frames & Google Flow prompts

Scripts: [Arc1_Scripts_Hindi.md](./Scripts_Hindi.md) ·
Curriculum: [Curriculum.md](../../Curriculum.md) ·
Brand: [../Disciplefy_Brand_Visual_System.md](../../../Disciplefy_Brand_Visual_System.md)

---

## The concept

**One person. One real moment. The whole reel happens inside it.**

Each reel is a single scene from the life of **राहुल**, a 24-year-old new
believer — the same face in all four reels. The scene *is* the hook: the viewer
watches something happen to someone, and the voiceover is what is going on
underneath it.

The five frames are moments a few seconds apart **in the same place**, so Flow's
*Frames to Video* can carry one continuous shot from each to the next.

**One signature device.** When the voiceover tells a story from the Bible,
Rahul's page blooms into a warm painting of that story, then fades back to him.
It appears only in Reels 2 and 4, because only they tell a Bible story — keep it
rare so it stays special. It is also how Jesus and David get on screen at all
without a photoreal AI face.

---

## Workflow

1. **Build the references once** (section below): Rahul, Amit, Sunil, the uncle,
   and the painting style. Save each as a Flow *Ingredient*.
2. **Frame 01** — generate from its prompt, attaching the references for everyone
   in the shot.
3. **Frames 02–05** — generate each with **the previous frame attached** as well as
   the character references. This is what locks the location, the light and the
   faces from frame to frame. Without it, the room redraws itself every time.
4. **Video** — in Flow, *Frames to Video* for each pair: 01→02, 02→03, 03→04,
   04→05, then 05→**your outro**. Paste the clip's motion prompt.
5. **Edit** — lay the voiceover, add the **hook text on frame 01** and the
   **on-screen Scripture** listed per clip. Both are added in the edit, never
   generated: image models mangle Devanagari.

### Timing

```
01 → 02 → 03 → 04 → 05 → OUTRO
  10s   10s   10s   10s   10s      = 50s
```

Each clip below shows the voiceover it carries, so picture and sound line up.
The scripts run 46–50s; the last line lands on the outro, which is where a
closing line belongs.

### The painted clips

The page → painting and painting → room clips (Reels 2 and 4) ask Flow to change
style mid-shot. Expect to regenerate them once or twice. **Fallback:** generate the
painting as its own clip and hard-cut into it on the page close-up. The cut still
reads, because the page is the doorway.

---

## Rules

- **Never show Jesus' face** — not photoreal, not painted. The painted scenes show
  him from behind. A generated face either reads Westernised to this audience or
  turns uncanny, and either one breaks the reverence.
- **Never depict God the Father.**
- **Everyone reads as Indian** in the present-day scenes. The painted scenes are
  first-century Judea, in an Indian painting style.
- **No text inside any generated image** — hook and Scripture go on in the edit.
  Bible pages and phone screens are deliberately unreadable.
- **Never encode caste in appearance.** Reel 3 turns on a surname, not a look —
  Sunil must not be distinguished by skin tone or dress. That would teach the
  opposite of the reel.
- **Warm grade throughout.** No cold blue — including phone light at night.

Every prompt below already carries its style line and its negative prompt.
Copy and paste as-is. If your tool takes negatives in a separate field, move the
`Negative:` line there instead of leaving it inline.

---

## References — build these first

**Rahul — the thread through the whole arc**
```
Character reference sheet on a plain warm grey background. Rahul: a 24-year-old Indian man from a North Indian city. Slim build, medium height, warm brown skin, short slightly untidy black hair, light stubble, thick dark eyebrows, kind but tired dark eyes, a small mole on his right cheek. Three views side by side: front, three-quarter and profile. Neutral expression. Wearing a plain grey t-shirt. Even soft studio light.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**Amit — Reel 1**
```
Character reference sheet on a plain warm grey background. Amit: a 25-year-old Indian man, broad build, round face, thick black mustache, short curly hair, easy-going expression. Three views side by side: front, three-quarter and profile. Wearing a mustard-yellow t-shirt. Even soft studio light.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**Sunil — Reel 3**
```
Character reference sheet on a plain warm grey background. Sunil: a 24-year-old Indian man, slight build, neatly side-parted black hair, clean-shaven, a reserved and polite expression. Three views side by side: front, three-quarter and profile. Wearing a light-blue collared shirt. Even soft studio light.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**The uncle — Reel 3**
```
Character reference sheet on a plain warm grey background. An Indian man in his late fifties, greying hair and greying mustache, spectacles, a jovial and self-assured expression. Three views side by side: front, three-quarter and profile. Wearing a cream kurta with a dark Nehru jacket. Even soft studio light.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**Painting style — Reels 2 and 4**
```
A single painted scene to establish the illustration style for the series: a first-century Judean village street at golden hour, a few figures in simple robes walking away from the viewer, flat-roofed stone houses, an olive tree. No faces shown in detail.
Warm painterly illustration in the tradition of Indian Christian art: gouache texture, soft visible brushwork, rich ochre, deep indigo and gold, gently stylised figures, first-century Judean setting. Vertical 9:16. Match the painting style reference exactly.
Negative: photograph, photoreal, 3D render, CGI, glossy digital art, anime, cartoon, face of Jesus shown, depiction of God the Father, halo glow effect, text, watermark, extra fingers, deformed hands, busy background.
```

---

## REEL 1 — यीशु कौन है?
A chai stall at dusk. Rahul's friend Amit calls Jesus "a good guru" and laughs it off. Rahul laughs along — then stops. He shows Amit what Jesus actually said, and by nightfall nobody is laughing.
**Cast:** Rahul, Amit, a third friend (background only) · **Hook text on frame 01:** "वे एक अच्छे गुरु थे।"

### Frames

**01 — the joke**
```
A roadside chai stall at dusk in a North Indian town, a single tungsten bulb hanging unlit above the counter, glass jars of biscuits on a wooden shelf. Three young Indian men standing at the counter holding small glasses of chai, all laughing. Amit, broad-built with a round face and thick mustache in a mustard t-shirt, mid-shrug with a dismissive wave of his hand. Rahul, in a grey t-shirt with an open blue-checked shirt, laughing along beside him. Amit matches his character reference. Medium shot, eye level. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**02 — Rahul stops laughing**
```
Same chai stall at dusk, same three young Indian men, same framing and light. Amit and the third friend are still laughing. Rahul has stopped: his smile gone, his glass of chai paused just below his lips, looking steadily at Amit. Amit matches his character reference. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**03 — the phone**
```
Same chai stall at dusk. Over-the-shoulder close shot of Rahul holding his phone, a Bible app open showing Hindi Devanagari text that is deliberately unreadable, his thumb resting just below one verse. His glass of chai set down on the counter. Amit soft and out of focus in the background. Rahul's hands only, no face; skin tone and shirt sleeve match his character reference.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**04 — Amit reads**
```
Same chai stall at dusk. Rahul holding his phone out toward Amit, pointing at a line on the screen. Amit leaning in close to read it, his smile gone, brow slightly furrowed. The third friend soft behind them. Amit matches his character reference. Medium close shot. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**05 — nobody laughing**
```
Same chai stall, now night: the single bulb above the counter is lit, warm light pooling on the three young Indian men. Amit holding Rahul's phone in both hands, still reading, quiet. Rahul watching him without a word. The third friend looking at the ground. Behind the counter, a small shelf of framed family photographs, soft and completely unreadable, no religious images of any kind. Amit matches his character reference. Slightly wider shot. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition, deity images, religious posters, shrine, idols.
```

### Clips — Frames to Video

**Clip 1 · 01 → 02** · 0:00–0:10

*Voiceover:* "यीशु के बारे में सबसे आदर की बात लोग यही कहते हैं — 'वे एक अच्छे गुरु थे।' पर अगर यही एक बात हो, जो यीशु हो ही नहीं सकते — तो?"

```
Amit finishes his joke and keeps laughing; the third friend laughs with him. Rahul's laugh fades and he lowers his glass, eyes on Amit.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

**Clip 2 · 02 → 03** · 0:10–0:20

*Voiceover:* "क्योंकि एक अच्छा गुरु यह नहीं कहता कि उसे देखना परमेश्वर को देखना है। एक अच्छा गुरु लोगों के पाप माफ़ नहीं करता। एक अच्छा गुरु यह नहीं कहता कि वही मार्ग है।"

*On screen:* यूहन्ना 14:9 · मरकुस 2:5-7 · यूहन्ना 14:6

```
Rahul sets his glass down on the counter, takes his phone from his pocket and scrolls with his thumb, then stops on a verse. Camera eases in over his shoulder.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

**Clip 3 · 03 → 04** · 0:20–0:30

*Voiceover:* "यीशु ने यह सब कहा। बाइबल कहती है — वे सृष्टि से पहले थे, और मरियम की गोद में एक बच्चा बने।"

*On screen:* यूहन्ना 8:58

```
Rahul turns the phone round toward Amit and points at the line. Amit leans in to read, and his smile slowly drops.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

**Clip 4 · 04 → 05** · 0:30–0:40

*Voiceover:* "पूरे परमेश्वर, पूरे इंसान — दो नहीं, एक ही व्यक्ति। इसलिए उन्हें दीवार पर लगी कई तस्वीरों में से एक बना देना — यही सबसे बड़ा अनादर है।"

*On screen:* कुलुस्सियों 2:9

```
Amit takes the phone from Rahul's hand and keeps reading, quiet. Dusk turns to night and the bulb above the stall flickers on. The camera eases back to take in the whole stall.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

**Clip 5 · 05 → outro** · 0:40–0:50

*Voiceover:* "यीशु सिर्फ़ आदर नहीं माँगते। वे आपका पूरा भरोसा माँगते हैं।"

```
Hold on the three men under the lit bulb, nobody speaking. Slow push in on Rahul watching Amit read, then a gentle dissolve into the brand outro.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

---

## REEL 2 — परमेश्वर कैसा है?
Late at night in his rented room, Rahul can't shake the feeling that God is angry with him. He opens the Gospels — and the page becomes a painting of who Jesus actually was: tender with the leper, fierce at the temple tables.
**Cast:** Rahul · painted scene (Jesus seen only from behind) · **Hook text on frame 01:** "क्या परमेश्वर आपसे नाराज़ हैं?"

### Frames

**01 — uneasy**
```
Night in a small rented room in an Indian city: a narrow bed, a small wooden desk with a desk lamp switched on, a folded Hindi Bible on the desk, a steel water bottle, clothes on a hook. Rahul, in a plain grey t-shirt, sitting on the edge of the bed, elbows on his knees, looking at nothing, uneasy. Warm lamplight from the desk, the rest of the room in deep shadow. Medium shot. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**02 — at the desk**
```
Same small room at night, same lamp. Rahul now sitting at the small wooden desk under the warm desk lamp, the Hindi Bible open in front of him, turning a page. His face half-lit, searching. Medium close shot from the side. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**03 — the page**
```
Same desk at night. Close over-the-shoulder shot of the open Hindi Bible under warm lamplight, Rahul's finger resting on a passage in the Gospels, the Devanagari text deliberately unreadable. The page glows warm, the edges of the frame falling into shadow. Rahul's hands only, no face; skin tone and shirt sleeve match his character reference.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**04 — the painting**
```
A single vertical painting in two stacked scenes, divided by a thin decorative border. Top scene: Jesus, seen only from behind, reaching out to touch a kneeling man with leprosy while the onlookers around them draw back. Bottom scene: a temple courtyard with wooden tables overturned, coins scattered across the stone, merchants scattering, Jesus seen only from behind with his arm raised. Tender above, fierce below.
Warm painterly illustration in the tradition of Indian Christian art: gouache texture, soft visible brushwork, rich ochre, deep indigo and gold, gently stylised figures, first-century Judean setting. Vertical 9:16. Match the painting style reference exactly.
Negative: photograph, photoreal, 3D render, CGI, glossy digital art, anime, cartoon, face of Jesus shown, depiction of God the Father, halo glow effect, text, watermark, extra fingers, deformed hands, busy background.
```

**05 — sobered**
```
Back in the same small room at night, same desk lamp. Rahul sitting back in his chair a little away from the desk, the Bible still open in the pool of lamplight, hands resting on his knees, still and sobered, looking at the page. Medium shot. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

### Clips — Frames to Video

**Clip 1 · 01 → 02** · 0:00–0:10

*Voiceover:* "क्या कभी ऐसा लगा है कि परमेश्वर आपसे नाराज़ हैं — पर आप ठीक-ठीक बता भी नहीं सकते क्यों? हममें से ज़्यादातर लोग परमेश्वर की दो में से एक तस्वीर लेकर चलते हैं।"

```
Rahul exhales and rubs his face with both hands, then gets up from the bed, crosses to the desk, sits down and opens the Bible.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

**Clip 2 · 02 → 03** · 0:10–0:20

*Voiceover:* "या तो एक सख़्त परमेश्वर, जो गलती पकड़ने के लिए बैठा है। या एक ढीला परमेश्वर, जो सब कुछ चलने देता है। बाइबल दोनों को गलत कहती है।"

```
Rahul turns the pages, searching, slows down and stops on a passage. The camera eases down over his shoulder onto the page.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

**Clip 3 · 03 → 04** · 0:20–0:30

*Voiceover:* "और उसने अपने बारे में हमारा अंदाज़ा नहीं छोड़ा — उसने यीशु को भेजा। यीशु ने साफ़ कहा — जिसने उन्हें देखा, उसने पिता को देखा। तो देखिए यीशु कैसे थे।"

*On screen:* यूहन्ना 14:9 — hold through "तो देखिए यीशु कैसे थे"

```
The lamplight on the page grows warmer and brighter until the page itself blooms into the painting, filling the frame.
Slow, calm transformation between photoreal and warm painterly illustration, like a painting blooming out of the page. Warm golden grade, no cuts, no text.
Negative: face of Jesus shown, depiction of God the Father, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, extra fingers, deformed hands, anime, cartoon.
```

**Clip 4 · 04 → 05** · 0:30–0:40

*Voiceover:* "वे कोढ़ी को छूते थे — और पाखंड पर खरी बात कहते थे। बच्चों को गोद में उठाते थे — और मन्दिर की मेज़ें उलट देते थे।"

*On screen:* मरकुस 1:41 · मत्ती 23:27 · यूहन्ना 2:15

```
The camera tilts slowly down the painting from the scene with the leper to the overturned tables, then the painting fades back into the lamplit page and the room.
Slow, calm transformation between photoreal and warm painterly illustration, like a painting blooming out of the page. Warm golden grade, no cuts, no text.
Negative: face of Jesus shown, depiction of God the Father, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, extra fingers, deformed hands, anime, cartoon.
```

**Clip 5 · 05 → outro** · 0:40–0:50

*Voiceover:* "परमेश्वर ढीले नहीं हैं। और दूर भी नहीं हैं। वे पवित्र हैं — और वे भले हैं। और यही दोनों बातें मिलकर बताती हैं कि पाप इतनी बड़ी बात क्यों है।"

*On screen:* यशायाह 6:3 · इब्रानियों 1:3

```
Hold on Rahul sitting back from the desk, completely still. Slow push in on his face, then a gentle dissolve into the brand outro.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

---

## REEL 3 — आप कौन हैं
At a family get-together, a relative asks Rahul's friend Sunil his surname — and his warmth cools the moment he hears it. Sunil slips outside. Rahul follows him out with two glasses of chai.
**Cast:** Rahul, Sunil, the uncle, relatives (background only) · **Hook text on frame 01:** "आपकी कीमत किसने तय की?"

### Frames

**01 — the question**
```
An evening family get-together in the drawing room of an Indian home: string lights, relatives chatting with steel plates of food, warm lamplight. A jovial Indian uncle in his late fifties with greying hair, a greying mustache and spectacles, in a cream kurta and a dark Nehru jacket, smiling at Sunil and asking him something. Sunil, a slightly built Indian man of 24 with neatly side-parted hair, clean-shaven, in a light-blue collared shirt, answering politely. Rahul, in a simple maroon kurta, standing a step behind with a plate. The uncle and Sunil match their character references. Medium shot. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**02 — the cooling**
```
Same drawing room, same party and light. The uncle has turned his back and is laughing with other relatives. Sunil stands alone holding his plate, his smile gone, eyes lowered. Rahul in the background, noticing. Sunil matches his character reference. Medium shot. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**03 — on the steps**
```
Outside the same house at night. Sunil sitting alone on the front steps, his shoulders drawn in. Behind him the open front door spills warm light and the blur of the party onto the steps. A quiet street beyond in deep indigo shadow. Sunil matches his character reference. Wide shot.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**04 — the chai**
```
Same front steps at night. Rahul sitting down beside Sunil, holding out one of two small glasses of chai toward him. Sunil hesitant, looking at it. Warm doorway light behind them. Sunil matches his character reference. Medium shot. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**05 — side by side**
```
Same front steps at night. Rahul and Sunil sitting side by side. Sunil holding the glass of chai in both hands, the beginning of a small smile, his shoulders eased. Rahul looking out at the quiet street. Warm doorway light behind them. Sunil matches his character reference. Medium wide shot. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

### Clips — Frames to Video

**Clip 1 · 01 → 02** · 0:00–0:10

*Voiceover:* "आपकी कीमत किसने तय की? आपके काम ने? आपकी कमाई ने? आपके घर के नाम ने?"

```
The uncle hears Sunil's answer; his smile cools, he gives a short nod and turns away to greet someone else. Sunil's face falls.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

**Clip 2 · 02 → 03** · 0:10–0:20

*Voiceover:* "हम सब कहीं न कहीं यह मान बैठे हैं कि कुछ लोग बड़े हैं और कुछ छोटे। और जो छोटा मान लिया गया — वह अक्सर खुद भी मान लेता है।"

```
Sunil quietly sets his plate down and slips out through the front door. The camera follows him outside, where he sits down alone on the steps.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

**Clip 3 · 03 → 04** · 0:20–0:30

*Voiceover:* "बाइबल अपने बिलकुल पहले पन्ने पर इसे काट देती है। लिखा है — परमेश्वर ने मनुष्य को अपने स्वरूप में बनाया। हर इंसान को। किसी छाँटे हुए वर्ग को नहीं। उसे भी, जिसे लोग गिनते तक नहीं।"

*On screen:* उत्पत्ति 1:27 · प्रेरितों के काम 17:26 (shown, never read aloud) · याकूब 3:9

```
Rahul steps out through the lit doorway carrying two small glasses of chai and sits down on the step beside Sunil, holding one out to him.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

**Clip 4 · 04 → 05** · 0:30–0:40

*Voiceover:* "इसका मतलब यह नहीं कि हम भीतर से अच्छे हैं — यह तो हम खुद जानते हैं कि हम नहीं हैं। इसका मतलब यह है कि आपकी कीमत आपने कमाई नहीं,"

```
Sunil hesitates, then takes the chai. They sit together in silence; the tension slowly leaves his shoulders.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

**Clip 5 · 05 → outro** · 0:40–0:50

*Voiceover:* "और इसलिए कोई इंसान उसे आपसे छीन भी नहीं सकता। जिसने आपको बनाया, उसी ने आपकी कीमत तय कर दी है।"

*On screen:* उत्पत्ति 9:6

```
Hold on the two of them on the steps. Slow push in, then a gentle dissolve into the brand outro.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

---

## REEL 4 — पाप असल में क्या है
1 AM. Rahul is scrolling in bed when something from his day catches up with him. He reaches for his Bible — and the page becomes a painting of King David face-down on the floor on his worst night.
**Cast:** Rahul · painted scene (King David) · **Hook text on frame 01:** "अगर आपका पूरा दिन एक परदे पर चल जाए…?"

### Frames

**01 — 1 AM**
```
A small bedroom at 1 AM, dark. Rahul, in a faded grey t-shirt, lying on his back in bed, his face lit only by his phone held above him, scrolling, expression slack. A bedside table with a small unlit lamp and a Hindi Bible. The phone light is warm-neutral, never blue. Close shot. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**02 — the ceiling**
```
Same dark bedroom at 1 AM. Rahul lying on his back, the phone face-down on his chest, staring up at the ceiling, uneasy. Only faint light from the window. Close shot from above. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**03 — the page**
```
Same bedroom at night. The small bedside lamp is now switched on, casting a warm pool of light. Close shot of the open Hindi Bible on the bedside table, Rahul's hand holding the page flat, the Devanagari text deliberately unreadable. The rest of the room in deep shadow. Rahul's hands only, no face; skin tone and shirt sleeve match his character reference.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

**04 — David**
```
A painting of King David alone at night in his palace chamber, lying face-down on a woven mat on a stone floor in grief, his crown set aside on the floor beside him, a single oil lamp burning, deep indigo shadows on the walls. His face hidden against the floor.
Warm painterly illustration in the tradition of Indian Christian art: gouache texture, soft visible brushwork, rich ochre, deep indigo and gold, gently stylised figures, first-century Judean setting. Vertical 9:16. Match the painting style reference exactly. Setting: the palace of ancient Israel in King David's time, not first-century — no Roman or Herodian details.
Negative: photograph, photoreal, 3D render, CGI, glossy digital art, anime, cartoon, face of Jesus shown, depiction of God the Father, halo glow effect, text, watermark, extra fingers, deformed hands, busy background.
```

**05 — unresolved**
```
Back in the same dark bedroom, the bedside lamp on. Rahul sitting on the edge of his bed, elbows on his knees, head lowered, the Bible open beside him in the small pool of lamplight, his phone face-down on the sheet. Still and unresolved. Medium shot. Rahul matches the character reference exactly.
Photoreal cinematic still, warm golden grade, soft natural light, subtle film grain, shallow depth of field, no cold blue light. Palette: warm gold and cream with deep indigo shadows. Vertical 9:16.
Negative: cartoon, illustration, painting, 3D render, CGI, plastic skin, HDR, oversaturated, cold blue lighting, neon, text, captions, watermark, logo, extra fingers, deformed hands, distorted faces, stock-photo smile, crowded composition.
```

### Clips — Frames to Video

**Clip 1 · 01 → 02** · 0:00–0:10

*Voiceover:* "अगर आपके मन में आज दिन भर जो-जो चला, वह सब एक परदे पर चल जाए — तो आप कमरे में किसके साथ बैठ पाएँगे?"

```
Rahul's thumb stops scrolling. Something he remembers crosses his face. He lowers the phone onto his chest and stares up at the ceiling.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

**Clip 2 · 02 → 03** · 0:10–0:20

*Voiceover:* "हम पाप को एक सूची समझते हैं। झूठ, गुस्सा, लालच। और फिर सोचते हैं — थोड़े अच्छे काम कर लें, तो हिसाब बराबर हो जाएगा।"

```
Rahul rolls onto his side, switches on the small bedside lamp, reaches for the Bible on the table and opens it.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

**Clip 3 · 03 → 04** · 0:20–0:30

*Voiceover:* "पर बाइबल पाप को हिसाब की तरह नहीं देखती। वह इसे रिश्ते की तरह देखती है। पाप दिल की वह ज़िद है जो कहती है — मेरी ज़िंदगी, मेरी मरज़ी।"

*On screen:* यिर्मयाह 17:9 · यशायाह 53:6

```
The lamplight on the page deepens and the page blooms into the painting of David, filling the frame.
Slow, calm transformation between photoreal and warm painterly illustration, like a painting blooming out of the page. Warm golden grade, no cuts, no text.
Negative: face of Jesus shown, depiction of God the Father, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, extra fingers, deformed hands, anime, cartoon.
```

**Clip 4 · 04 → 05** · 0:30–0:40

*Voiceover:* "जिसने आपको साँस दी, उससे यह कहना कि मुझे आपकी ज़रूरत नहीं। इसलिए दाऊद ने अपने सबसे बुरे दिन में माना — उसका पाप सबसे पहले परमेश्वर के ही विरुद्ध था।"

*On screen:* भजन संहिता 51:4

```
A slow push toward David's figure on the floor, the oil lamp flickering, then the painting fades back into the lamplit bedroom and Rahul sitting on the edge of his bed.
Slow, calm transformation between photoreal and warm painterly illustration, like a painting blooming out of the page. Warm golden grade, no cuts, no text.
Negative: face of Jesus shown, depiction of God the Father, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, extra fingers, deformed hands, anime, cartoon.
```

**Clip 5 · 05 → outro** · 0:40–0:50

*Voiceover:* "यह कोई गलती नहीं थी जो सुधर जाती। और यही वजह है कि अच्छे काम इसे मिटा नहीं सकते — क्योंकि जो टूटा है, वह हिसाब नहीं, रिश्ता है। इस रिश्ते को जोड़ने का रास्ता परमेश्वर ने खुद कैसे बनाया — यह आगे देखेंगे।"

*On screen:* तीतुस 3:5

```
Hold on Rahul, head lowered, completely still. Slow push in, then a gentle dissolve into the brand outro.
Cinematic, warm golden grade, natural realistic movement, steady camera, shallow depth of field, subtle film grain, no cuts, no text, photoreal.
Negative: faces changing identity, morphing faces, extra fingers, deformed hands, jittery motion, camera shake, fast cuts, cold blue lighting, text, watermark, cartoon.
```

---

## Across the arc

- **Rahul is the thread.** Same face in all four reels, a different place and day
  each time. That is what turns four reels into a series someone follows.
- **The painting appears twice, never more** — Reel 2 and Reel 4. Its rarity is
  what keeps it meaningful.
- **Every reel ends on Rahul, still**, then a slow push in to the outro. Hold the
  final frame an extra beat.
- **The scenes are ordinary on purpose**: a chai stall, a rented room, a family
  get-together, a bed at 1 AM. The viewer should recognise their own life in
  every frame before a single word of doctrine lands.
