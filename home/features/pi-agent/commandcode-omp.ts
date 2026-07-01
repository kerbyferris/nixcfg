import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { EventEmitter } from "events";
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";

const API_BASE = "https://api.commandcode.ai";
const CLI_VERSION = "0.33.0";
const MODELS_URL = "https://api.commandcode.ai/provider/v1/models";

interface ModelEntry {
  id: string;
  name?: string;
  context?: number;
  maxOutput?: number;
  context_length?: number;
}

interface Usage {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  totalTokens: number;
  reasoningTokens?: number;
  cost: { total: number };
}

function defaultUsage(): Usage {
  return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { total: 0 } };
}

async function getApiKey(): Promise<string | undefined> {
  const envKey = process.env.COMMANDCODE_API_KEY;
  if (envKey) return envKey;
  const home = process.env.HOME;
  if (!home) return;
  for (const p of [`${home}/.commandcode/auth.json`, `${home}/.pi/agent/auth.json`]) {
    try {
      const content = readFileSync(p, "utf-8");
      const parsed = JSON.parse(content) as Record<string, unknown>;
      const key = parsed.apiKey ?? parsed.commandcode;
      if (typeof key === "string") return key;
    } catch {
      // try next
    }
  }
}

const FALLBACK_MODELS: ModelEntry[] = [
  { id: "deepseek/deepseek-v4-pro", context: 1048576, maxOutput: 393216 },
  { id: "deepseek/deepseek-v4-flash", context: 1048576, maxOutput: 16384 },
  { id: "claude-sonnet-4-6", context: 1000000, maxOutput: 64000 },
  { id: "codestral-latest", context: 256000, maxOutput: 4096 },
];

function makeStream() {
  const emitter = new EventEmitter();
  const queue: unknown[] = [];
  let ended = false;
  emitter.on("push", (e: unknown) => queue.push(e));
  emitter.on("end", () => {
    ended = true;
  });
  const stream = {
    push: (event: unknown) => {
      emitter.emit("push", event);
    },
    end: () => {
      emitter.emit("end");
    },
    [Symbol.asyncIterator]: () => ({
      next: async () => {
        while (!ended && queue.length === 0) {
          const { promise, resolve } = Promise.withResolvers<void>();
          setTimeout(resolve, 5);
          await promise;
        }
        if (queue.length > 0) return { value: queue.shift(), done: false };
        return { value: undefined, done: true };
      },
    }),
  };
  return stream;
}

