# gzen-architect

The blueprint for **[Architect — architect.gzen.io](https://architect.gzen.io)**, a senior architect's notebook on Azure, AI, and modern cloud systems.

A **[GZen](https://gzen.io)** product, built by **[Divineforge Technology Enterprise](https://divineforge.com)**.

---

## Design Decisions

### 1. Static Site with Hugo
The site is built with [Hugo](https://gohugo.io/) — a Go-based static site generator. All content is written in Markdown with YAML frontmatter. Hugo builds the site in under 100 ms and the output is deployed to GitHub Pages with zero server-side infrastructure.

### 2. Mobile-First CSS
All styles are written **mobile-first**: base styles target small screens, and `@media (min-width: ...)` breakpoints layer on progressive enhancements for tablet and desktop. Font sizes are in `rem` units relative to the root `16px` baseline, ensuring consistent scaling across devices and respecting user browser preferences.

Key breakpoints:
- `min-width: 640px` — tablet / landscape phone
- `min-width: 860px` — desktop (max content width)

### 3. Tag-Based Navigation
Navigation is driven by **tags** rather than sections. Instead of rigid category buckets (Learn / Patterns / Systems), users can navigate by topic (`#azure`, `#ai`, `#architecture`, `#mongodb`). This reflects how architects actually think — across domains, not within silos.

The mobile hamburger drawer keeps the nav clean on small screens while exposing the full tag set on desktop.

### 4. Client-Side Search
Search is implemented **without a backend** using Hugo's JSON output format:
- `index.json` is generated at build time, containing title, URL, summary, tags, and section for every page.
- The `/search/` page fetches this index in the browser and runs lightweight full-text matching using keyword tokenisation.
- Supports `?q=` URL parameters for shareable search links.
- Summaries are sanitised with Hugo's `plainify` filter before indexing to prevent XSS.
- Input is debounced (200 ms) for performance.

### 5. Solutions over Systems
The `systems/` section was renamed to `solutions/` to better reflect the purpose: real-world, end-to-end architecture solutions rather than abstract system diagrams.

### 6. Favicon — 巨 (GZen)
The favicon uses the Chinese character **巨** (jù — "giant, enormous"), the root character of GZen, rendered in white on the GZen blue (`#2563eb`) as an SVG. SVG favicons are supported by all modern browsers and scale perfectly at any resolution.

### 7. Diagram Shortcode
Diagrams are embedded via a Hugo shortcode (`{{< diagram >}}`) rather than raw HTML. This keeps Markdown files clean and avoids enabling global unsafe HTML rendering in the Goldmark parser.

---

## Content Structure

```
content/
├── articles/        # 30-day architecture series (Azure, AI, cloud)
├── solutions/       # Real-world end-to-end architecture solutions
├── patterns/        # Reusable architecture patterns (legacy section)
├── learn/           # Curated learning paths (legacy section)
└── _index.md        # Homepage content
```

---

## Development

```bash
# Install Hugo extended ≥ 0.147.7
# https://gohugo.io/installation/

# Serve locally with live reload
hugo server

# Production build
hugo --minify
```

Output goes to `public/` (excluded from git). Deployed automatically via GitHub Actions on push to `main`.

---

## Adding Articles

```bash
bash scripts/new-article.sh "Your Article Title"
```

Or create manually in `content/articles/` with frontmatter:

```yaml
---
title: "Article Title"
date: "YYYY-MM-DD"
summary: "One-sentence summary."
tags: ["azure", "architecture", "cloud"]
---
```
