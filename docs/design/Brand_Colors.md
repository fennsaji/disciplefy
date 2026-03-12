# Disciplefy Brand Colors

**Source of truth**: `frontend/lib/core/theme/app_colors.dart`
All colors in the app must originate from `AppColors`. Never use inline hex values.

---

## Brand Palette

| Token | Hex | Tailwind Equiv | Usage |
|---|---|---|---|
| `brandPrimary` | `#4F46E5` | Indigo-600 | Primary buttons, active tabs, highlights |
| `brandPrimaryLight` | `#A5B4FC` | Indigo-300 | Dark-mode primary, hover/focus states |
| `brandSecondary` | `#6366F1` | Indigo-500 | Gradient end, pairs with `brandPrimary` |
| `brandPrimaryDeep` | `#4338CA` | Indigo-700 | High-contrast, pressed states |
| `brandHighlight` | `#FFEEC0` | Amber-100 (custom) | Secondary brand color, verse containers, gold accents |
| `brandHighlightDark` | `#B8860B` | — | Richer gradient pairs with `brandHighlight` |
| `brandAccent` | `#FF6B6B` | — | Action/alert, destructive confirmation |

## Primary Gradient

```
#4F46E5 → #6366F1  (top-left to bottom-right)
brandPrimary → brandSecondary
```

Used via `AppColors.primaryGradient` — a `LinearGradient` constant.

---

## Theme Usage

### Light Theme
- **Primary**: `#4F46E5` (`brandPrimary`) — 5.7:1 contrast on white (WCAG AA)
- **Scaffold background**: `#FAF8F5`
- **Surface**: `#FFFFFF`
- **Text primary**: `#1E1E1E`

### Dark Theme
- **Primary**: `#A5B4FC` (`brandPrimaryLight`) — 8.1:1 on dark surfaces (WCAG AAA)
- **Scaffold background**: `#121212`
- **Surface**: `#1A1A1A`
- **Text primary**: `#E0E0E0`

---

## On-Gradient Colors

Text and icons rendered on a gradient or colored surface should use:

| Token | Value | Opacity |
|---|---|---|
| `onGradient` | `#FFFFFF` | 100% |
| `onGradientMuted` | `#CCFFFFFF` | 80% |
| `onGradientSubtle` | `#99FFFFFF` | 60% |
| `onGradientFaint` | `#66FFFFFF` | 40% |

---

## Semantic Colors

| Token | Hex | Usage |
|---|---|---|
| `success` | `#10B981` | Success states, easy difficulty |
| `error` | `#EF4444` | Error states, hard difficulty |
| `warning` | `#F59E0B` | Warning states, medium difficulty |
| `info` | `#3B82F6` | Informational states |

---

## Rules

- **Never** add inline hex values — always reference `AppColors`
- **Never** use `purple` or `#6A4FB6` — the old brand color, fully replaced by indigo
- For dark mode, use `AppColors.brandPrimaryLight` (`#A5B4FC`) as the primary, not `brandPrimary`
- For interactive elements in dark mode, use `AppColors.brandSecondary` (`#6366F1`) for proper visual weight
- Access the theme-aware primary via `context.appPrimary` (resolves automatically per theme)
