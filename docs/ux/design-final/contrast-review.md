# Contrast review of design-v2.pen

Read-only parse of `design-v2.pen` on 2026-10-07. The editor was offline and the file was not changed. These are edits to make in the design when the editor is back, so it matches the app.

**Method.** For every text and icon node I composited its fill over its ancestors' fills, alpha included, to get the colour actually behind it. Nodes over a photo or gradient were skipped. A frame named "… · light", or with fill `#FAF8F5`, counts as light. Ratios are WCAG 2.x.

**Thresholds.**
- Normal text: 4.5:1.
- Text 18.66px bold or larger, and icons: 3:1.
- Button, chip, pill and badge labels: 5.5:1 or more. The app tests this floor in `test/core/theme/palette_contrast_test.dart`.

Node ids are listed so each node can be found in the editor.

## 1. Selected chip and gold fills (the owner's complaint)

The light Generate screen has no frame in the design: Generate exists only as dark frames, with `#121212` on `#E3B154` at 9.5:1. The app derived the light selected chip from the light "gold fill" `#B8860B`. Ink on that fill is 5.4:1, and the owner found it muddy.

| Where | Pair now | Ratio | Replace with | New ratio |
|---|---|---|---|---|
| App light selected chip (depth chips, segments, toggles) | ink `#1A1917` on `#B8860B` | 5.40 | ink on **`#D4A23A`** (already in the app) | 7.55 |
| Secondary line on a selected chip ("3 min", cost) | ink 80% on the gold fill | 5.25 | ink **85%** (`#1A1917D9`) | 5.77 light / 6.63 dark |
| Guest Home · light, Home / Returning user · light, Topics · light, All paths · light: numbered and "All" badges (`u8QyD`, `YDkeH`, `QVeFB`) | white on `#B8860B` | 3.25 | ink `#1A1917` on `#D4A23A` | 7.55 |
| The same frames: check icons on gold dots (7 nodes) | white on `#B8860B` | 3.25 | ink on `#D4A23A` | 7.55 |
| First run / 2 Grow in · dark: icons `K5XZxA` and `ndpcf` | `#F2F2F4` on `#E3B154` | 1.76 | ink `#1A1917` | 8.94 |

**Rule for the design:** gold fills that carry a label use `#D4A23A` on light and `#E3B154` on dark, both with ink. White goes only on ink, or on deep gold `#986910` for icons and large text (4.8:1).

## 2. Gold text on light surfaces

| Where | Pair now | Ratio | Replace with | New ratio |
|---|---|---|---|---|
| Sign in · light, Sign up · light and others: "WELCOME BACK", "Forgot password?", "JOIN DISCIPLEFY" (20 nodes, e.g. `kMRS6`, `fwVDj`, `FbKJa`) | `#9A6B10` on `#FAF8F5` | 4.42 | `#986910` | 4.54 |
| Feature introductions / Fellowships · light: step numbers 1–3 on the cream circles (8 nodes, `hunRJ`, `psM1D`, `bIBVG`) | `#9A6B10` on `#FFEEC0` | 4.07 | **`#704D0F`** (gold for labels on a tint) | 6.62 |
| Guest mode / Lesson 3 complete: "4" on a 10% gold tint (`xiwFJ`) | `#9A6B10` on `#F8F3E6` | 4.23 | `#704D0F` | 6.87 |
| Study / Returning · light: sparkles icon on a gold tint (`dYcRD`) | `#B8860B` on `#F9EFDD` | 2.85 | `#986910` | 4.22 |
| Any gold pill label on a 12–16% gold tint (Official, Mentor, Milestone, Daily study, scripture chips) | `#9A6B10` on its tint | about 4.0–4.4 | `#704D0F` | 5.9 or more |

## 3. Grey text and icons on light surfaces

