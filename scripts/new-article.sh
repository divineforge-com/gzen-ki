#!/usr/bin/env bash
# Usage: ./scripts/new-article.sh "My Article Title"
set -euo pipefail

TITLE="${1:-New Article}"
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
DATE=$(date +%Y-%m-%d)
FILE="content/articles/${DATE}-${SLUG}.md"

cat > "$FILE" << FRONTMATTER
---
title: "${TITLE}"
date: "${DATE}"
summary: "TL;DR — one sentence summary."
tags: [azure, architecture, cloud]
---

## TL;DR

One-paragraph synthesis.

## Context

What problem does this solve? Why does it matter?

## Architecture / Design

Explain the design decisions and components.

## Diagram

![${TITLE} Architecture](/diagrams/${SLUG}-architecture.png)

## Key Insights

- Insight 1
- Insight 2
- Insight 3

## Trade-offs

| Approach | Pros | Cons |
|----------|------|------|
| Option A | ... | ... |
| Option B | ... | ... |

## References

- [Microsoft Learn](https://learn.microsoft.com)
FRONTMATTER

echo "Created: $FILE"
