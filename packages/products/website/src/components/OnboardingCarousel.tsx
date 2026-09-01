import { useEffect, useState } from "react";
import * as v from "valibot";
import { OnboardingStepsSchema, parsePositiveInt } from "@/lib/schemas";

// A neutral recreation of the app's 6-step first-run wizard. Semantic tokens only, so it
// renders true light/dark with the page. Clickable dots + arrows, auto-advance that pauses
// on hover/focus and is disabled under prefers-reduced-motion.
type Step = { title: string; body: string; path: string };

const STEPS: Step[] = [
	{
		title: "Welcome to Harvest Auto-Fill",
		body: "Your timesheet, filled from the work you already did.",
		path: "M12 3v3m0 12v3m9-9h-3M6 12H3m14.5-6.5-2 2m-9 9-2 2m0-13 2 2m9 9 2 2",
	},
	{
		title: "Connect your Harvest account",
		body: "The one account we truly need — it's where your hours get written.",
		path: "M15 7a4 4 0 1 0-3.9 5H14l2 2 2-2 2 2 2-2-2-2M8 11l-5 5v3h3l5-5",
	},
	{
		title: "Find your projects automatically",
		body: "We read your accounts and fill in the IDs — no typing them by hand.",
		path: "M12 3l1.9 4.6L18.5 9l-4.6 1.9L12 15l-1.9-4.1L5.5 9l4.6-1.4z M18 15l.8 2 .2.8m-14-2 .8 2",
	},
	{
		title: "Where your work lives",
		body: "Pick the sources to turn into hours. GitHub is the main one; the rest are optional.",
		path: "M6 3v12a3 3 0 0 0 3 3h6m0 0a3 3 0 1 0 0 .01M6 6a3 3 0 1 0 0-.01",
	},
	{
		title: "Your workday",
		body: "Sensible defaults are already set — adjust only if yours differ, then continue.",
		path: "M12 7v5l3 2M12 3a9 9 0 1 0 .01 0",
	},
	{
		title: "Here's your week",
		body: "A live preview from everything you connected — nothing is written yet.",
		path: "M9 12l2 2 4-4M12 3a9 9 0 1 0 .01 0",
	},
];

// Build-time guard: every slide needs copy and a real icon path.
v.parse(OnboardingStepsSchema, STEPS);

const AUTO_MS: number = parsePositiveInt(5000);

export default function OnboardingCarousel() {
	const [i, setI] = useState(0);
	const [paused, setPaused] = useState(false);
	// Detected on the client at hydration (this island is client:visible), so the very first
	// auto-advance already respects the user's motion preference.
	const [reduced] = useState(
		() => typeof window !== "undefined" && matchMedia("(prefers-reduced-motion: reduce)").matches,
	);

	useEffect(() => {
		if (paused || reduced) return;
		const t: ReturnType<typeof setTimeout> = setTimeout(
			() => setI((n) => (n + 1) % STEPS.length),
			AUTO_MS,
		);
		return () => clearTimeout(t);
		// reduced is stable (set once at hydration); listed for exhaustive-deps, flagged
		// as "extra" only because it never changes — safe to keep.
		// oxlint-disable-next-line react/exhaustive-effect-dependencies
	}, [i, paused, reduced]);

	const go: (n: number) => void = (n) => setI((n + STEPS.length) % STEPS.length);
	const step: Step = STEPS[i];

	return (
		<div
			className="w-full max-w-md overflow-hidden rounded-2xl border border-border/60 bg-card shadow-2xl shadow-black/10 ring-1 ring-black/5 dark:shadow-black/40"
			onMouseEnter={() => setPaused(true)}
			onMouseLeave={() => setPaused(false)}
			onFocusCapture={() => setPaused(true)}
			onBlurCapture={() => setPaused(false)}
		>
			<div className="flex items-center gap-2 border-b border-border/60 px-4 py-3">
				<span className="size-3 rounded-full bg-[#ff5f57]" />
				<span className="size-3 rounded-full bg-[#febc2e]" />
				<span className="size-3 rounded-full bg-[#28c840]" />
				<span className="ml-2 text-xs font-medium text-muted-foreground">
					Harvest Auto-Fill — Setup
				</span>
				<span className="ml-auto text-xs tabular-nums text-muted-foreground">
					Step {i + 1} of {STEPS.length}
				</span>
			</div>

			<div className="px-7 py-8 text-center" aria-live="polite">
				<div className="mx-auto grid size-16 place-items-center rounded-2xl bg-gradient-to-br from-[#f6903a] to-[#e2541f] shadow-md">
					<svg
						viewBox="0 0 24 24"
						className="size-9 text-white"
						fill="none"
						stroke="currentColor"
						strokeWidth={1.8}
						strokeLinecap="round"
						strokeLinejoin="round"
					>
						<path d={step.path} />
					</svg>
				</div>
				<h3 className="mt-5 text-xl font-bold tracking-tight">{step.title}</h3>
				<p className="mx-auto mt-2 max-w-xs text-sm leading-relaxed text-muted-foreground">
					{step.body}
				</p>
			</div>

			<div className="flex items-center justify-between border-t border-border/60 px-5 py-4">
				<button
					type="button"
					className="rounded-md px-3 py-1.5 text-sm text-muted-foreground transition-colors hover:bg-muted"
					onClick={() => go(i - 1)}
					aria-label="Previous step"
				>
					Back
				</button>
				<div className="flex gap-2" role="tablist" aria-label="Onboarding steps">
					{STEPS.map((s, n) => (
						<button
							type="button"
							key={s.title}
							role="tab"
							aria-selected={n === i}
							aria-label={`Step ${n + 1}: ${s.title}`}
							className={`size-2 rounded-full transition-all ${n === i ? "w-5 bg-primary" : "bg-border hover:bg-muted-foreground/40"}`}
							onClick={() => go(n)}
						/>
					))}
				</div>
				<button
					type="button"
					className="rounded-md bg-primary px-3 py-1.5 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90"
					onClick={() => go(i + 1)}
					aria-label="Next step"
				>
					{i === STEPS.length - 1 ? "Done" : "Continue"}
				</button>
			</div>
		</div>
	);
}
