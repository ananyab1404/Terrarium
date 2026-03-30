# Infinity Node — Frontend PRD

### Dashboard UI · v1.0

#### Vercel-structure × PostHog-soul × Dark Systems Aesthetic

---

## 1. Product Vision

Infinity Node's dashboard is the **control plane for serverless compute at the systems level**. It is not a typical SaaS dashboard — it is an operational interface for engineers who care deeply about what's happening inside their infrastructure.

The visual direction is: **PostHog's data-dense dark UI**, structured with **Vercel's layout discipline**, executed with a **terminal-meets-glass aesthetic**. The result feels like a Bloomberg terminal designed by someone who has tasted good software. Every pixel earns its place. Every animation communicates state, not decoration.

---

## 2. Design Language

### 2.1 Aesthetic Direction

**"Dark Systems Glass"** — a high-density dark UI that communicates trust, precision, and control. Think: the dashboard a senior infra engineer would actually want to use at 2am during an incident. Not pretty for its own sake — precise, information-rich, and calm under pressure.

Key aesthetic commitments:

- **Dark** always. No light mode in MVP. The interface lives in the dark.
- **Data-forward** — every surface that can show live data, shows live data
- **Controlled density** — PostHog-style information packing, but with Vercel's discipline around whitespace
- **Glass & depth** — layered surfaces with subtle translucency, not flat cards
- **Monospace where it matters** — logs, hashes, execution IDs, metrics always render in mono
- **Micro-animations everywhere** — status pulses, number counters, skeleton shimmer, line chart draws

---

### 2.2 Color System

All colors defined as CSS custom properties. No hardcoded values in components.

```css
:root {
  /* ── Base Surfaces ─────────────────────────────────── */
  --bg-void: #080a0e; /* true background — almost black, very slight blue tint */
  --bg-base: #0d1117; /* primary surface (cards, panels) */
  --bg-elevated: #161b22; /* elevated cards, modals */
  --bg-overlay: #1c2333; /* tooltips, dropdown menus */
  --bg-glass: rgba(22, 27, 34, 0.72); /* frosted glass panels */

  /* ── Borders ───────────────────────────────────────── */
  --border-subtle: rgba(48, 54, 61, 0.6);
  --border-default: rgba(48, 54, 61, 1);
  --border-strong: rgba(110, 118, 129, 0.4);
  --border-glow: rgba(88, 166, 255, 0.35); /* focus rings, active states */

  /* ── Typography ────────────────────────────────────── */
  --text-primary: #e6edf3;
  --text-secondary: #8b949e;
  --text-muted: #484f58;
  --text-inverse: #0d1117;
  --text-mono: #79c0ff; /* monospace values, hashes, IDs */

  /* ── Brand / Accent ────────────────────────────────── */
  --accent-primary: #58a6ff; /* PostHog-adjacent blue — primary CTAs, links */
  --accent-secondary: #a371f7; /* purple — secondary actions, tags */
  --accent-glow: rgba(88, 166, 255, 0.15);

  /* ── Semantic Status Colors ────────────────────────── */
  --status-success: #3fb950;
  --status-success-dim: rgba(63, 185, 80, 0.12);
  --status-success-glow: rgba(63, 185, 80, 0.3);

  --status-error: #f85149;
  --status-error-dim: rgba(248, 81, 73, 0.12);
  --status-error-glow: rgba(248, 81, 73, 0.3);

  --status-warning: #d29922;
  --status-warning-dim: rgba(210, 153, 34, 0.12);

  --status-pending: #58a6ff;
  --status-pending-dim: rgba(88, 166, 255, 0.12);

  --status-running: #79c0ff;
  --status-running-glow: rgba(121, 192, 255, 0.25);

  --status-idle: #8b949e;

  /* ── PostHog Influence — Data Visualization ─────────── */
  --chart-1: #58a6ff; /* blue */
  --chart-2: #3fb950; /* green */
  --chart-3: #a371f7; /* purple */
  --chart-4: #ffa657; /* orange */
  --chart-5: #f85149; /* red */
  --chart-6: #79c0ff; /* light blue */

  /* ── Gradients ─────────────────────────────────────── */
  --gradient-brand: linear-gradient(135deg, #58a6ff 0%, #a371f7 100%);
  --gradient-success: linear-gradient(135deg, #3fb950 0%, #58a6ff 100%);
  --gradient-surface: linear-gradient(
    180deg,
    rgba(22, 27, 34, 0) 0%,
    rgba(22, 27, 34, 0.8) 100%
  );
  --gradient-glow: radial-gradient(
    ellipse at top,
    rgba(88, 166, 255, 0.08) 0%,
    transparent 60%
  );
}
```

