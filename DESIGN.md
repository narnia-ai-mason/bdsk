# DESIGN.md — [App Name] Design System

> A Korean-first voice typing app.
> The moment fragments of sound settle into language — expressed as a small object you'd want to hold, like a pebble.

---

## 1. Concept

**One line:** Scattered fragments of sound (pebbles) settle into the balanced rhythm of a Korean syllable block, and between them a single cursor glows warm.

**Three keywords**

| Keyword             | Meaning                                                                                                                     | Translation into UI                                                                  |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **Pebble**          | Not a perfect circle — organic roundness worn smooth by water                                                               | Every container uses large, slightly asymmetric curvature. No sharp corners anywhere |
| **Syllable rhythm** | Like initial, medial, and final consonants balancing inside one block, elements of different sizes align into a single unit | Clusters over grids. Elements lean on each other, with a base bar underneath         |
| **Warm cursor**     | A vertical glowing line = "I'm listening, and I'm writing right now"                                                        | The app's only luminous element. Appears only in listening/typing states             |

**Mood:** Modern Korean digital craft. Calm, warm, minimal ceramic. Avoid futuristic, neon, or "tech" aesthetics.

**Forbidden metaphors:** No microphones, speech bubbles, waveforms, or Hangul glyphs used as decoration. Sound is expressed only through form and arrangement.

---

## 2. Color

### 2.1 Dark palette (default)

