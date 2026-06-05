/**
 * Tavily Web Search — Web search via the Tavily API.
 *
 * Registers a `web_search` tool that the LLM can call to search the web
 * using Tavily's search API. Requires the TAVILY_API_KEY environment
 * variable to be set (managed via sops-nix at /run/secrets/agent-env).
 *
 * Usage:
 *   The LLM calls `web_search` automatically when it determines it needs
 *   up-to-date information from the web. No manual activation needed.
 */

import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const TAVILY_API_URL = "https://api.tavily.com/search";

interface TavilyResult {
  title: string;
  url: string;
  content: string;
  score?: number;
}

interface TavilyResponse {
  results: TavilyResult[];
  answer?: string;
  query: string;
  response_time: number;
}

export default function (pi: ExtensionAPI) {
  // Read API key from environment (sourced from /run/secrets/agent-env by zsh)
  const apiKey = process.env.TAVILY_API_KEY;
  if (!apiKey) {
    console.warn(
      "[tavily-web-search] TAVILY_API_KEY not set — web_search tool will fail at runtime. Set it via sops-nix at /run/secrets/agent-env.",
    );
  }

  pi.registerTool({
    name: "web_search",
    label: "Web Search",
    description:
      "Search the web for current information using Tavily. Use this to look up recent events, documentation, prices, news, or any information that requires real-time or up-to-date sources.",
    promptSnippet:
      "web_search(query: string, max_results?: number, search_depth?: 'basic' | 'advanced') — Search the web via Tavily API. Returns ranked results with titles, URLs, and snippets.",
    promptGuidelines: [
      "Before making assumptions about current facts, prices, events, or APIs, prefer using web_search to get accurate, up-to-date information.",
      "Use specific queries for better results. For technical questions, include the technology name and version.",
      "When you need authoritative documentation, include 'documentation' or 'docs' in the query.",
    ],
    parameters: Type.Object({
      query: Type.String({
        description: "The search query string",
      }),
      max_results: Type.Optional(
        Type.Integer({
          description: "Maximum number of search results to return (1–10)",
          default: 5,
          minimum: 1,
          maximum: 10,
        }),
      ),
      search_depth: Type.Optional(
        Type.Union(
          [
            Type.Literal("basic", {
              description: "Faster, lower cost — good for most queries",
            }),
            Type.Literal("advanced", {
              description:
                "Slower, higher quality — better for deep research",
            }),
          ],
          { default: "basic" },
        ),
      ),
    }),
    renderShell: "default",
    executionMode: "parallel",

    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const { query, max_results = 5, search_depth = "basic" } = params;
      const key = apiKey || process.env.TAVILY_API_KEY;

      if (!key) {
        return {
          type: "text" as const,
          text: "Web search is not available: TAVILY_API_KEY is not configured. Ask the user to add the Tavily API key to the sops-managed agent-env secret and rebuild.",
        };
      }

      try {
        const response = await fetch(TAVILY_API_URL, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            api_key: key,
            query,
            max_results: Math.min(Math.max(1, max_results), 10),
            search_depth,
          }),
        });

        if (!response.ok) {
          const errorBody = await response.text().catch(() => "");
          return {
            type: "text" as const,
            text: `Tavily search failed (HTTP ${response.status}): ${errorBody}`,
          };
        }

        const data: TavilyResponse = await response.json();
        const { results, answer } = data;

        if (!results || results.length === 0) {
          return {
            type: "text" as const,
            text: `No results found for "${query}". Try rephrasing or broadening the query.`,
          };
        }

        const lines: string[] = [];
        if (answer) {
          lines.push(`Answer: ${answer}`);
          lines.push("");
        }

        lines.push(`Search results for "${query}" (${results.length} results):`);
        lines.push("");

        results.forEach((result, i) => {
          const score = result.score !== undefined
            ? ` [relevance: ${(result.score * 100).toFixed(0)}%]`
            : "";
          lines.push(`${i + 1}. ${result.title}${score}`);
          lines.push(`   URL: ${result.url}`);
          lines.push(`   ${result.content}`);
          lines.push("");
        });

        return {
          type: "text" as const,
          text: lines.join("\n"),
        };
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        return {
          type: "text" as const,
          text: `Web search error: ${message}`,
        };
      }
    },
  });
}
