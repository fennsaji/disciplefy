# Colour tokens read from design-v2.pen

Source: `design-v2.pen`, read-only extraction on 2026-10-07 (Home dark/light frames plus a histogram of every fill and stroke in the file). The file has no variables; every colour is a literal on a node. Counts are uses across the whole file.

## Dark (page `#121212`)

| Role | Value | Notes |
|---|---|---|
| Page | `#121212` | splash/hero base `#0B0B0B` |
| Card | `#17171C` | 204 uses |
| Raised / chip | `#1F1F27` (also `#1C1C24`, `#26262F`) | 183 uses |
| Text | `#F2F2F4` | 1072 uses |
| Secondary text | `#9CA3AF` | 618 uses |
| Icons, nav labels | `#8A8A95` | 168 uses |
| Dim / disabled | `#6B6B75` | 131 uses |
| Gold (text, icons, accents, strokes) | `#E3B154` | 1079 uses; tints `/14 /1A /24 /26 /33` alpha |
| Primary button | fill `#FFFFFF`, text `#1A1917` | no indigo |
| Hairline / outline | `#FFFFFF` at 7% / 14% (`/12 /14 /1F /24`) | |
| Verse caption on photo | `#D6D6DC` | |

## Light (page `#FAF8F5`)

| Role | Value | Notes |
|---|---|---|
| Page | `#FAF8F5` | |
| Card | `#FFFFFF` | |
| Raised | `#EEEBE3` (also `#F1EEE7`) | warm, not lavender |
| Ink (text, primary button fill) | `#1A1917` | 455 uses |
| Secondary text | `#6F6B61` | 92 uses |
| Icons / dim | `#8A857A` (also `#B5B0A4` for placeholders) | |
| Gold text / links | `#9A6B10` | 105 uses |
| Gold fill | `#B8860B` | 44 uses |
| Primary button | fill `#1A1917`, text `#FFFFFF` | no indigo |
| Hairline | `#16161D` at 14% (`/24`) | |

## Status (dark surfaces)

Success `#34D399`, error `#F87171`, accent pink `#F472B6`.

## Rules the design follows

- No indigo or lavender anywhere. Selected, progress and link colours are gold.
- Primary action: white pill on dark, ink pill on light.
- Gold on light surfaces is the deep gold (`#9A6B10` text, `#B8860B` fills); `#E3B154` is only used on dark surfaces and over photos.
