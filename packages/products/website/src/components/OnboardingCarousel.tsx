import { useEffect, useState } from "react";
import { Clock, KeyRound, Sparkles, Workflow, CalendarClock, BadgeCheck } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import * as v from "valibot";
import { OnboardingStepsSchema, parsePositiveInt } from "@/lib/schemas";

// A neutral recreation of the app's 6-step first-run wizard. Each icon mirrors the matching
// step's SF Symbol in the app (welcome/clock, key, sparkles, sources, workday, finish), so the
// site and the app show the same steps. Semantic tokens only, so it renders true light/dark.
type Step = { title: string; body: string; Icon: LucideIcon };

const STEPS: Step[] = [
	{
		Icon: Clock,
		title: "Welcome to Harvest Auto-Fill",
		body: "Your timesheet, filled from the work you already did.",
	},
	{
		Icon: KeyRound,
		title: "Connect your Harvest account",
		body: "The one account it truly needs — where your hours get written.",
	},
	{
		Icon: Sparkles,
		title: "Find your projects automatically",
		body: "It reads your accounts and fills in the details, so you never type them by hand.",
	},
	{
		Icon: Workflow,
		title: "Where your work lives",
		body: "Pick what turns into hours. GitHub is the main one; the rest are optional.",
	},
	{
		Icon: CalendarClock,
		title: "Your workday",
		body: "Sensible defaults are already set — tweak them only if yours differ.",
	},
	{
		Icon: BadgeCheck,
		title: "Here's your week",
		body: "A live preview from everything you connected — nothing's written yet.",
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
	// i is always in range (setI wraps with modulo) and STEPS is schema-validated non-empty.
	const step: Step = STEPS[i]!;

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

			<div className="flex items-start gap-4 px-7 py-8" aria-live="polite">
				<div className="grid size-14 shrink-0 place-items-center rounded-2xl bg-gradient-to-br from-[#f6903a] to-[#e2541f] shadow-md">
					<step.Icon className="size-8 text-white" strokeWidth={1.8} aria-hidden="true" />
				</div>
				<div>
					<h3 className="text-xl font-bold tracking-tight">{step.title}</h3>
					<p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">{step.body}</p>
				</div>
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
