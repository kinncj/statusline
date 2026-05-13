// SPDX-FileCopyrightText: 2026 Kinn Coelho Juliao <kinncj@protonmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// kinncj-statusline — Pi extension (shell bridge).
//
// Renders the repo's statusline.sh inside Pi by feeding it a Claude-shaped
// JSON payload and piping the result into a widget under the editor.
//
// We deliberately do NOT replace Pi's native footer — Pi has its own rich
// footer (cwd · branch · token/burn stats · model). Our line sits as a
// separate two-line widget below the editor so users see both: Pi's native
// info plus the cross-host statusline they're used to from Claude Code /
// Copilot CLI.
//
// Pi discovers this file automatically from ~/.pi/agent/extensions/.

import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const STATUSLINE = path.join(HERE, "statusline.sh");
const WIDGET_KEY = "kinncj-statusline";

// Throttle refreshes — events can fire dozens of times per turn. A fresh
// render every 500ms is plenty for a wall-clock-driven line.
const REFRESH_DEBOUNCE_MS = 500;

export default function (pi) {
    let lastRender = 0;
    let scheduled = null;

    const renderNow = (ctx) => {
        lastRender = Date.now();
        scheduled = null;

        if (!ctx || !ctx.hasUI) return;

        const usage = typeof ctx.getContextUsage === "function" ? ctx.getContextUsage() : undefined;
        const modelName = ctx.model?.id ?? ctx.model?.name ?? "";

        const payload = {
            cwd: ctx.cwd ?? process.cwd(),
            model: { display_name: modelName },
            context_window: {
                used_percentage: usage?.percent ?? null,
                context_window_size: usage?.contextWindow ?? null,
                total_input_tokens: usage?.tokens ?? null,
                total_output_tokens: 0,
            },
        };

        let result;
        try {
            result = spawnSync(STATUSLINE, [], {
                input: JSON.stringify(payload),
                encoding: "utf8",
                timeout: 2000,
            });
        } catch {
            return;
        }
        if (!result || result.status !== 0 || !result.stdout) return;

        const lines = result.stdout.replace(/\n+$/, "").split("\n");
        try {
            ctx.ui.setWidget(WIDGET_KEY, lines, { placement: "belowEditor" });
        } catch {
            // Widget API not available in this mode (print/RPC) — fine, no-op.
        }
    };

    const refresh = (ctx) => {
        const delay = Math.max(0, REFRESH_DEBOUNCE_MS - (Date.now() - lastRender));
        if (scheduled) return;
        if (delay === 0) {
            renderNow(ctx);
        } else {
            scheduled = setTimeout(() => renderNow(ctx), delay);
        }
    };

    // Render on session boundaries and after each agent/tool turn so token
    // counts and model changes propagate. Event handlers receive ExtensionContext.
    pi.on("session_start", refresh);
    pi.on("turn_end", refresh);
    pi.on("agent_end", refresh);
    pi.on("tool_execution_end", refresh);
    pi.on("model_select", refresh);

    pi.on("session_shutdown", (ctx) => {
        if (scheduled) {
            clearTimeout(scheduled);
            scheduled = null;
        }
        try {
            ctx.ui.setWidget(WIDGET_KEY, undefined);
        } catch {
            // Ignore.
        }
    });
}
