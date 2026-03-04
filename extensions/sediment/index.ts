import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import * as fs from "node:fs";
import * as path from "node:path";

export default function (pi: ExtensionAPI) {
  const home = process.env.HOME!;
  const configPath = path.join(home, ".sediment/config.json");
  const sessionsDir = path.join(home, ".sediment/sessions");
  const scriptsDir = path.join(home, ".sediment/scripts");
  const pendingPath = path.join(sessionsDir, "pending.json");

  function readConfig(): { vault_path: string } | null {
    try {
      return JSON.parse(fs.readFileSync(configPath, "utf-8"));
    } catch {
      return null;
    }
  }

  /** Process pending.json and trigger distillation if found. */
  function processPending(): void {
    if (!fs.existsSync(pendingPath)) return;

    try {
      const pending = JSON.parse(fs.readFileSync(pendingPath, "utf-8"));
      fs.unlinkSync(pendingPath);

      const config = readConfig();
      if (!config) return;

      const sessionHint = pending.sessionFile
        ? ` The previous session file is at ${pending.sessionFile} if you need to review it.`
        : "";
      pi.sendUserMessage(
        `A previous coding session ended without distillation.` +
          sessionHint +
          ` Follow the sediment-writer skill to distill it.` +
          ` Evaluate whether any decisions, patterns, gotchas, context, or progress are worth capturing.` +
          ` If nothing meaningful, say so and move on.` +
          ` Write any notes to ${config.vault_path}/00-Inbox/.`
      );
    } catch {
      try {
        fs.unlinkSync(pendingPath);
      } catch {}
    }
  }

  /**
   * Write pending.json for the current session. Called from both
   * session_shutdown (exit) and session_before_switch (/new).
   */
  function markPending(
    entries: any[],
    sessionFile: string | undefined
  ): void {
    const assistantCount = entries.filter(
      (e: any) => e.type === "message" && e.message?.role === "assistant"
    ).length;
    if (assistantCount < 3) return;
    if (!sessionFile) return;

    fs.mkdirSync(sessionsDir, { recursive: true });
    fs.writeFileSync(
      pendingPath,
      JSON.stringify({ sessionFile, timestamp: Date.now() })
    );
  }

  // --- Confidence decay + pending distillation at session start ---
  pi.on("session_start", async (_event, _ctx) => {
    const decayScript = path.join(scriptsDir, "sediment-decay.sh");
    if (fs.existsSync(decayScript)) {
      await pi.exec("bash", [decayScript], { timeout: 10000 });
    }

    processPending();
  });

  // --- Context injection before each agent turn ---
  pi.on("before_agent_start", async (event, ctx) => {
    const contextScript = path.join(scriptsDir, "sediment-context.sh");
    if (!fs.existsSync(contextScript)) return;

    const result = await pi.exec("bash", [contextScript, ctx.cwd], {
      timeout: 10000,
    });
    if (result.code === 0 && result.stdout.trim()) {
      return {
        systemPrompt: event.systemPrompt + "\n\n" + result.stdout.trim(),
      };
    }
  });

  // --- Distill after compaction ---
  // Compaction compresses detailed context into a summary. Trigger
  // distillation immediately so knowledge is captured while the
  // compaction summary is still fresh.
  pi.on("session_compact", async (_event, _ctx) => {
    const config = readConfig();
    if (!config) return;

    pi.sendUserMessage(
      `A compaction just occurred, compressing the previous conversation context.` +
        ` Follow the sediment-writer skill to distill any important knowledge from this session so far.` +
        ` Focus on the compaction summary for decisions, patterns, gotchas, or context worth capturing.` +
        ` If nothing meaningful, say so and move on.` +
        ` Write any notes to ${config.vault_path}/00-Inbox/.`
    );
  });

  // --- Save pending before /new ---
  // session_shutdown does NOT fire on /new, so we catch it here.
  pi.on("session_before_switch", async (event, ctx) => {
    if ((event as any).reason !== "new") return;

    const config = readConfig();
    if (!config) return;

    markPending(
      ctx.sessionManager.getEntries(),
      ctx.sessionManager.getSessionFile() ?? undefined
    );
  });

  // --- Distill pending after /new ---
  // session_start only fires once at process startup. After /new we
  // need to process pending.json ourselves.
  pi.on("session_switch", async (event, _ctx) => {
    if ((event as any).reason !== "new") return;
    processPending();
  });

  // --- Mark session for distillation on shutdown ---
  pi.on("session_shutdown", async (_event, ctx) => {
    const config = readConfig();
    if (!config) return;

    markPending(
      ctx.sessionManager.getEntries(),
      ctx.sessionManager.getSessionFile() ?? undefined
    );
  });
}
