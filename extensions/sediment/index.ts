import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import * as fs from "node:fs";
import * as path from "node:path";

export default function (pi: ExtensionAPI) {
  const home = process.env.HOME!;
  const configPath = path.join(home, ".sediment/config.json");
  const sessionsDir = path.join(home, ".sediment/sessions");
  const scriptsDir = path.join(home, ".sediment/scripts");

  function readConfig(): { vault_path: string } | null {
    try {
      return JSON.parse(fs.readFileSync(configPath, "utf-8"));
    } catch {
      return null;
    }
  }

  // --- Confidence decay + pending distillation at session start ---
  pi.on("session_start", async (_event, ctx) => {
    // Run decay script
    const decayScript = path.join(scriptsDir, "sediment-decay.sh");
    if (fs.existsSync(decayScript)) {
      await pi.exec("bash", [decayScript], { timeout: 10000 });
    }

    // Check for pending distillation from previous session
    const pendingPath = path.join(sessionsDir, "pending.json");
    if (fs.existsSync(pendingPath)) {
      try {
        const pending = JSON.parse(fs.readFileSync(pendingPath, "utf-8"));
        fs.unlinkSync(pendingPath);

        const config = readConfig();
        if (config) {
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
        }
      } catch {
        // If pending file is corrupt, just remove it
        try {
          fs.unlinkSync(pendingPath);
        } catch {}
      }
    }
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

  // --- Mark session for distillation on shutdown ---
  pi.on("session_shutdown", async (_event, ctx) => {
    const config = readConfig();
    if (!config) return;

    // Only mark if session had meaningful work (3+ assistant messages)
    const entries = ctx.sessionManager.getEntries();
    const assistantCount = entries.filter(
      (e: any) => e.type === "message" && e.message?.role === "assistant"
    ).length;
    if (assistantCount < 3) return;

    const sessionFile = ctx.sessionManager.getSessionFile();
    if (!sessionFile) return;

    fs.mkdirSync(sessionsDir, { recursive: true });
    fs.writeFileSync(
      path.join(sessionsDir, "pending.json"),
      JSON.stringify({
        sessionFile,
        timestamp: Date.now(),
      })
    );
  });
}