| Where | Pair now | Ratio | Replace with | New ratio |
|---|---|---|---|---|
| Sign in · light form labels and links: "Email", "Password", "Don't have an account?" (9 nodes, `nW3lP`, `MUDZt`, `UI3TG`) | `#9CA3AF` on `#FAF8F5` | 2.40 | `#6F6B61` | 5.01 |
| Light dock, unselected labels "Home", "Discipler", "Topics" (`iasA9`, `GMBty`, `X7m7Hy`) | `#9CA3AF` on white | 2.54 | `#6F6B61` | 5.31 |
| Helper and placeholder text: "At least 8 characters", the Generate placeholder, "Quick Read 10 · Standard 20" (`VRWgq`, `WDBmK`, `dXC2w`) | `#8A8F9C` on white | 3.24 | `#6F6B61` (helper) / `#7B766D` (placeholder) | 5.31 / 4.51 |
| Fine print: "By continuing, you agree…", "Saved verses come back…", "Trial on the web…" (`ao1Be`, `fmmaS`, `IDOlS`) | `#8A8F9C` on `#FAF8F5` | 3.05 | `#716C64` | 4.91 |
| Guest Home · light: row chevrons (10 nodes, `XWnVv`, `rraOL`, `sG3JE`) | `#B5B0A4` on `#FAF8F5` | 2.04 | `#8A857A` | 3.47 |
| Lesson 3 complete: lock on raised (`f4LQQ`) and close icon (`wFMsM`) | `#B5B0A4` on `#F1EEE7` / white | 1.87 / 2.16 | `#8A857A` | 3.17 / 3.67 |
| Memory verses / With verses · light: "Due" chip (`SaNYM`, `pfHC2`) | `#6F6B61` on `#F1F1F2` | 4.71 | `#5E5A50` | 6.09 |

## 4. Status colours

| Where | Pair now | Ratio | Replace with | New ratio |
|---|---|---|---|---|
| Guest mode / Account needed · light: check icons (`cGaHk`, `wwI8U`, `DSASi`) | `#10B981` on white | 2.54 | `#065F46` | 7.68 |
| Light status text and solid fills (app tokens) | Emerald, Amber and Red-700 | 4.3–5.2 on their own tints | **Emerald-800 `#065F46`, Amber-800 `#92400E`, Red-800 `#991B1B`** | 5.5 or more on tints, white on them 7.1–8.3 |
| Dark "End" / "Confirm cancel" on a red tint (`W0CmoV`, `clAsJ`) | `#F87171` on `#392429` | 5.21 | `#FCA5A5` | 7.59 |
| Dark "Prayer" chip on a pink tint (`pxgRN`) | `#F472B6` on `#362432` | 5.45 | `#F9A8D4` | 7.96 |

## 5. Dark frames

| Where | Pair now | Ratio | Replace with | New ratio |
|---|---|---|---|---|
| Guest Home · dark: chevrons and copy icons (18 nodes, `cLhjS`, `RFfe9`, `uWQch`) | `#5A5A63` on `#121212` | 2.75 | `#86868E` | 5.19 |
| First run / 4 Lesson complete: lock icons (`jdsfo`, `XV9Xb`) | `#5A5A63` on `#1F1F27` | 2.40 | `#86868E` | 4.53 |
| Preferences / Theme: chevrons (`Edpck`, `bFszM`) | `#6B6B75` on `#272320` | 2.96 | `#86868E` | 4.31 |
| Study / First time: field placeholder (`M411s`, `FyFU5`) | `#8A8F9C` on white | 3.24 | `#7B766D` | 4.51 |
| First run / 5 Home after sign-in: dock labels (96 nodes, e.g. `vj6aZ`) | `#8A8A95` on `#1C1C24` | 4.96 | `#9CA3AF` | 6.67 (optional, below the 5.5 label floor) |

## 6. Values to add to the design's colour list

| Token | Light | Dark | Use |
|---|---|---|---|
| Selected fill / ink on it | `#D4A23A` / `#1A1917` | `#E3B154` / `#1A1917` | chosen chip, segment, option, gold badge |
| Secondary on the selected fill | `#1A1917` at 85% | same | duration or cost line on a selected chip |
| Gold label on a gold tint | `#704D0F` | `#E3B154` | Official, Mentor, Milestone, Daily study and scripture chips |
| Gold graphics (switch track, radio, slider, progress) | `#986910` | `#E3B154` | 4.5:1 on the light page (the selected fill is 2.2:1) |
| Switch thumb when on | white | ink `#1A1917` | white on `#E3B154` was 1.9:1 |
| Input focus ring | `#BC851F` | `#E3B154` | 3.2:1 on the white field |
| Status text and fills on light | `#065F46`, `#92400E`, `#991B1B` | `#34D399`, `#FCD34D`, `#F87171` | dark chip labels are lifted per tint in the app |
