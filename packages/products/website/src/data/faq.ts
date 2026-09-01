import * as v from "valibot";
import { FaqItemsSchema, type FaqItem } from "@/lib/schemas";

// Single source of truth for the FAQ: the on-page accordion (Faq.tsx) and the FAQPage
// JSON-LD in Layout.astro both read this array. Validated at module load so a malformed
// entry fails the build rather than shipping broken structured data.
const items: FaqItem[] = [
	{
		q: "How does it know what I worked on?",
		a: "It looks at the work you already leave behind — your commits, your pushes, and your calendar — and lays the week out on a timeline. The time between things becomes hours on the right project, so you never retype what you did.",
	},
	{
		q: "Can I see the week before it's filed?",
		a: "Always. The menu-bar window shows the whole week — every entry, project, and time — before anything is sent. Nothing reaches your timesheet until you say so.",
	},
	{
		q: "Where does my data go?",
		a: "Nowhere but the services you connect. Everything stays on your Mac, in a spot only the app can read — no cloud, no account, no tracking. It's open source, so anyone can check.",
	},
	{
		q: "Is there anything to set up?",
		a: "Barely. Everything the app needs is already inside it. Connect your accounts in a short guided setup and you're done — usually a couple of minutes.",
	},
	{
		q: "What do I need to run it?",
		a: "A Mac on macOS 26 or newer with Apple Silicon. You'll connect Harvest and GitHub; a calendar and Azure DevOps are optional extras.",
	},
	{
		q: "Why does macOS ask before opening it the first time?",
		a: "macOS double-checks anything downloaded from the web the first time it runs. Right-click the app in your Applications folder, choose Open, and confirm once — after that it opens like anything else.",
	},
	{
		q: "How do updates work?",
		a: "It keeps itself current. The app checks for a new version on launch and once a day, confirms it genuinely came from us before installing, and shows you a plain-language note about what changed.",
	},
	{
		q: "What does it cost?",
		a: "Nothing. It's free and open source — no subscription, no account, no upsell.",
	},
];

export const faqItems: readonly FaqItem[] = v.parse(FaqItemsSchema, items);