---

### 2.3 Typography

```css
/* Display / Headings */
@import url("https://fonts.googleapis.com/css2?family=DM+Mono:ital,wght@0,300;0,400;0,500;1,400&family=Syne:wght@400;500;600;700;800&display=swap");

:root {
  --font-display: "Syne", sans-serif; /* section titles, hero numbers, nav */
  --font-body: system-ui, -apple-system, "Segoe UI", sans-serif;
  --font-mono: "DM Mono", "Fira Code", "Cascadia Code", monospace;

  /* Scale */
  --text-xs: 11px;
  --text-sm: 12px;
  --text-base: 14px;
  --text-md: 15px;
  --text-lg: 18px;
  --text-xl: 22px;
  --text-2xl: 28px;
  --text-3xl: 36px;

  /* Weight */
  --weight-regular: 400;
  --weight-medium: 500;
  --weight-semibold: 600;
  --weight-bold: 700;
  --weight-black: 800;

  /* Line Heights */
  --leading-tight: 1.2;
  --leading-normal: 1.5;
  --leading-loose: 1.75;
}

/* Usage rules */
/* All metric numbers → font-mono, text-mono color */
/* Log output → font-mono, text-secondary */
/* Job IDs, hashes → font-mono, text-muted, selectable */
/* Section titles → font-display, weight-semibold */
/* Body copy → font-body, weight-regular */
```

---

### 2.4 Spacing & Layout

```css
:root {
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-5: 20px;
  --space-6: 24px;
  --space-8: 32px;
  --space-10: 40px;
  --space-12: 48px;
  --space-16: 64px;

  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-xl: 16px;
  --radius-full: 9999px;

  --sidebar-width: 240px;
  --topbar-height: 52px;
  --content-max-width: 1200px;
}
```

---

### 2.5 Elevation & Shadow

```css
:root {
  --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.4);
  --shadow-md: 0 4px 12px rgba(0, 0, 0, 0.5), 0 1px 3px rgba(0, 0, 0, 0.3);
  --shadow-lg: 0 8px 32px rgba(0, 0, 0, 0.6), 0 2px 8px rgba(0, 0, 0, 0.4);
  --shadow-glow:
    0 0 20px rgba(88, 166, 255, 0.15), 0 0 40px rgba(88, 166, 255, 0.05);
  --shadow-success-glow: 0 0 16px rgba(63, 185, 80, 0.2);
  --shadow-error-glow: 0 0 16px rgba(248, 81, 73, 0.2);
}
```

---

## 3. Animation System

Every animation must communicate something meaningful. There are no decorative animations.

### 3.1 Animation Tokens

```css
:root {
  --ease-spring: cubic-bezier(
    0.34,
    1.56,
    0.64,
    1
  ); /* bouncy — status changes */
  --ease-smooth: cubic-bezier(0.4, 0, 0.2, 1); /* standard — panels, modals */
  --ease-out: cubic-bezier(0, 0, 0.2, 1); /* exits */
  --ease-in: cubic-bezier(0.4, 0, 1, 1); /* enters */

  --duration-fast: 80ms;
  --duration-base: 150ms;
  --duration-slow: 250ms;
  --duration-slower: 400ms;
  --duration-slowest: 600ms;
}
```

### 3.2 Defined Animations

**StatusPulse** — used on any RUNNING/PENDING status dot

```css
@keyframes status-pulse {
  0%,
  100% {
    opacity: 1;
    box-shadow: 0 0 0 0 var(--status-running-glow);
  }
  50% {
    opacity: 0.8;
    box-shadow: 0 0 0 6px transparent;
  }
}
.status-running {
  animation: status-pulse 2s ease-in-out infinite;
}
```

**NumberTick** — when a metric counter updates, digits scroll vertically (slot-machine style)
Implementation: wrap each digit in an overflow-hidden container; on change, animate `translateY` from +100% to 0. Duration 200ms, ease-out.

**SkeletonShimmer** — loading state for all cards and log rows

