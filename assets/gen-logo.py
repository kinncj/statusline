#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Kinn Coelho Juliao <kinncj@protonmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
"""Generate assets/ascii_logo.svg from the ANSI Shadow block-letter art.

Each character is mapped to a list of (x, y, w, h) sub-rectangles
expressed in a per-cell coordinate system (0..CW × 0..CH). Full blocks
fill the cell; box-drawing characters render as their actual visual
shape (double horizontal/vertical lines for ═ and ║; L-shaped corner
strokes for ╔ ╗ ╚ ╝). This is what makes the rendered output read as
"retro terminal" and not as Minecraft voxels.

We also overlap rects by 1 unit on each side so any anti-aliasing in
the rasterizer can't insert visible gaps between adjacent cells.

Run after changing the art in installers/_tui.sh:

    python3 assets/gen-logo.py assets/ascii_logo.svg
"""
import sys

# Cell size in SVG user units. Bigger == crisper at common README widths.
CW, CH = 18, 24
PAD = 12
FILL = "#5FD7D7"   # cyan that reads as terminal-glow on both light/dark GH

# Lines from installers/_tui.sh _LOGO_LINES (kept in sync by hand).
LINES = [
    ' ██╗  ██╗██╗███╗   ██╗███╗   ██╗ ██████╗     ██╗',
    ' ██║ ██╔╝██║████╗  ██║████╗  ██║██╔════╝     ██║',
    ' █████╔╝ ██║██╔██╗ ██║██╔██╗ ██║██║          ██║',
    ' ██╔═██╗ ██║██║╚██╗██║██║╚██╗██║██║     ██   ██║',
    ' ██║  ██╗██║██║ ╚████║██║ ╚████║╚██████╗╚█████╔╝',
    ' ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═══╝ ╚═════╝ ╚════╝ ',
]
TAGLINE = "s · t · a · t · u · s · l · i · n · e"

# Stroke geometry for box-drawing characters. These are sized to look
# coherent next to a full block — thick enough to read clearly at 16px
# but thin enough that ═ / ║ are visually distinct from █.
SH_OUTER = 3           # outer-line thickness (the "double" effect)
SH_INNER = 3           # inner-line thickness
GAP      = 2           # spacing between the two lines of ═ / ║

# Pre-computed positions inside a cell. Adjusted so the corners and
# straight lines join up cleanly.
H1_Y = (CH - (SH_OUTER + GAP + SH_INNER)) // 2          # upper bar of ═
H2_Y = H1_Y + SH_OUTER + GAP                            # lower bar of ═
V1_X = (CW - (SH_OUTER + GAP + SH_INNER)) // 2          # left bar of ║
V2_X = V1_X + SH_OUTER + GAP                            # right bar of ║

def cell_shapes(ch):
    """Return list of (x, y, w, h) rects for one cell character."""
    if ch == '█':
        return [(0, 0, CW, CH)]
    if ch == '═':
        return [(0, H1_Y, CW, SH_OUTER),
                (0, H2_Y, CW, SH_INNER)]
    if ch == '║':
        return [(V1_X, 0, SH_OUTER, CH),
                (V2_X, 0, SH_INNER, CH)]
    # ╔ — corner: horizontal-RIGHT + vertical-DOWN
    if ch == '╔':
        return [(V1_X, H1_Y, CW - V1_X, SH_OUTER),     # outer ─
                (V1_X, H1_Y, SH_OUTER, CH - H1_Y),     # outer │
                (V2_X, H2_Y, CW - V2_X, SH_INNER),     # inner ─
                (V2_X, H2_Y, SH_INNER, CH - H2_Y)]     # inner │
    # ╗ — corner: horizontal-LEFT + vertical-DOWN
    if ch == '╗':
        return [(0,    H1_Y, V2_X + SH_INNER, SH_OUTER),
                (V2_X, H1_Y, SH_INNER, CH - H1_Y),
                (0,    H2_Y, V1_X + SH_OUTER, SH_INNER),
                (V1_X, H2_Y, SH_OUTER, CH - H2_Y)]
    # ╚ — corner: horizontal-RIGHT + vertical-UP
    if ch == '╚':
        return [(V1_X, H2_Y, CW - V1_X, SH_INNER),
                (V1_X, 0,    SH_OUTER, H2_Y + SH_INNER),
                (V2_X, H1_Y, CW - V2_X, SH_OUTER),
                (V2_X, 0,    SH_INNER, H1_Y + SH_OUTER)]
    # ╝ — corner: horizontal-LEFT + vertical-UP
    if ch == '╝':
        return [(0,    H2_Y, V2_X + SH_INNER, SH_INNER),
                (V2_X, 0,    SH_INNER, H2_Y + SH_INNER),
                (0,    H1_Y, V1_X + SH_OUTER, SH_OUTER),
                (V1_X, 0,    SH_OUTER, H1_Y + SH_OUTER)]
    return []  # space or unknown


def main():
    out = sys.argv[1]
    cols = max(len(line) for line in LINES)
    rows = len(LINES)
    W = cols * CW + PAD * 2
    H = rows * CH + PAD * 2 + 36   # extra for tagline

    with open(out, 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" '
                f'viewBox="0 0 {W} {H}" '
                f'role="img" aria-label="kinncj statusline">\n')
        f.write('  <title>kinncj statusline</title>\n')
        f.write(f'  <g fill="{FILL}" shape-rendering="crispEdges">\n')

        rects = 0
        for row, line in enumerate(LINES):
            for col, ch in enumerate(line):
                for (dx, dy, w, h) in cell_shapes(ch):
                    x = col * CW + PAD + dx
                    y = row * CH + PAD + dy
                    f.write(f'    <rect x="{x}" y="{y}" '
                            f'width="{w}" height="{h}"/>\n')
                    rects += 1

        f.write('  </g>\n')

        # Tagline below the block art.
        tag_y = rows * CH + PAD + 28
        f.write(f'  <text x="{W//2}" y="{tag_y}" '
                f'font-family="ui-monospace, \'JetBrains Mono\', Menlo, Consolas, monospace" '
                f'font-size="16" fill="#888" letter-spacing="2" '
                f'text-anchor="middle">{TAGLINE}</text>\n')
        f.write('</svg>\n')

    print(f"wrote {out}: {W}x{H}, {rects} rects across {cols}x{rows} cells")


if __name__ == '__main__':
    main()
