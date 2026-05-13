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
import { appendFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const STATUSLINE = path.join(HERE, "statusline.sh");
const WIDGET_KEY = "kinncj-statusline";

// Opt-in debug log. Set PI_STATUSLINE_DEBUG=1 to write per-event records
// to /tmp/pi-statusline-debug.log. Useful when the widget doesn't appear
// and you need to see whether handlers fired, what ctx looked like, and
// whether setWidget threw.
const DEBUG = process.env.PI_STATUSLINE_DEBUG === "1";
const DBG_FILE = "/tmp/pi-statusline-debug.log";
const dbg = (msg) => {
    if (!DEBUG) return;
    try { appendFileSync(DBG_FILE, `${new Date().toISOString()} ${msg}\n`); } catch {}
};
dbg(`=== module loaded; STATUSLINE=${STATUSLINE} ===`);

// Throttle refreshes — events can fire dozens of times per turn. A fresh
// render every 500ms is plenty for a wall-clock-driven line.
const REFRESH_DEBOUNCE_MS = 500;

export default function (pi) {
    let lastRender = 0;
    let scheduled = null;

    const renderNow = (ctx) => {
        lastRender = Date.now();
        scheduled = null;

        if (!ctx) { dbg("renderNow: no ctx"); return; }
        dbg(`renderNow: hasUI=${ctx.hasUI} cwd=${ctx.cwd} model=${ctx.model?.id}`);
        if (!ctx.hasUI) return;

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
        } catch (e) {
            dbg(`renderNow: spawnSync threw: ${e?.message}`);
            return;
        }
        if (!result) { dbg("renderNow: spawnSync returned null"); return; }
        if (result.status !== 0) { dbg(`renderNow: status=${result.status} stderr=${result.stderr}`); return; }
        if (!result.stdout) { dbg("renderNow: empty stdout"); return; }

        const lines = result.stdout.replace(/\n+$/, "").split("\n");
        dbg(`renderNow: setWidget with ${lines.length} lines: ${JSON.stringify(lines[0]?.slice(0, 80))}`);
        try {
            ctx.ui.setWidget(WIDGET_KEY, lines, { placement: "belowEditor" });
            dbg("renderNow: setWidget OK");
        } catch (e) {
            dbg(`renderNow: setWidget threw: ${e?.message}`);
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

    // Pi's ExtensionHandler signature is `(event, ctx) => ...` — the ctx
    // is the SECOND argument, not the first. Wrap so refresh() gets ctx.
    const onEvent = (eventName) => (_event, ctx) => {
        dbg(`event: ${eventName}`);
        refresh(ctx);
    };

    pi.on("session_start", onEvent("session_start"));
    pi.on("turn_end", onEvent("turn_end"));
    pi.on("agent_end", onEvent("agent_end"));
    pi.on("tool_execution_end", onEvent("tool_execution_end"));
    pi.on("model_select", onEvent("model_select"));

    pi.on("session_shutdown", (_event, ctx) => {
        if (scheduled) {
            clearTimeout(scheduled);
            scheduled = null;
        }
        try {
            ctx?.ui?.setWidget(WIDGET_KEY, undefined);
        } catch {
            // Ignore.
        }
    });
}