```css
@keyframes shimmer {
  0% {
    background-position: -400px 0;
  }
  100% {
    background-position: 400px 0;
  }
}
.skeleton {
  background: linear-gradient(
    90deg,
    var(--bg-elevated) 25%,
    var(--bg-overlay) 50%,
    var(--bg-elevated) 75%
  );
  background-size: 800px 100%;
  animation: shimmer 1.4s ease-in-out infinite;
}
```

**PageTransition** — route changes

```css
@keyframes page-enter {
  from {
    opacity: 0;
    transform: translateY(8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
.page-enter {
  animation: page-enter var(--duration-slower) var(--ease-smooth) both;
}
```

**LogLineAppear** — new log lines streaming into the log viewer

```css
@keyframes log-appear {
  from {
    opacity: 0;
    transform: translateX(-4px);
    background: rgba(88, 166, 255, 0.06);
  }
  to {
    opacity: 1;
    transform: translateX(0);
    background: transparent;
  }
}
.log-line-new {
  animation: log-appear var(--duration-slow) var(--ease-smooth) both;
}
```

**ChartDraw** — line charts draw from left on mount

```css
/* SVG stroke-dasharray trick — animate stroke-dashoffset from full-length to 0 */
/* Duration: 800ms, ease-out, stagger each series by 100ms */
```

**GlowPulse** — overview hero metrics during active execution

```css
@keyframes glow-pulse {
  0%,
  100% {
    box-shadow: var(--shadow-glow);
  }
  50% {
    box-shadow:
      0 0 40px rgba(88, 166, 255, 0.25),
      0 0 80px rgba(88, 166, 255, 0.1);
  }
}
```

**TerminalCursor** — blinking cursor in log viewer and code upload terminal preview

```css
@keyframes blink {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0;
  }
}
.cursor::after {
  content: "▋";
  color: var(--accent-primary);
  animation: blink 1.1s step-end infinite;
}
```

**Sidebar item hover** — subtle `translateX(3px)` on hover, 100ms ease-out

**Card hover** — `translateY(-2px)` + shadow increase, 150ms ease-smooth

**Modal enter** — scale from 0.96 to 1.0, opacity 0→1, backdrop blur animates in, 200ms

**Toast notification** — slides in from bottom-right, 250ms spring. Auto-dismisses with shrink-height animation.

---

## 4. Application Layout

### 4.1 Global Shell

```
┌──────────────────────────────────────────────────────────────────┐
│  TOPBAR  [52px]                                                  │
│  ▲ InfinityNode  [project selector ▾]    [Search]  [Notif] [Ava] │
├───────────┬──────────────────────────────────────────────────────┤
│           │                                                      │
│  SIDEBAR  │   MAIN CONTENT AREA                                  │
│  [240px]  │   max-width: 1200px, centered with padding           │
│           │                                                      │
│  (fixed)  │   (scrollable)                                       │
│           │                                                      │
└───────────┴──────────────────────────────────────────────────────┘
```

The topbar is always `position: sticky; top: 0; z-index: 100`. It has `backdrop-filter: blur(12px)` with `background: var(--bg-glass)`. A 1px bottom border `var(--border-subtle)`.

The sidebar is `position: fixed; left: 0`. Same glass treatment as topbar.

---

### 4.2 Sidebar Navigation

```
▲ InfinityNode                    ← project name, monospace, with animated triangle
─────────────────────
⬡  Overview                       ← hex icon (brand)
⚡  Deployments
📋  Jobs                           ← live badge showing RUNNING count
📜  Logs
📊  Analytics
───────────── COMPUTE ────────────
☁️  Functions                      ← upload landing
🐳  Containers
🌐  Regions
───────────── CONFIG ─────────────
⚙️  Settings
🔑  API Keys
🔔  Alerts
─────────────────────
🧪  Sandbox                        ← test execution env
```

Each nav item: 36px height, `--radius-md`, hover state `background: var(--bg-elevated)` with left border `2px solid transparent` → `2px solid var(--accent-primary)` on active. The transition is 80ms. Active item text color: `--text-primary`.

The RUNNING badge on Jobs: small pill, `--status-running` background, animated with `status-pulse`. Number inside ticks with NumberTick animation when count changes.

---

## 5. Pages

---

### 5.1 Overview Page

The hub. Everything important visible in one scroll.

#### 5.1.1 Hero Metrics Bar

Full-width row of 5 stat cards immediately below the breadcrumb. These are the most important numbers on the platform.

