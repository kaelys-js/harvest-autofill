import * as v from "valibot";
import { FaqItemsSchema, type FaqItem } from "@/lib/schemas";

// Single source of truth for the FAQ: the on-page accordion (Faq.tsx) and the FAQPage
// JSON-LD in Layout.astro both read this array. Validated at module load so a malformed
// entry fails the build rather than shipping broken structured data.
const items: FaqItem[] = [
	{
		q: "How does it know what I worked on?",
		a: "It reads your commits, pushes, and calendar, then lays the week out on a timeline. Gaps between events become hours on the right project, so you never retype what you did.",
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
		a: "Barely. Everything the app needs is already inside it. Connect your accounts in a short guided setup and you're done.",
	},
	{
		q: "What do I need to run it?",
		a: "A Mac on macOS 26 or newer with Apple Silicon. You'll connect Harvest and GitHub; a calendar and Azure DevOps are optional extras.",
	},
	{
		q: "Why does macOS warn me the first time I open it?",
		a: "macOS quarantines apps downloaded from the web. Right-click the app in your Applications folder, choose Open, then click Open in the dialog — you'll only see it once.",
	},
	{
		q: "How do updates work?",
		a: "The app checks for a new version on launch and once a day. It verifies each update's signature before installing, then shows a plain-language note about what changed.",
	},
	{
		q: "What does it cost?",
		a: "Nothing. It's free and open source — no subscription, no account, no upsell.",
	},
];

export const faqItems: readonly FaqItem[] = v.parse(FaqItemsSchema, items);