| Token                 | HEX                      | Usage                                                           |
| --------------------- | ------------------------ | --------------------------------------------------------------- |
| `--bg-base`           | `#2A2540`                | App background (deep plum)                                      |
| `--bg-surface`        | `#352F4D`                | Cards, sheets, panels (the icon's rounded square)               |
| `--bg-surface-raised` | `#3E3858`                | Hover/active surfaces, popovers                                 |
| `--stroke-subtle`     | `#4A4466`                | Dividers, inactive borders                                      |
| `--lavender`          | `#B9B5DF`                | Primary accent — main interactions, links, progress             |
| `--lavender-deep`     | `#8F8ABD`                | Pressed/selected lavender                                       |
| `--pink`              | `#F2C3CB`                | Secondary accent — emphasis, new items, soft warnings           |
| `--pearl`             | `#F1ECEC`                | Body text, primary button background                            |
| `--pearl-muted`       | `#C9C3CF`                | Secondary text, placeholders                                    |
| `--cursor-glow`       | `#FFE6C2`                | **Cursor / listening-state glow. Never used for anything else** |
| `--shadow`            | `rgba(16, 12, 30, 0.45)` | Drop shadows                                                    |

### 2.2 Light variant

| Token                 | HEX       | Usage                                              |
| --------------------- | --------- | -------------------------------------------------- |
| `--bg-base`           | `#F4F1F3` | Background (pearl gray)                            |
| `--bg-surface`        | `#FFFFFF` | Cards                                              |
| `--bg-surface-raised` | `#F9F6F8` | Hover surfaces                                     |
| `--stroke-subtle`     | `#E4DEE6` | Dividers                                           |
| `--text-primary`      | `#2A2540` | Body text (deep plum)                              |
| `--text-secondary`    | `#6E6886` | Secondary text                                     |
| `--lavender`          | `#8F8ABD` | Primary accent (one step deeper in light mode)     |
| `--pink`              | `#E9A9B5` | Secondary accent                                   |
| `--cursor-glow`       | `#F5B96E` | Cursor (saturation raised for visibility on light) |

### 2.3 Semantic colors

No primary red/green for error/success. Resolve everything within the palette.

- Success: `--lavender` + check icon
- Warning: `--pink` tones (`#F2C3CB` / deeper `#D98B9A`)
- Error: `#D98B9A` text on a 10% `--pink` tint background. No red.
- Info: `--pearl-muted`

### 2.4 Color proportions

Background 60% / surfaces 25% / pearl & text 10% / lavender & pink 4% / cursor glow 1%.
If accents exceed ~5% of the screen, "light resting on a pebble" becomes "a neon sign."

---

## 3. Typography

### 3.1 Typefaces

| Role                                           | Typeface                                                            | Fallback                          |
| ---------------------------------------------- | ------------------------------------------------------------------- | --------------------------------- |
| Body & UI (Korean-first)                       | **Pretendard Variable**                                             | Apple SD Gothic Neo, Noto Sans KR |
| Display (headlines, onboarding, large numbers) | **Paperlogy** (Bold–ExtraBold)                                      | Pretendard 800                    |
| Latin & numerals                               | Pretendard's own Latin glyphs (do not mix in a separate Latin face) | —                                 |
| Timestamps, shortcuts, code                    | **JetBrains Mono**                                                  | SF Mono, Menlo                    |

Principle: Korean is read first, so no Latin-only display face is layered on top. Maximum two typefaces per screen.

### 3.2 Scale (base 16px)

| Token        | Size / line-height | Weight | Tracking | Usage                                               |
| ------------ | ------------------ | ------ | -------- | --------------------------------------------------- |
| `display-xl` | 40 / 48            | 800    | -0.02em  | Onboarding headline                                 |
| `display-lg` | 28 / 36            | 700    | -0.015em | Screen titles                                       |
| `title`      | 20 / 28            | 600    | -0.01em  | Section titles, sheet headers                       |
| `body-lg`    | 18 / 30            | 400    | 0        | **Transcript body** — the most important text style |
| `body`       | 16 / 26            | 400    | 0        | General UI text                                     |
| `label`      | 14 / 20            | 500    | 0        | Buttons, form labels                                |
| `caption`    | 12 / 16            | 500    | 0.01em   | Metadata, timestamps                                |

Transcript text uses generous line-height (1.65–1.7). Korean body text — especially transcribed speech — needs room to breathe to stay readable.

---

## 4. Shape & Material

### 4.1 Corner radius — "pebble curvature"

| Token             | Value                     | Usage                                  |
| ----------------- | ------------------------- | -------------------------------------- |
| `--radius-pebble` | `40%` or `min(48px, 45%)` | Icons, avatars, FAB, status indicators |
| `--radius-xl`     | 28px                      | Cards, bottom sheets, modals           |
| `--radius-lg`     | 20px                      | Large buttons, input fields            |
| `--radius-md`     | 14px                      | Chips, tags, small buttons             |
| `--radius-sm`     | 8px                       | Tooltips, inline code                  |

Rules:

- Use 40–45% instead of a full 50% circle. A slightly pressed pebble is this system's form language.
- Larger elements get larger curvature. A small chip must never be rounder than a card.
- No right angles (0px) anywhere. Even dividers have rounded ends (`stroke-linecap: round`).

### 4.2 Material — matte ceramic + translucent glass

Only two materials exist.

**Ceramic (default)** — opaque, matte, soft top highlight

```css
.ceramic {
  background: var(--bg-surface);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.06),
    /* top highlight */ 0 12px 32px -8px var(--shadow); /* soft downward shadow */
}
```

**Glass (accents only)** — translucent, lavender/pink tinted, background faintly visible

```css
.glass {
  background: color-mix(in srgb, var(--lavender) 22%, transparent);
  backdrop-filter: blur(20px) saturate(120%);
  border: 1px solid rgba(255, 255, 255, 0.1);
}
```

Rules:

- One or two glass elements per screen at most — the recording control, an active-state card.
- The light source is always **top-left**. Shadows fall bottom-right. Never mix directions.
- No gradients on surfaces. Color variation comes only from lighting (highlight/shadow).

### 4.3 Elevation

| Level | Shadow                                    | Usage                       |
| ----- | ----------------------------------------- | --------------------------- |
| 0     | none                                      | Background, inline elements |
| 1     | `0 4px 12px -4px var(--shadow)`           | Cards (resting)             |
| 2     | `0 12px 32px -8px var(--shadow)`          | Cards (hover), sheets       |
| 3     | `0 24px 56px -12px var(--shadow)` + glass | Recording control, modals   |

---

## 5. Signature — the cursor glow

The vertical glowing line in the icon is this app's identity. Across the whole system it remains **the single luminous element**.

```css
.cursor-glow {
  width: 3px;
  border-radius: 2px;
  background: var(--cursor-glow);
  box-shadow:
    0 0 6px var(--cursor-glow),
    0 0 18px color-mix(in srgb, var(--cursor-glow) 50%, transparent);
}
```

**Behavior by state**

| State        | Cursor                                                                 |
| ------------ | ---------------------------------------------------------------------- |
| Idle         | Not shown                                                              |
| Listening    | Breathes gently on a 1.6s cycle (opacity 0.6 ↔ 1.0); shape stays fixed |
| Transcribing | Steady glow at the end of the text, nudged 4px as each character lands |
| Paused       | Opacity 0.35, glow removed                                             |
| Error        | Glow shifts to `--pink`, shakes once, then fades out                   |

Forbidden: never reuse this glow for focus rings, notification badges, or loading spinners.

---

## 6. Spacing & Layout

Base unit 4px. Working tokens:

`4 · 8 · 12 · 16 · 24 · 32 · 48 · 64`

- Card inner padding: 24px (mobile 20px)
- Gap inside a pebble cluster: 8–12px — elements should feel like they **lean on each other**. Beyond 16px the rhythm breaks.
- Section spacing: 48px
- Horizontal margins: mobile 20px; desktop max-width 720px, centered (transcript lines should not exceed ~40–50 Korean characters)

**Cluster layout principle (taken from the icon)**

```
   ╭────╮  ╭──╮
   │ big│  ╰──╯      ← elements of different sizes form one unit
   │    │ ╭────╮
   ╰────╯ ╰────╯
  ╭──────────────╮   ← a base bar underneath anchors the center of gravity
  ╰──────────────╯
```

In dashboards and lists, prefer sizing elements by importance and grounding them with a stable bottom bar (summary, controls) over spreading them across an even grid.

---

## 7. Components

### 7.1 Buttons

| Type                          | Background                    | Text         | Radius            | Height |
| ----------------------------- | ----------------------------- | ------------ | ----------------- | ------ |
| Primary                       | `--pearl` (ceramic)           | `--bg-base`  | `--radius-lg`     | 52px   |
| Secondary                     | `--bg-surface-raised`         | `--pearl`    | `--radius-lg`     | 52px   |
| Accent (e.g. start recording) | Lavender glass                | `--pearl`    | `--radius-pebble` | 64px   |
| Ghost                         | Transparent                   | `--lavender` | `--radius-md`     | 44px   |
| Danger                        | Transparent + `--pink` border | `#D98B9A`    | `--radius-lg`     | 52px   |

States: hover lifts 1px and raises elevation one level. Pressed scales to 0.97 and drops the shadow. Focus ring is `--lavender` 2px with 3px offset.

### 7.2 Cards

Ceramic material, `--radius-xl`, elevation 1. Title uses `title`, body uses `body`. Never nest a card inside a card.

### 7.3 Recording control (core component)

Fixed to the bottom. One large glass pebble (64px) with a small ceramic pebble overlapping its top-left as a status indicator. When active, the cursor glow sits at the center of the large pebble.

No waveform is drawn. Input level is shown only through **subtle size changes** (scale 0.96–1.04) of three or four pebbles.

### 7.4 Transcript view

- `body-lg`, line-height 1.65
- Committed text: `--pearl`
- Tentative (not yet committed) text: `--pearl-muted`, with the cursor glow at the end
- Paragraphs separated by whitespace only (24px). No dividers.
- Timestamps in `caption` + JetBrains Mono, in the left margin, `--pearl-muted`

### 7.5 Input fields

Ceramic, `--radius-lg`, height 52px, inner padding 16px. Focus border `--lavender` 1.5px. Placeholder `--pearl-muted`.

### 7.6 Chips & tags

`--radius-md`, height 32px. Default `--bg-surface-raised`; selected state uses lavender glass.

### 7.7 Toasts & notifications

Ceramic pebble shape (`--radius-pebble`), bottom center. Text only, no icons. Sinks downward and fades after 3 seconds.

### 7.8 Empty states

An illustration of three loosely placed pebbles + one sentence + one action. Guide the next action rather than express emotion — no "nothing here yet" sentiment.

---

## 8. Iconography

- Line icons, 1.75px stroke, rounded caps, 24px grid
- Rounded outer forms (Lucide-style recommended; add corner radius where needed)
- Filled icons only for active states
- When extending the app icon family: keep the 2–4 pebbles + base bar structure; the silhouette must read at 32px

---

## 9. Motion

- Default easing: `cubic-bezier(0.2, 0.8, 0.2, 1)` — starts with weight, settles softly (the mass of ceramic)
- Durations: micro-interactions 160ms / transitions 280ms / sheet entrance 380ms
- Entrances move up 8px with a fade. No bounce.
- Pebble elements enter with scale 0.92 → 1.0, as if being set down
- Under `prefers-reduced-motion`, remove all motion except the cursor breathing

---

## 10. Voice & Copy

Korean is the primary UI language. Rules below apply to Korean copy; examples are kept in Korean because the tone is the spec.

- Polite declarative register (존댓말 평서형), kept short. Prefer "듣고 있어요" over "녹음을 시작합니다".
- Action buttons state the result, and the name carries through the flow: button "저장" → completion toast "저장했어요".
- No exposed technical terms: say "받아쓰기" and "정확도", not "STT" or "인식률".
- Errors give the cause plus the next action: "마이크 권한이 꺼져 있어요. 설정에서 켜주세요."
- No exclamation marks. No emoji.
- For any English UI strings, mirror the same register: short, sentence case, active voice ("Listening", "Saved").

---

## 11. Accessibility

- Text contrast: `--pearl` on `--bg-surface` ≈ 11:1; `--pearl-muted` on `--bg-surface` ≈ 6:1 (AA or better)
- Lavender text only at 16px and above
- The cursor glow must never be the sole carrier of information — always pair it with a text state ("듣고 있어요")
- Minimum touch target 44px
- Focus visibility always preserved

---

## 12. Do / Don't

**Do**

- Arrange elements in clusters with a base bar underneath
- Allow luminosity on the cursor only
- Build depth with lighting (highlight/shadow), not color
- Give Korean body text generous line-height

**Don't**

- Use waveforms, microphones, speech bubbles, or Hangul glyphs as decoration
- Put gradients on surfaces
- Use neon, fluorescent, or high-saturation accents
- Use perfect circles or right-angle corners
- Place three or more glass elements on one screen

---

## 13. Source reference

App icon generation prompt (the origin of this system):

> Abstract composition inspired by the balanced rhythm of Korean syllable blocks: a small set of rounded geometric forms gently align into one flowing, intelligent symbol. Fragments of sound becoming organized language, with a subtle vertical glow that implies a typing cursor. Modern Korean digital craft, minimal geometric sculpture, premium matte ceramic with translucent glass accents, calm and warm rather than futuristic. Palette: deep plum-indigo, muted lavender, powder pink, pearl white.

When uploading to Claude Design, attach this file together with the icon PNG and open with: "Build a design system that follows this DESIGN.md exactly. The icon is the reference for form and material."
