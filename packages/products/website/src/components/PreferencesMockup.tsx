import { useState } from "react";
import * as v from "valibot";
import { PrefsTabsSchema } from "@/lib/schemas";

// Neutral recreation of the app's Preferences window — all four tabs, clickable. Semantic
// tokens only, so it renders true light/dark with the page. Content mirrors the app's tabs
// (General / Accounts / Allocation / About) without exposing any private connection detail.
type Row = { title: string; body: string };
type Tab = { name: string; path: string; rows: Row[] };

const TABS: Tab[] = [
	{
		name: "General",
		path: "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z M19.4 13a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-2.9 1.2V21a2 2 0 1 1-4 0v-.1A1.7 1.7 0 0 0 7 19.4l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1A1.7 1.7 0 0 0 3 13.6H3a2 2 0 1 1 0-4h.1A1.7 1.7 0 0 0 4.6 7l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1A1.7 1.7 0 0 0 10 3.6V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 2.9 1.2l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.9",
		rows: [
			{
				title: "Automatic recording",
				body: "Files your week to Harvest every Friday at 6pm, even if the app is closed.",
			},
			{
				title: "Dock icon",
				body: "Show a Dock icon in addition to the menu-bar item, or keep it menu-bar only.",
			},
			{
				title: "How it works",
				body: "Recomputes your week's hours in the background every 15 minutes.",
			},
		],
	},
	{
		name: "Accounts",
		path: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M4 20a8 8 0 0 1 16 0",
		rows: [
			{
				title: "Harvest",
				body: "Where your hours are written — the one account the app truly needs.",
			},
			{
				title: "Calendar",
				body: "Optional. Adds meeting hours from your calendar via a private script.",
			},
			{
				title: "GitHub",
				body: "Reads your commits, pushes, and organizations to build the timeline.",
			},
			{
				title: "Azure DevOps — optional",
				body: "Add a token to include repository activity alongside GitHub.",
			},
		],
	},
	{
		name: "Allocation",
		path: "M12 3v9l7 3M21 12a9 9 0 1 1-9-9",
		rows: [
			{ title: "Your workday", body: "Work hours and the days counted as a normal week." },
			{
				title: "Timeline split",
				body: "How commits, pushes, and meetings weight across your projects.",
			},
			{ title: "Holidays", body: "Your region's public holidays, skipped automatically." },
			{ title: "Danger zone", body: "Delete everything and restart setup from scratch." },
		],
	},
	{
		name: "About",
		path: "M12 16v-5M12 8h.01M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z",
		rows: [
			{ title: "Version & updates", body: "See what's new and check for a signed update." },
			{ title: "Website & source", body: "Open this site or the app's open-source repository." },
			{ title: "Your privacy", body: "Every token stays on this Mac and is never sent anywhere." },
		],
	},
];

// Build-time guard: every tab needs a name, an icon path, and at least one row of copy.
v.parse(PrefsTabsSchema, TABS);

export default function PreferencesMockup() {
	const [t, setT] = useState(0);
	const tab: Tab = TABS[t];

	return (
		<div className="w-full max-w-md overflow-hidden rounded-2xl border border-border/60 bg-card shadow-2xl shadow-black/10 ring-1 ring-black/5 dark:shadow-black/40">
			<div className="flex items-center gap-2 border-b border-border/60 px-4 py-3">
				<span className="size-3 rounded-full bg-[#ff5f57]" />
				<span className="size-3 rounded-full bg-[#febc2e]" />
				<span className="size-3 rounded-full bg-[#28c840]" />
				<span className="ml-2 text-xs font-medium text-muted-foreground">Preferences</span>
			</div>

			<div
				className="flex gap-1 border-b border-border/60 px-3 py-2"
				role="tablist"
				aria-label="Preferences tabs"
			>
				{TABS.map((x, n) => (
					<button
						type="button"
						key={x.name}
						role="tab"
						aria-selected={n === t}
						className={`flex flex-1 flex-col items-center gap-1 rounded-md px-2 py-1.5 text-[11px] font-medium transition-colors ${n === t ? "bg-primary/10 text-primary" : "text-muted-foreground hover:bg-muted"}`}
						onClick={() => setT(n)}
					>
						<svg
							viewBox="0 0 24 24"
							className="size-4"
							fill="none"
							stroke="currentColor"
							strokeWidth={1.8}
							strokeLinecap="round"
							strokeLinejoin="round"
						>
							<path d={x.path} />
						</svg>
						{x.name}
					</button>
				))}
			</div>

			<div className="space-y-3 px-5 py-5">
				{tab.rows.map((r) => (
					<div
						key={r.title}
						className="rounded-xl border border-border/60 bg-background/40 px-4 py-3"
					>
						<div className="text-sm font-semibold">{r.title}</div>
						<div className="mt-0.5 text-xs leading-relaxed text-muted-foreground">{r.body}</div>
					</div>
				))}
			</div>
		</div>
	);
}
