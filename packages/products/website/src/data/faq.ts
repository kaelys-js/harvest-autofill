import * as v from "valibot";
import { FaqItemsSchema, type FaqItem } from "@/lib/schemas";

// Single source of truth for the FAQ: the on-page accordion (Faq.tsx) and the FAQPage
// JSON-LD in Layout.astro both read this array. Validated at module load so a malformed
// entry fails the build rather than shipping broken structured data.
const items: FaqItem[] = [
	{
		q: "How does it know what I worked on?",
		a: "It reads your own Git commits, Azure DevOps pushes, and calendar meetings, then lays them out on a timeline and turns the gaps between them into hours — split across the right projects by when you actually did the work.",
	},
	{
		q: "Can I check the week before it's filed?",
		a: "Yes. The menu-bar window shows the full week — every entry, project, and time range — before anything is sent. Nothing goes to Harvest until you click Log this week, and you can run it as a dry run first to see the result without filing.",
	},
	{
		q: "Where do my tokens and data go?",
		a: "Nowhere but the services you connect. Every token lives only on your Mac in a locked folder — no account, no cloud, no telemetry. The app is open source, so you can read exactly what it does.",
	},
	{
		q: "Do I need to install Python or anything else?",
		a: "No. A full Python runtime is bundled inside the app, so there is nothing to set up beyond entering your own accounts in the guided onboarding.",
	},
	{
		q: "What are the requirements?",
		a: "macOS 26 or newer on Apple Silicon. GitHub works with a token you paste or the GitHub CLI; Azure DevOps and Google Calendar are optional.",
	},
	{
		q: "Why does macOS ask before opening it the first time?",
		a: "macOS checks apps downloaded from the web the first time they run. Right-click Harvest Auto-Fill in your Applications folder, choose Open, and confirm once — it launches normally every time after that.",
	},
	{
		q: "How do updates work?",
		a: "The app checks this repository for a new signed release on launch and once a day. Each update is verified against a key built into the app before it installs, and you can read the plain-language changelog any time.",
	},
	{
		q: "What does it cost?",
		a: "Nothing. It's free and open source under the license in the repository — no subscription, no account, no upsell.",
	},
];

export const faqItems: readonly FaqItem[] = v.parse(FaqItemsSchema, items);