```
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  RUNNING    │ │  JOBS/SEC   │ │  P99 LATENCY│ │  ERROR RATE │ │  QUEUE DEPTH│
│             │ │             │ │             │ │             │ │             │
│    ● 24     │ │   147.3     │ │   38ms      │ │   0.12%     │ │    82       │
│  +3 (1m)   │ │  ↑ 12%      │ │  ↓ 4ms      │ │  ● healthy  │ │  draining   │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
```

Each card:

- Background: `var(--bg-elevated)`, border `1px solid var(--border-subtle)`
- The large number: `font-display`, `--text-2xl`, `--weight-bold`, `--text-primary`
- Units / label: `font-mono`, `--text-xs`, `--text-muted`, uppercase, letter-spacing 0.08em
- Delta (e.g. "+3 (1m)"): `--text-sm`, color based on whether up/down is good or bad for that metric
- RUNNING card: the dot pulses with `status-pulse`. On hover, the card lifts `translateY(-2px)`.
- Numbers animate with NumberTick on every update (WebSocket-pushed).

#### 5.1.2 Execution Timeline (Live)

A horizontal swimlane chart — one lane per active worker node. Each lane shows in-flight jobs as colored bars (duration proportional to estimated wall time). New jobs animate in from the right. Completed jobs shrink and fade.

```
worker-node-01 ──[██████ fn:resize-image]────[████ fn:send-email]──────────
worker-node-02 ──[███ fn:parse-csv]──────────────────────────────[██ fn:...]
worker-node-03 ──────────────────────────────────────────────────────── idle
worker-node-04 ──[████████████████ fn:video-transcode]──────────────────────
```

- Chart background: `var(--bg-base)`, `border-radius: var(--radius-lg)`
- Node label: `font-mono`, `--text-xs`, `--text-muted`
- Job bars: rounded, color by function name (hashed to chart palette), show function name on hover in a tooltip
- "idle" lanes: `--text-muted`, italic, dashed underline
- The entire chart scrolls time (30s window by default). A subtle gradient on right edge fades to `--bg-base`.
- A thin vertical "now" line (1px, `--accent-primary`, 30% opacity) at the right.

#### 5.1.3 Status Grid

Below the timeline, a 2-column layout:

**Left: Recent Jobs Feed**
A dense table, PostHog-style. Infinite scroll (virtual list). Columns:

- `JOB ID` — `font-mono`, `--text-xs`, `--text-muted`, truncated with ellipsis, copy-on-click
- `FUNCTION` — `--text-primary`, `--text-sm`
- `STATUS` — pill badge: RUNNING (blue pulse), TERMINAL ✓ (green), ERROR ✗ (red), PENDING (grey)
- `DURATION` — `font-mono`, `--text-sm`
- `NODE` — `font-mono`, `--text-xs`, `--text-muted`
- `TIME` — relative ("3s ago"), `--text-muted`

Row hover: `background: var(--bg-elevated)`, cursor pointer (navigates to job detail).
New rows entering from top: `log-appear` animation.

**Right: Cluster Health**
A live donut chart (3 segments: RUNNING / IDLE / ERROR slots). Below it:

- Active nodes: `N / MAX`
- Autoscaler state: STABLE / SCALING OUT / DRAINING
- Last scale event: "scaled out +2 nodes, 4m ago"

The donut chart arcs draw with a CSS stroke-dashoffset animation on mount and re-draw smoothly on data change.

#### 5.1.4 Deployment Card (Vercel-style)

Below the grid, a single card that mirrors Vercel's deployment panel:

```
┌─────────────────────────────────────────────────────────────────────┐
│  Production Deployment                    [Repository] [Rollback]   │
│                                                                     │
│  ┌────────────────────┐   Deployment:                               │
│  │                    │   ▸ abc123f  main  3 hours ago              │
│  │  [Live Preview     │                                             │
│  │   Screenshot]      │   Status:  ● Ready                         │
│  │                    │   Region:  us-east-1                        │
│  │                    │   Nodes:   4 active                         │
│  └────────────────────┘                                             │
│                                                                     │
│  ● Last commit · fix(worker): increase vm snapshot pool size · 3h   │
└─────────────────────────────────────────────────────────────────────┘
```

The preview area is a dark container showing an animated sparkline of recent throughput (subtle, like a ghost chart). On hover it reveals "View Live Dashboard →".

