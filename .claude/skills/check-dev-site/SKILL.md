---
name: check-dev-site
description: Open the dev Evidence site in Chrome and visually verify a change (layout, styling, new page/component). Use whenever the user says "проверь на dev", "засинкал, проверь", or otherwise asks to confirm a frontend change is live and looks right. Read-only browsing — never syncs files there itself.
---

Visual QA for Chronica's dev Evidence instance, using `claude-in-chrome` browser automation.
This skill only looks — it never edits site files or syncs anything to `loki` (see
[[feedback_no_self_sync]] memory: the user syncs `evidence/` changes to `dev.chronica`
themselves after Claude edits local files; only sync if the user explicitly says to do it
this time).

## Prerequisites

- The user has already synced their local edit to `dev.chronica` on `loki` (or explicitly
  asked you to sync it yourself this one time). If they haven't said so, ask first —
  don't assume a local edit is already live.
- Chrome tools are deferred; load them before use:
  `ToolSearch("select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__computer,mcp__claude-in-chrome__resize_window,mcp__claude-in-chrome__tabs_create_mcp,mcp__claude-in-chrome__tabs_close_mcp")`

## URL

`http://192.168.1.15:33001` — see [[reference_dev_evidence_url]]. Not `dev.chronica.life`
(no working vhost for it). LAN-only, reachable from wherever this session's Chrome runs.

## Site is mobile-first — pick your viewport deliberately

The layout (`evidence/pages/+layout.svelte`) shows completely different UI depending on
viewport width, via a pure-CSS gate at `@media (min-width: 900px) and (pointer: fine)`:

- **< 900px wide** (or no fine pointer) → the real mobile UI: bottom tab bar (Главная /
  Сюжеты / Поддержка / Профиль), actual page content.
- **≥ 900px wide** → a desktop "business card" gate overlay (`.c-desktop-gate`) covering
  the whole viewport: logo, tagline, a single "Открыть в Telegram →" CTA, a ticker. The
  real page underneath is hidden. Only useful for checking that specific gate's own
  styling — not for verifying anything about the underlying page.

Resize *before* navigating, or navigate again after resizing (`resize_window` doesn't
reliably trigger a CSS re-layout notification on its own):

```
resize_window(width: 420, height: 800, tabId)   # mobile UI
resize_window(width: 1400, height: 800, tabId)  # desktop gate
navigate(url: "http://192.168.1.15:33001", tabId)
```

If the change under test lives on a specific page (not the home gate), navigate straight
to it, e.g. `http://192.168.1.15:33001/stories`.

## Verifying a change actually landed

Evidence dev (`:33001`) hot-reloads on file change, but the browser can still serve a
stale cached copy. If a screenshot doesn't reflect an edit you know was just synced, hard
reload before concluding something is wrong:

```
computer(action: "key", text: "cmd+shift+r", tabId)
```

If it *still* doesn't match after a hard reload, don't guess — confirm the file actually
landed on disk before assuming the CSS/markup is wrong:

```
ssh loki "grep -n '<snippet>' /media/data/projects/dev.chronica/evidence/pages/<file>"
```
(paths under `dev.chronica`, per [[reference_dev_evidence_url]] — this is inspection only,
not a sync).

## Inspecting the result

- `computer(action: "screenshot", tabId)` for the full-viewport view.
- `computer(action: "zoom", region: [x0,y0,x1,y1], tabId)` to inspect one element closely
  (e.g. confirm a `border-radius` value visually, not just by reading the CSS) — get pixel
  coordinates from the plain screenshot first.

## Cleanup

Close any tab you created for the check: `tabs_close_mcp(tabId)`. Leave it open only if
the user asked to keep it open.