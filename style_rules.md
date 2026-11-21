# FReD Apps Style Rules

The FReD apps (landing page, Explorer, Annotator) use the design system of the
**FLoRA Replication Atlas** ([live](https://forrt.org/flora-replication-atlas/),
source: `forrtproject/flora-replication-atlas`, `src/index.css`). When something
below doesn't cover a case, copy what the Atlas does.

All tokens live in [`shared/css/theme.css`](shared/css/theme.css). Component CSS
and JavaScript read tokens; they never hard-code colours.

---

## Colour

### Brand and surfaces
| Token | Light | Dark | Use |
|---|---|---|---|
| `--primary` | `#853953` | `#d68aa7` | Links, primary buttons, active states, headline numbers |
| `--primary-dark` | `#612d53` | `#e7a9c0` | Hover for primary |
| `--primary-light` | `#a04d6b` | `#c27093` | KPI labels |
| `--primary-faint` | `#f9f0f4` | `#3a2530` | Active row, KPI band, hover tint |
| `--primary-soft` | `#ecd9e0` | `#5a3446` | Feature-card border, underlines |
| `--on-primary` | `#fff` | `#1b181a` | Text on a `--primary` fill |
| `--neutral` | `#2c2c2c` | `#121011` | Top bar and footer |
| `--surface` | `#f3f4f4` | `#1b181a` | Page background, inset panels, table header |
| `--surface-alt` | `#e8e9e9` | `#242023` | Secondary-button hover, tracks |
| `--white` | `#fff` | `#2a2528` | Cards, panels, inputs, chart background |

### Text and lines
| Token | Light | Dark |
|---|---|---|
| `--text` | `#2c2c2c` | `#ece8ea` |
| `--text-secondary` | `#4a4a4a` | `#cdc6ca` |
| `--text-muted` | `#5c5c5c` | `#a9a1a6` |
| `--text-faint` | `#696969` | `#958d92` |
| `--border` | `#d0d1d1` | `#463f43` |
| `--border-light` | `#e0e1e1` | `#383236` |

### Outcomes: these encode data, not decoration
Every surface (CSS, Plotly charts, legends, badges, reports) uses the same mapping.

| Meaning | Fill / dot / bar | Text | Tint background | Border |
|---|---|---|---|---|
| Success | `--success` | `--success-light` | `--success-bg` | `--success-border` |
| Mixed | `--warning` (fills only, fails AA as text) | `--warning-text` | `--warning-bg` | `--warning-border` |
| Failure | `--error` | `--error` | `--error-bg` | `--error-border` |
| Not coded / not calculable | `--outcome-na` | `--text-muted` | `--surface-alt` | `--border` |

Chart categories the Atlas does not define (derived from the same family):

| Token | Light | Dark | Outcome labels |
|---|---|---|---|
| `--outcome-reversal` | `#7a1610` | `#dc2626` | failure (reversal); failure (not homogeneous and not significant) |
| `--outcome-failure-partial` | `#e8857a` | `#fdba9f` | failure (not homogeneous but jointly significant) |
| `--outcome-os-ns` | `#9a9c9c` | `#8a8f8f` | OS not significant; uninformative |
| `--outcome-descriptive` | `#8a9bb0` | `#8fa3bd` | descriptive only |
| `--outcome-flawed` | `#c2410c` | `#f97316` | statistically successful but flawed |
| `--sig-yes` / `--sig-no` | plum / `--text-faint` | | Scatterplot significance rugs |
| `--study-original` / `--study-replication` | plum / `#7a7a7a` | plum / `#a9a1a6` | Forest plot and CI mini-chart |

The label → token map lives in `FReD.successCriteria.colorTokens`
([shared/js/success-criteria.js](shared/js/success-criteria.js)). Never use colour
alone: every chart keeps a legend or label.

---

## Typography

- **Display:** Domine (headings, card and modal titles, brand name, big numbers)
- **Body:** Source Sans 3 (everything else)
- Both are self-hosted in `shared/fonts/` (SIL OFL, licences alongside); declared in `shared/css/fonts.css`.

| Token | Size | Use |
|---|---|---|
| `--fs-9` | clamp(30–46px) | Landing hero title (plum) |
| `--fs-8` | clamp(24–32px) | Section headings, `h1` |
| `--fs-7` | clamp(19–21px) | KPI numbers, `h2` |
| `--fs-6` | 16px | Card / modal titles |
| `--fs-5` | 14px | Body copy, inputs |
| `--fs-4` | 13px | Dense UI, buttons, tables |
| `--fs-3` | 12px | Meta, footer, table headers |
| `--fs-2` / `--fs-1` | 11 / 10px | Pills, eyebrow labels (uppercase, letter-spaced) |

---

## Shape, elevation, motion

- **Radius by role:** inputs/tags `--radius-sm` (4px), buttons/controls `--radius` (8px), cards/panels/modals `--radius-lg` (14px), chips/pills `--radius-full`. `50%` only for true circles.
- **Shadows** are plum-tinted: `--shadow-sm` (resting cards), `--shadow-md` (hovered cards), `--shadow-lg` (modals, dropdowns).
- **Motion:** `--transition-fast` (0.12s) for hovers, `--transition` (0.24s) for larger moves. Everything respects `prefers-reduced-motion`.
- **Focus:** a 2px `--primary` outline on `:focus-visible` for every interactive element.

---

## Components

- **Top bar** (`.page-header` > `.topbar`): 52px, `--neutral`, FORRT icon tile + two-line name (Domine title, uppercase subtitle), translucent white nav links, theme toggle as a 32px tile.
- **Footer** (`.footer-bar`): slim `--neutral` strip, 12px text, underlined links.
- **Cards:** white, `--border-light` border, `--radius-lg`, `--shadow-sm`; header in Domine 16px with a hairline divider.
- **Buttons:** primary = `--primary` fill; secondary = white with `--border`; outline = transparent with `--border`. 13px, weight 600.
- **Sidebar nav** (`.sidebar-nav-link`): active row is `--primary-faint` with a 3px `--primary` bar on the left (Atlas list rows), never a solid fill.
- **Tabs:** muted 600-weight labels; active tab is `--primary` with a 2px inset underline.
- **KPI band** (`.sidebar-counts`, `.effect-count`): `--primary-faint` strip, Domine plum numbers, uppercase labels.
- **Badges / outcome pills:** pill radius, tint background + border + text colour from the outcome table.
- **Alerts:** tint background with a 4px coloured left border.
- **Tables (DataTables):** `--surface` header with 12px uppercase labels; hairline row dividers; hover and selected rows use `--primary-faint` (selected adds the 3px left bar). DataTables CSS loads **before** `theme.css` so the overrides win.
- **Modals:** blurred dark backdrop, white `--radius-lg` box, Domine title, `--surface` footer strip.

---

## Theme toggle

1. On load: saved preference in `localStorage['fred-theme']`, else the system preference.
2. Applies `data-theme="light|dark"` on `<html>`; dark mode only overrides tokens.
3. Dispatches a `themechange` event; charts re-render on it.

## Plotly charts

Read colours at render time so charts follow the theme:

```javascript
const themeLayout = FReD.themeToggle.getPlotlyLayout(); // background, grid, fonts, hover label
const colors = FReD.successCriteria.getColorsForCriterion(criterion); // outcome colours
const original = FReD.themeToggle.token('--study-original', '#853953'); // any single token
const label = FReD.themeToggle.textOn(segmentColor); // readable text on a filled bar
```

```javascript
window.addEventListener('themechange', () => {
  if (this.lastData) this.render(this.lastData);
});
```

---

## Responsive breakpoints

| Breakpoint | Change |
|---|---|
| `992px` | Sidebar layout collapses to one column |
| `768px` | Card headers stack; landing app cells stack |
| `720px` | Top bar wraps |
| `576px` | Base font 14px; top-bar subtitle hidden; footer stacks |