---

### 5.2 Jobs Page

The operational console for job lifecycle.

#### 5.2.1 Filter Bar

Sticky below topbar. Contains:

- Search input (searches by job ID, function name, input payload snippet). Shortcut: `/` key.
- Status filter: pill toggles (ALL | RUNNING | TERMINAL | ERROR | PENDING | DEAD-LETTER)
- Function filter: dropdown, multi-select
- Node filter: dropdown
- Time range: relative presets (1h / 6h / 24h / 7d) + custom range picker
- Auto-refresh toggle: 🔴 LIVE (blinking dot) / PAUSED

#### 5.2.2 Jobs Table

Dense, high-information table. Each row is 48px. Columns:

| Column    | Width | Details                                                |
| --------- | ----- | ------------------------------------------------------ |
| STATUS    | 100px | Animated pill                                          |
| JOB ID    | 140px | `font-mono`, copy icon on hover                        |
| FUNCTION  | 180px | Function name + version tag                            |
| INPUT     | 200px | JSON preview, truncated, expand on hover               |
| DURATION  | 100px | Wall time in `font-mono`                               |
| NODE      | 130px | Node ID, `font-mono`                                   |
| MEMORY    | 80px  | Peak MB, color-coded (yellow near limit, red at limit) |
| EXIT      | 60px  | Exit code, `font-mono`                                 |
| TIMESTAMP | 120px | Relative + absolute on hover                           |

Clicking a row opens the **Job Detail Drawer** (slides in from right, 480px wide, `--ease-spring` animation, backdrop blur on main content behind it).

**Dead-letter rows** have a full-row subtle red tint `rgba(248,81,73,0.04)` and a left border `3px solid var(--status-error)`.

#### 5.2.3 Job Detail Drawer

Slides in from the right. Contains:

**Header:**

- Job ID (`font-mono`, large, copyable)
- Status badge (large version, animated if RUNNING)
- Function name + version

**Sections (tabbed):**

1. **Summary** — execution metadata table (all fields from the telemetry envelope)
2. **Logs** — embedded log viewer (same component as full Logs page, scoped to this job)
3. **Input / Output** — collapsible JSON viewers with syntax highlighting
4. **Timeline** — horizontal bar: queue wait | execution | overhead, colored segments

**Footer actions:**

- Re-run with same input
- Copy job ID
- View function definition
- If dead-lettered: "Re-enqueue" button

---

### 5.3 Logs Page

Real-time log streaming with full traceability.

#### 5.3.1 Log Viewer Layout

