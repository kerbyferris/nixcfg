/**
 * Hermes SSH — Communication bridge to the Pi agent.
 *
 * Provides opt-in SSH connectivity for reading/writing CONTEXT.md and
 * running bash commands on the Raspberry Pi where Hermes lives.
 *
 * Unlike the generic ssh.ts example, this extension:
 * - Defaults the SSH target to pi@work.kerbyandnaomi.com:/home/pi/work-os
 * - Does NOT proxy all file tools (read/write/edit stay local)
 * - Proxies bash so the agent can run commands on the Pi
 * - Registers /hermes command for quick context operations
 * - Activates only when `--hermes` flag is passed
 *
 * Usage:
 *   pi --hermes               # SSH with default target
 *   pi --hermes user@host     # SSH with custom target
 *   /hermes                   # Quick context read after flag is set
 */

import { spawn } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const DEFAULT_REMOTE = "pi@work.kerbyandnaomi.com";
const DEFAULT_REMOTE_PATH = "/home/pi/work-os";

function sshExec(remote: string, command: string): Promise<Buffer> {
  const { promise, resolve, reject } = Promise.withResolvers<Buffer>();
  const child = spawn("ssh", [remote, command], { stdio: ["ignore", "pipe", "pipe"] });
  const chunks: Buffer[] = [];
  const errChunks: Buffer[] = [];
  child.stdout.on("data", (data: Buffer) => chunks.push(data));
  child.stderr.on("data", (data: Buffer) => errChunks.push(data));
  child.on("error", reject);
  child.on("close", (code: number | null) => {
    if (code !== 0) {
      reject(new Error(`SSH failed (${code}): ${Buffer.concat(errChunks).toString()}`));
    } else {
      resolve(Buffer.concat(chunks));
    }
  });
  return promise;
}

function createRemoteBashOps(remote: string, remoteCwd: string) {
  return {
    exec: (
      command: string,
      cwd: string,
      opts: { onData?: (chunk: Buffer) => void; signal?: AbortSignal; timeout?: number },
    ) => {
      const { promise, resolve, reject } = Promise.withResolvers<{ exitCode: number | null }>();
      const cmd = `cd ${JSON.stringify(remoteCwd)} && ${command}`;
      const child = spawn("ssh", [remote, cmd], { stdio: ["ignore", "pipe", "pipe"] });
      let timedOut = false;
      const timer = opts.timeout
        ? setTimeout(() => {
            timedOut = true;
            child.kill();
          }, opts.timeout * 1000)
        : undefined;

      if (opts.onData) {
        child.stdout.on("data", opts.onData);
        child.stderr.on("data", opts.onData);
      }

      child.on("error", (e: Error) => {
        if (timer) clearTimeout(timer);
        reject(e);
      });

      const onAbort = () => child.kill();
      opts.signal?.addEventListener("abort", onAbort, { once: true });

      child.on("close", (code: number | null) => {
        if (timer) clearTimeout(timer);
        opts.signal?.removeEventListener("abort", onAbort);
        if (opts.signal?.aborted) reject(new Error("aborted"));
        else if (timedOut) reject(new Error(`timeout:${opts.timeout}`));
        else resolve({ exitCode: code });
      });

      return promise;
    },
  };
}

export default function (pi: ExtensionAPI) {
  let resolvedRemote: string | null = null;
  let resolvedRemoteCwd: string | null = null;

  pi.registerFlag("hermes", {
    description: "Enable Hermes SSH bridge. Optionally: user@host or user@host:/path",
    type: "string",
  });

  const getActive = () => resolvedRemote !== null;

  // Register /hermes command for quick context operations
  pi.registerCommand("hermes", {
    description: "Read Hermes context from the Pi. Usage: /hermes",
    handler: async (_args, ctx) => {
      if (!getActive()) {
        ctx.ui.notify("Hermes not connected. Start with: pi --hermes", "warning");
        return;
      }
      try {
        const remote = resolvedRemote!;
        const cwd = resolvedRemoteCwd!;
        const result = await sshExec(remote, `cat ${JSON.stringify(cwd + "/CONTEXT.md")}`);
        ctx.ui.notify("CONTEXT.md loaded from Pi", "info");
        // Display the content in the chat
        return result.toString();
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        ctx.ui.notify(`Failed to read CONTEXT.md: ${msg}`, "error");
      }
    },
  });

  // On session start, resolve the SSH target
  pi.on("session_start", async (_event, ctx) => {
    const arg = pi.getFlag("hermes") as string | undefined;
    if (arg !== undefined && arg !== "") {
      if (arg.includes(":")) {
        const [remote, path] = arg.split(":");
        resolvedRemote = remote;
        resolvedRemoteCwd = path;
      } else {
        resolvedRemote = arg;
        resolvedRemoteCwd = DEFAULT_REMOTE_PATH;
      }
    } else if (arg === "") {
      // Flag present but no value — use defaults
      resolvedRemote = DEFAULT_REMOTE;
      resolvedRemoteCwd = DEFAULT_REMOTE_PATH;
    }

    if (resolvedRemote) {
      // Verify connection
      try {
        const pwd = (await sshExec(resolvedRemote, "pwd")).toString().trim();
        ctx.ui.setStatus(
          "hermes",
          ctx.ui.theme.fg("accent", `Hermes: ${resolvedRemote}:${resolvedRemoteCwd}`),
        );
        ctx.ui.notify(`Hermes bridge active: ${resolvedRemote}:${resolvedRemoteCwd} (${pwd})`, "info");

        // Update system prompt so agent knows about the Pi
        return {
          systemPrompt: `\n\n## Hermes SSH Bridge Active\nRemote: ${resolvedRemote}\nRemote path: ${resolvedRemoteCwd}\nUse /hermes to read context, or bash commands with ssh:// for Pi operations.\n`,
        };
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        ctx.ui.notify(`Hermes SSH failed: ${msg} — check connectivity`, "error");
        resolvedRemote = null;
        resolvedRemoteCwd = null;
      }
    }
  });
}
