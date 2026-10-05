/**
 * web-search.ts — pi extension that adds a `web_search` tool.
 *
 * Backend: DuckDuckGo HTML endpoint (html.duckduckgo.com). No API key or
 * service account required, but note that this scrapes anonymous HTML,
 * so automated (non-browser) access can get a CAPTCHA from the very first
 * request depending on network/DC (bot detection). Treat as best-effort.
 * The HTML is parsed with regexes against the stable `result__a` /
 * `result__snippet` class names; if DuckDuckGo changes its layout, snippet
 * extraction may silently degrade (the block check below still applies).
 *
 * Installed by home-manager to ~/.pi/agent/extensions/web-search.ts (see
 * hosts/MacBookPro-minami/home.nix).
 *
 * The tool is active by default. Scope the tool set per invocation with
 * `pi --tools web_search`, or drop this tool with `pi --exclude-tools web_search`.
 */

import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";

/** Strip HTML tags, decode common and numeric character references. */
function textOf(input: string): string {
    return input
        .replace(/<[^>]*>/g, " ")
        .replace(/&#x([0-9a-fA-F]+);/g, (_m, hex: string) => codePoint(parseInt(hex, 16)))
        .replace(/&#(\d+);/g, (_m, dec: string) => codePoint(parseInt(dec, 10)))
        .replace(/&quot;/g, '"')
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&nbsp;/g, " ")
        .replace(/&amp;/g, "&")
        .replace(/\s+/g, " ")
        .trim();
}

function codePoint(n: number): string {
    try {
        return String.fromCodePoint(n);
    } catch {
        return "";
    }
}

/**
 * DuckDuckGo wraps result URLs in a redirect (`uddg=` parameter).
 * Note: `searchParams.get` already percent-decodes once, so the value is
 * returned as-is (decoding again would corrupt URLs containing `%`).
 */
function resolveUrl(href: string): string {
    const full = href.startsWith("//") ? `https:${href}` : href;
    try {
        const u = new URL(full);
        const target = u.searchParams.get("uddg");
        if (target) return target;
    } catch {
        /* not a DDG redirect; return as-is */
    }
    return full;
}

interface SearchResult {
    title: string;
    url: string;
    snippet: string;
}

async function ddgSearch(query: string,
    maxResults: number,
    signal?: AbortSignal): Promise<SearchResult[]> {
    const res = await fetch(
        `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`,
        {
            headers: {
                "User-Agent": USER_AGENT,
                Accept: "text/html",
                "Accept-Language": "en-US,en;q=0.9",
            },
            signal,
        },
    );
    if (!res.ok) throw new Error(`DuckDuckGo request failed: HTTP ${res.status}`);
    const html = await res.text();

    // Bot detection returns HTTP 200 (sometimes 202) with a CAPTCHA page.
    if (/anomaly-modal|bots use DuckDuckGo/i.test(html)) {
        throw new Error(
            "DuckDuckGo returned a bot-detection (CAPTCHA) page. " +
            "Retry later or try a different query.",
        );
    }

    const results: SearchResult[] = [];
    const linkRe = /<a[^>]+class="result__a"[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/g;
    let m: RegExpExecArray | null;
    while ((m = linkRe.exec(html)) !== null && results.length < maxResults) {
        const url = resolveUrl(m[1]);
        // Ad results point at duckduckgo.com/y.js with no uddg target.
        if (url.includes("duckduckgo.com/y.js") || url.includes("ad_provider")) continue;
        const title = textOf(m[2]);

        // The snippet anchor sits between this result's title anchor and the
        // next result's title anchor.
        const rest = html.slice(linkRe.lastIndex, linkRe.lastIndex + 4000);
        const next = rest.indexOf('class="result__a"');
        const windowText = next !== -1 ? rest.slice(0, next) : rest;
        const sm = /class="result__snippet"[^>]*>([\s\S]*?)<\/a>/.exec(windowText);
        const snippet = sm && sm[1] ? textOf(sm[1]) : "";

        results.push({ title, url, snippet });
    }
    return results;
}

const webSearchTool = defineTool({
    name: "web_search",
    label: "Web Search",
    description:
        "Search the web via DuckDuckGo. Returns the top results as a numbered " +
        "list of title, URL, and snippet. Use for current information (news, " +
        "release notes, documentation, facts) not in local files. " +
        "Best-effort: the search engine may rate-limit or CAPTCHA " +
        "non-browser clients.",
    parameters: Type.Object({
        query: Type.String({
            description: "Search query",
        }),
        max_results: Type.Optional(
            Type.Integer({ description: "Maximum number of results to return (default 5)",
                minimum: 1,
                maximum: 10 }),
        ),
    }),
    async execute(_toolCallId, params, signal) {
        const maxResults = Math.min(Math.max(Math.floor(params.max_results ?? 5), 1), 10);
        const results = await ddgSearch(params.query, maxResults, signal);
        const text = results.length
            ? results
                .map((r, i) =>
                    `${i + 1}. ${r.title}\n   URL: ${r.url}${r.snippet ? `\n   ${r.snippet}` : ""}`,
                )
                .join("\n\n")
            : "(no results)";
        return {
            content: [
                {
                    type: "text" as const,
                    text: `${results.length} result(s) for "${params.query}":\n\n${text}`,
                },
            ],
            details: {
                query: params.query,
                count: results.length,
                urls: results.map((r) => r.url),
            },
        };
    },
});

export default function (pi: ExtensionAPI) {
    pi.registerTool(webSearchTool);
}