```
┌─ Filter ─────────────────────────────────────────────────────────────┐
│  [Search logs...]  [Function ▾]  [Node ▾]  [Level ▾]  [● LIVE]      │
└──────────────────────────────────────────────────────────────────────┘

┌─ Log Stream ─────────────────────────────────────────────────────────┐
│                                                                      │
│  10:42:33.881  INFO   [job:a3f2c1]  fn:resize-image  started         │
│  10:42:33.902  DEBUG  [job:a3f2c1]  artifact loaded, size: 2.3MB     │
│  10:42:33.951  INFO   [job:a3f2c1]  vm:slot-4  execution started     │
│  10:42:34.102  STDOUT [job:a3f2c1]  Processing image batch: 24 items │
│  10:42:34.220  STDOUT [job:a3f2c1]  ✓ completed 24/24                │
│  10:42:34.231  INFO   [job:a3f2c1]  exit code: 0, wall: 280ms        │
│  10:42:34.245  INFO   [job:a3f2c1]  vm:slot-4  snapshot restored     │
│  ──────────────────────────────────────────────────────────────────  │
│  10:42:34.311  ERROR  [job:b7d9e2]  fn:parse-csv  oom killed         │
│  10:42:34.318  WARN   [job:b7d9e2]  peak_memory: 256MB (at limit)    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Log line anatomy:**

```
[timestamp]  [LEVEL]  [context tags]  message
```

- Timestamp: `font-mono`, `--text-xs`, `--text-muted`
- Level pill: color-coded
  - `INFO` — `--accent-primary`, dim background
  - `DEBUG` — `--text-muted`, no background
  - `WARN` — `--status-warning`
  - `ERROR` — `--status-error`, full row tint `rgba(248,81,73,0.06)`
  - `STDOUT` — `--status-success`
  - `STDERR` — `--status-warning`
- Context tags `[job:xxx]` — `font-mono`, `--accent-secondary`, clickable (filters to that job)
- Message: `font-mono`, `--text-secondary`, wraps at container edge

**Live streaming behavior:**

- New lines enter with `log-appear` animation
- Auto-scroll is on by default. When user scrolls up manually, auto-scroll pauses and a "↓ Jump to latest" pill appears at the bottom (animated, `--ease-spring`). Clicking it resumes auto-scroll.
- Horizontal separator lines (dashed, `--border-subtle`) appear between job executions
- Line count indicator in top-right: "12,847 lines" — updates with NumberTick

**Search:**

- Matches highlight inline with `--accent-primary` background, 25% opacity
- Non-matching lines dim to 30% opacity (PostHog-style)
- Match count: "47 matches"
- Arrow keys cycle through matches

#### 5.3.2 Observability Panel (Right Sidebar, toggleable)

When expanded (320px), shows alongside the log stream:

- **Error rate chart** — sparkline, last 1h
- **Log volume chart** — bar chart by level, last 1h
- **Top functions by log volume** — ranked list
- **Recent error summary** — grouped error messages with count badges
- **Trace view** — when a job ID is selected in logs, shows the full execution trace as a waterfall (queue wait → vm boot → execution → cleanup)

---

### 5.4 Functions Page (Upload + Management)

Where developers submit their code.

#### 5.4.1 Page Layout

```
┌─ Functions ──────────────────────────────── [+ Deploy Function] ──┐
│                                                                    │
│  ┌─ Upload Zone ────────────────────────────────────────────────┐ │
│  │                                                              │ │
│  │          ↑  Drag & drop your function tarball               │ │
│  │             or paste a Docker image URL                     │ │
│  │                                                              │ │
│  │     [ Browse files ]    [ From Git ]    [ From Registry ]   │ │
│  │                                                              │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  ─── Deployed Functions ────────────────────────────────────────  │
│                                                                    │
│  [fn card]  [fn card]  [fn card]  [fn card]                        │
│  [fn card]  [fn card]  [fn card]  ...                              │
└────────────────────────────────────────────────────────────────────┘
```

#### 5.4.2 Upload Zone

The drag-and-drop area is the hero element of this page.

**Default state:**

- Dashed border `2px dashed var(--border-default)`, `--radius-xl`
- Dark background `var(--bg-base)`
- Center icon: upload arrow, `--text-muted`, 32px
- Text: `--text-secondary`

**Drag-over state:**

- Border changes to `2px dashed var(--accent-primary)`
- Background: `var(--accent-glow)`
- Border animates — the dashes themselves animate (CSS `border-style: dashed` with a `stroke-dashoffset` trick or SVG border overlay)
- Icon scales up `1.1x` with `--ease-spring`
- Label changes: "Release to upload"

**Processing state (after drop):**
A terminal-style progress block replaces the upload prompt:

```
● Validating artifact...          ✓
● Hashing content (SHA-256)...    ✓ a3f2c1b9...
● Uploading to S3...              ████████████ 100%
● Registering function...         ✓
● Running smoke test...           ✓ exit 0 (42ms)

