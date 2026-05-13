#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Kinn Coelho Juliao <kinncj@protonmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
"""Generate assets/logo.svg as one filled <rect> per non-space cell.

Re-run after changing the ASCII art in install.sh's TUI:

    python3 assets/gen-logo.py assets/logo.svg

Why rects and not <text>: GitHub's markdown renderer adds line-height inside
code fences, and even in pure <svg><text>, the block character (█) has no
descender so rows don't actually touch. Emitting one filled rect per
non-space cell sidesteps the font entirely.
"""
import sys

CW, CH = 12, 16   # cell width/height
PAD = 8           # outer padding

LINES = [
    ' ██╗  ██╗██╗███╗   ██╗███╗   ██╗ ██████╗     ██╗',
    ' ██║ ██╔╝██║████╗  ██║████╗  ██║██╔════╝     ██║',
    ' █████╔╝ ██║██╔██╗ ██║██╔██╗ ██║██║          ██║',
    ' ██╔═██╗ ██║██║╚██╗██║██║╚██╗██║██║     ██   ██║',
    ' ██║  ██╗██║██║ ╚████║██║ ╚████║╚██████╗╚█████╔╝',
    ' ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═══╝ ╚═════╝ ╚════╝ ',
]

cols = max(len(line) for line in LINES)
rows = len(LINES)
W = cols * CW + PAD * 2
H = rows * CH + PAD * 2 + 28  # extra for tagline

out = sys.argv[1]
with open(out, 'w', encoding='utf-8') as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
    f.write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
            'role="img" aria-label="kinncj statusline">\n')
    f.write('  <title>kinncj statusline</title>\n')
    f.write('  <g fill="#5FD7D7" shape-rendering="crispEdges">\n')
    for row, line in enumerate(LINES):
        y = row * CH + PAD
        for col, ch in enumerate(line):
            if ch != ' ':
                x = col * CW + PAD
                f.write(f'    <rect x="{x}" y="{y}" width="{CW}" height="{CH}"/>\n')
    f.write('  </g>\n')
    tag_y = rows * CH + PAD + 20
    f.write(f'  <text x="{W//2}" y="{tag_y}" '
            'font-family="ui-monospace, \'JetBrains Mono\', Menlo, Consolas, monospace" '
            'font-size="13" fill="#888" letter-spacing="3" '
            'text-anchor="middle">s · t · a · t · u · s · l · i · n · e</text>\n')
    f.write('</svg>\n')
print(f"wrote {out}: {W}x{H}, {sum(c != ' ' for ln in LINES for c in ln)} rects")
