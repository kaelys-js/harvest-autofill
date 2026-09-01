import { useEffect, useState } from "react";
import { Download } from "lucide-react";
import { Button } from "@/components/ui/button";
import { parseRelease, parseDownloadSize, type DownloadSize } from "@/lib/schemas";

const REPO = "kaelys-js/harvest-autofill-releases";
const ZIP = `https://github.com/${REPO}/releases/latest/download/HarvestAutoFill.zip`;

export default function DownloadButton({ size = "lg" }: { size?: DownloadSize }) {
	const btnSize = parseDownloadSize(size);
	const [ver, setVer] = useState<string | null>(null);
	useEffect(() => {
		fetch(`https://api.github.com/repos/${REPO}/releases/latest`)
			.then((r) => (r.ok ? r.json() : null))
			// Validate the payload with valibot before trusting it; a malformed response
			// yields null and the button simply renders without a version tag.
			.then((d) => {
				const release = parseRelease(d);
				if (release) setVer(release.tag_name);
			})
			.catch(() => {});
	}, []);
	return (
		<a href={ZIP} rel="noopener noreferrer" className="inline-block">
			<Button size={btnSize} className="gap-2">
				<Download />
				Download for macOS
				{/* Width reserved from first paint so the async version tag doesn't reflow the
				    button (and shift its neighbors) once the release fetch resolves — zero CLS. */}
				<span className="inline-block min-w-[5.5ch] text-left font-normal tabular-nums opacity-80">
					{ver ? `· ${ver}` : ""}
				</span>
			</Button>
		</a>
	);
}