Function deployed: fn:image-resize v1.0.0
ID: fn_01J8K3M2P4Q6R8S0T2V4W6X8Y0
```

Each line appears sequentially with a `log-appear` animation. The progress bar fills with a smooth CSS transition.

**Three upload paths:**

1. **Tarball upload** — the drag-and-drop zone above
2. **Git integration** — click "From Git" opens a modal: connect GitHub → select repo → select branch → map entrypoint. Shows a preview of the detected runtime.
3. **Container registry** — paste a Docker image URL. Platform validates the image exists and pulls the manifest.

#### 5.4.3 Function Cards

Grid of cards, 3-per-row. Each card:

```
┌─────────────────────────────────────────┐
│  fn:image-resize          [● active] ▸  │
│                                         │
│  v2.1.0 · Python 3.11 · 128MB          │
│                                         │
│  ████████ 1,247 invocations today       │
│  P99: 38ms · Error: 0.1%               │
│                                         │
│  Deployed 2h ago by krishang            │
└─────────────────────────────────────────┘
```

- `active` badge: green, pulsing dot
- Invocation bar: a thin sparkline chart (last 24h), fills the card width
- Hover: card lifts, right arrow appears, "View Details →"
- Click: navigates to Function Detail page

#### 5.4.4 Function Detail Page

Full-page view for a single function. Tabs:

1. **Overview** — invocation chart (daily), error rate, latency histogram, last 10 invocations
2. **Versions** — git-style version history, each version with deploy timestamp and diff link
3. **Configuration** — runtime settings, resource limits, environment variables (masked by default), timeout
4. **Invoke** — interactive sandbox: JSON input editor + "Run" button. Live result and logs appear below.
5. **Logs** — scoped log viewer for this function only

---

### 5.5 Containers Page

Identical structure to Functions page but for Docker containers.

Additional fields:

- Base image, image size, pull time
- Port mapping configuration
- Health check endpoint configuration

The upload flow accepts a Docker image URL or tarball. A "Scan Image" button runs a manifest analysis and shows layer breakdown.

---

### 5.6 Analytics Page

PostHog-inspired. Data-forward. No fluff.

Layout: full-width, 2-column on desktop.

**Left column:**

- Invocations over time (line chart, selectable series: total / by function / by node)
- Latency percentiles over time (P50 / P95 / P99 stacked area chart)
- Error rate over time

**Right column:**

- Top functions by invocation count (horizontal bar chart)
- Top functions by error count
- Node utilization heatmap (Y: nodes, X: time, color: utilization %)

All charts:

- Background: `var(--bg-base)`
- Axes: `--text-muted`, `font-mono`, `--text-xs`
- Series colors: `--chart-N` tokens
- Tooltips: glass panel, `backdrop-filter: blur(8px)`, show all series values on hover
- Charts draw on mount (stroke-dashoffset animation, staggered by series)
- Time range selector at top: same presets as Jobs page

---

## 6. Component Library

### 6.1 Status Badge

```
Variants: running | terminal | error | pending | dead-letter | idle

running:     [ ● RUNNING  ]   blue,   pulsing dot
terminal:    [ ✓ DONE     ]   green,  no animation
error:       [ ✗ ERROR    ]   red,    static
pending:     [ ◌ PENDING  ]   grey,   slow fade in/out on dot
dead-letter: [ ⚠ DL       ]   orange, static
idle:        [   IDLE     ]   muted,  no dot
```

Pill shape, `--radius-full`, 5px horizontal padding, 3px vertical padding. Font: `font-mono`, `--text-xs`, uppercase, letter-spacing 0.06em.

### 6.2 Buttons

```
Primary:   filled, --accent-primary bg, --text-inverse, hover: brighten 10%
Secondary: outlined, --border-default, --text-primary, hover: --bg-elevated fill
Ghost:     transparent, --text-secondary, hover: --text-primary + --bg-elevated
Danger:    filled, --status-error bg on hover (transitions from secondary)
```

All buttons: `--radius-md`, 32px height (standard), 40px (large). Disabled: 40% opacity, cursor not-allowed. Focus ring: `2px solid var(--border-glow)`, 2px offset.

Click animation: `scale(0.97)`, 80ms, spring ease.

### 6.3 Input / Search

```css
.input {
  background: var(--bg-base);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-md);
  color: var(--text-primary);
  font-family: var(--font-mono);
  font-size: var(--text-sm);
  padding: 8px 12px;
  transition:
    border-color var(--duration-base) var(--ease-smooth),
    box-shadow var(--duration-base) var(--ease-smooth);
}
.input:focus {
  border-color: var(--accent-primary);
  box-shadow: 0 0 0 3px var(--accent-glow);
  outline: none;
}
```

### 6.4 Code / JSON Viewer

Syntax-highlighted, dark theme. Token colors:

- Keys: `--accent-primary`
- Strings: `--status-success`
- Numbers: `--chart-4` (orange)
- Booleans/null: `--accent-secondary`
- Punctuation: `--text-muted`

Collapsible nested objects with animated expand/collapse (height + opacity). Copy button top-right.

### 6.5 Toast Notifications

Stacks at bottom-right. Max 3 visible (older ones compress/hide).

```
┌────────────────────────────────────────┐
│  ✓  Function deployed successfully     │
│     fn:image-resize v2.1.0             │       [×]
└────────────────────────────────────────┘
```

- Background: `var(--bg-elevated)`, border `1px solid var(--border-default)`
- Left accent strip: 3px, color by type (success/error/warning/info)
- Enter: `translateY(100%) → 0` + opacity, 250ms spring
- Auto-dismiss: 4s, progress bar animates across the bottom of the toast
- Hover pauses auto-dismiss

### 6.6 Empty States

Every empty table / no-data state uses a consistent pattern:

- Centered illustration (SVG, simple geometric — not clipart)
- Headline: `--text-primary`, `font-display`
- Description: `--text-secondary`
- Primary CTA button

Example: empty Jobs table → server rack SVG + "No jobs yet" + "Deploy your first function →"

---

## 7. Responsive Behavior

The dashboard is optimized for `1280px+` screens. Responsive breakpoints:

| Breakpoint        | Behavior                                                                                |
| ----------------- | --------------------------------------------------------------------------------------- |
| `< 768px`         | Sidebar collapses to icon-only rail (48px). Top bar condenses. Charts stack vertically. |
| `768px – 1024px`  | Sidebar stays open at 200px. 2-column layouts become 1-column.                          |
| `1024px – 1280px` | Full layout, slightly tighter spacing.                                                  |
| `> 1280px`        | Full layout, max-content-width constraint applied.                                      |

Mobile-specific note: the Log Viewer becomes a modal sheet on mobile (slides up from bottom, 90vh height, draggable dismiss).

---

## 8. Real-Time Data Architecture (Frontend)

All live data flows through a single WebSocket connection per session.

**WebSocket event types the frontend subscribes to:**

```typescript
type WSEvent =
  | { type: "job.created"; payload: JobEnvelope }
  | { type: "job.updated"; payload: { job_id; state; updated_at } }
  | { type: "job.terminal"; payload: { job_id; exit_code; wall_time_ms } }
  | { type: "metrics.update"; payload: MetricsSnapshot }
  | { type: "log.line"; payload: LogLine }
  | { type: "node.joined"; payload: { node_id } }
  | { type: "node.left"; payload: { node_id } }
  | { type: "scale.event"; payload: { direction; count; reason } };