export default async function (pi: ExtensionAPI) {
  let models: ModelEntry[] = FALLBACK_MODELS;
  try {
    const resp = await fetch(MODELS_URL, { headers: { accept: "application/json" } });
    if (resp.ok) {
      const data = (await resp.json()) as { data?: ModelEntry[] };
      if (data?.data) {
        models = data.data.map((m: ModelEntry) => ({
          id: m.id,
          name: m.name ?? m.id,
          context: m.context_length ?? 1000000,
          maxOutput: m.maxOutput ?? 64000,
        }));
      }
    }
  } catch {
    // use fallback
  }

  pi.registerProvider("commandcode", {
    name: "Command Code",
    baseUrl: API_BASE,
    apiKey: "$COMMANDCODE_API_KEY",
    authHeader: true,
    api: "commandcode-custom",
    streamSimple: function commandCodeStream(
      model: { id: string },
      messages: { messages?: unknown[] } | unknown[],
      options?: {
        apiKey?: string;
        signal?: AbortSignal;
        maxTokens?: number;
      },
    ) {
      const stream = makeStream();

      (async () => {
        const apiKey = (options?.apiKey && !options.apiKey.startsWith("$") ? options.apiKey : undefined) ?? (await getApiKey());
        const msgs = "messages" in messages ? messages.messages : (messages as unknown[]);

        if (!apiKey) {
          stream.push({
            type: "error",
            reason: "error",
            error: {
              role: "assistant",
              content: [],
              stopReason: "error",
              errorMessage:
                "No COMMANDCODE_API_KEY. Set env var or run /login.",
            },
          });
          stream.end();
          return;
        }

        try {
          const workingDir = process.cwd();
          const now = new Date();

          const body = {
            config: {
              workingDir,
              date: now.toISOString().split("T")[0],
              environment: process.env.NODE_ENV ?? "production",
              structure: [],
              isGitRepo: false,
              currentBranch: "",
              mainBranch: "",
              gitStatus: "",
              recentCommits: [],
            },
            memory: null,
            taste: null,
            skills: null,
            params: {
              model: model.id,
              messages: msgs,
              tools: [],
              system: "",
              max_tokens: options?.maxTokens ?? 64000,
              temperature: 0.3,
              stream: true,
            },
            threadId: randomUUID(),
          };

          const response = await fetch(`${API_BASE}/alpha/generate`, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${apiKey}`,
              "Content-Type": "application/json",
              "x-command-code-version": CLI_VERSION,
              "x-cli-environment": "production",
            },
            body: JSON.stringify(body),
            signal: options?.signal,
          });

          if (!response.ok) {
            const text = await response.text();
            stream.push({
              type: "error",
              reason: "error",
              error: {
                role: "assistant",
                content: [],
                stopReason: "error",
                errorMessage: `Command Code API error ${response.status}: ${text}`,
              },
            });
            stream.end();
            return;
          }

          const reader = response.body?.getReader();
          if (!reader) throw new Error("No response body");

          let buffer = "";
          const decoder = new TextDecoder();
          let contentIndex = 0;
          let fullContent = "";
          let usage: Usage = defaultUsage();
          let finished = false;

          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split("\n");
            buffer = lines.pop() ?? "";

            for (const line of lines) {
              const trimmed = line.trim();
              if (!trimmed) continue;
              try {
                const event = JSON.parse(trimmed) as { type: string; [key: string]: unknown };
                switch (event.type) {
                  case "text-delta": {
                    const text = typeof event.text === "string" ? event.text : "";
                    if (text) {
                      fullContent += text;
                      stream.push({
                        type: "text_delta",
                        contentIndex,
                        delta: text,
                        partial: {
                          role: "assistant",
                          content: [{ type: "text" as const, text: fullContent }],
                          stopReason: null,
                          usage,
                        },
                      });
                    }
                    break;
                  }
                  case "finish": {
                    const totalUsage = event.totalUsage as Record<string, unknown> | undefined;
                    if (totalUsage) {
                      usage = {
                        input: (totalUsage.inputTokens as number) ?? 0,
                        output: (totalUsage.outputTokens as number) ?? 0,
                        cacheRead: (
                          (totalUsage.inputTokenDetails as Record<string, unknown>)
                            ?.cacheReadTokens as number
                        ) ?? 0,
                        cacheWrite: (
                          (totalUsage.inputTokenDetails as Record<string, unknown>)
                            ?.cacheWriteTokens as number
                        ) ?? 0,
                        totalTokens: (totalUsage.totalTokens as number) ?? 0,
                        cost: { total: 0 },
                      };
                    }
                    finished = true;
                    break;
                  }
                  case "error": {
                    const errorRecord = event.error as Record<string, unknown> | undefined;
                    const errMsg =
                      (typeof errorRecord?.message === "string"
                        ? errorRecord.message
                        : undefined) ??
                      (typeof event.error === "string" ? event.error : undefined) ??
                      "Stream error";
                    throw new Error(errMsg);
                  }
                }
              } catch {
                // skip unparseable lines
              }
              if (finished) break;
            }
            if (finished) break;
          }

          const msg = {
            role: "assistant" as const,
            content: [{ type: "text" as const, text: fullContent }],
            stopReason: "stop" as const,
            usage,
          };
          stream.push({
            type: "text_end",
            contentIndex,
            content: fullContent,
            partial: msg,
          });
          stream.push({ type: "done", reason: "stop" as const, message: msg });
          stream.end();
        } catch (err: unknown) {
          if (err instanceof Error && err.name === "AbortError") {
            stream.push({
              type: "done",
              reason: "stop",
              message: {
                role: "assistant",
                content: [],
                stopReason: "stop",
              },
            });
          } else {
            const errMsg =
              err instanceof Error ? err.message : "Unknown error";
            stream.push({
              type: "error",
              reason: "error",
              error: {
                role: "assistant",
                content: [],
                stopReason: "error",
                errorMessage: errMsg,
              },
            });
          }
          stream.end();
        }
      })();
      return stream;
    },
    headers: {
      "x-command-code-version": CLI_VERSION,
      "x-cli-environment": "production",
    },
    models: models.map((m: ModelEntry) => ({
      id: m.id,
      name: m.name ?? m.id,
      context: m.context ?? 1000000,
      maxOutput: m.maxOutput ?? 64000,
    })),
  });
}
