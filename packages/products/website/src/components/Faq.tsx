import {
	Accordion,
	AccordionContent,
	AccordionItem,
	AccordionTrigger,
} from "@/components/ui/accordion";

const items = [
	{
		q: "How does it know what I worked on?",
		a: "It reads your own Git commits, Azure DevOps pushes, and calendar meetings, then lays them out on a timeline and turns the gaps between them into hours — split across the right projects by when you actually did the work.",
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
		q: "Why does macOS say it can't verify the app?",
		a: "The app is signed but not yet notarized, so Gatekeeper asks the first time. After copying it to Applications, run the one-line command in the Download section (or right-click → Open) and it opens normally from then on.",
	},
	{
		q: "How do updates work?",
		a: "The app checks this repository for a new signed release on launch and once a day. Each update is verified against a key built into the app before it installs, and you can see the changelog any time.",
	},
];

export default function Faq() {
	return (
		<Accordion type="single" collapsible className="w-full">
			{items.map((it, i) => (
				<AccordionItem key={i} value={`item-${i}`}>
					<AccordionTrigger>{it.q}</AccordionTrigger>
					<AccordionContent>{it.a}</AccordionContent>
				</AccordionItem>
			))}
		</Accordion>
	);
}