```

**Frontend state management:**

- Jobs list: keyed map by job ID. Incoming `job.updated` merges into existing entry. New entries prepend to list with `log-appear` animation.
- Metrics: rolling buffer. Each `metrics.update` replaces the current snapshot. NumberTick fires for changed values.
- Logs: virtual list, bounded to last 50,000 lines in memory. Older lines are streamed to a buffer that can be fetched on demand.

**Connection state handling:**

- Connecting: subtle "Connecting..." label next to LIVE indicator
- Connected: green pulsing dot, "LIVE"
- Disconnected: yellow dot, "Reconnecting...", data shown from last known state
- Failed (5+ retries): banner warning, "Live data unavailable. Showing last known state."

---

## 9. Success Criteria for the Frontend

| Criterion                        | Measurement                                                               |
| -------------------------------- | ------------------------------------------------------------------------- |
| Initial page load (LCP)          | < 1.5s on fast connection                                                 |
| Time to interactive              | < 2.5s                                                                    |
| Log stream rendering (10k lines) | No jank — virtual list required                                           |
| NumberTick animation smoothness  | 60fps, no layout thrash                                                   |
| WebSocket reconnect time         | < 3s with exponential backoff                                             |
| Empty → data transition          | No flash of unstyled content — skeleton states required on all async data |
| Animation frame budget           | All animations < 16ms/frame (no heavy JS animations on main thread)       |

---

## 10. Implementation Notes

- **Framework**: React 18 with concurrent features. Suspense boundaries on all async data panels.
- **Routing**: React Router v6. All page transitions use the `page-enter` animation.
- **Charts**: Recharts for standard line/bar charts. D3 for the execution swimlane (custom) and node utilization heatmap.
- **Log virtual list**: `@tanstack/react-virtual` — do not attempt to render 50k DOM nodes.
- **WebSocket**: native WebSocket with a reconnect wrapper. Phoenix Channels if using the Elixir backend directly.
- **Syntax highlighting**: `shiki` (WASM) for JSON viewers and code blocks. Do not ship a full language server.
- **Animation**: Framer Motion for component-level animations. CSS for micro-interactions and status pulses (keep JS animation budget low).
- **Icons**: Lucide React — consistent, sharp, developer-appropriate.
- **Fonts**: loaded via `<link rel="preconnect">` and `font-display: swap`. Never block render on fonts.

---

_Infinity Node Frontend PRD v1.0 · UI Architecture for Dashboard, Logs, Observability, and Function Upload_
