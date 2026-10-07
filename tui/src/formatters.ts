export function summarizeArgs(
    args: Record<string, unknown> | null | undefined,
): string {
    if (!args) return "";

    return Object.entries(args)
        .map(([k, v]) => {
            let text = typeof v == "string" ? v : JSON.stringify(v);
            text = text.replace(/\s+/g, " ").trim(); // flatten newlines and extra spaces

            if (text.length > 60) {
                text = `${text.slice(0, 60)}...`;
            }

            return `${k}: ${text}`;
        })
        .join(", ");
}

export function formatTokens(count: number): string {
    if (count >= 1_000_000) {
        return `${(count / 1_000_000).toFixed(1)}M`;
    }

    if (count >= 1_000) {
        return `${(count / 1_000).toFixed(1)}k`;
    }

    return `${count}`;
}
