import { useEffect, useState } from "react";
import { Download } from "lucide-react";
import { Button } from "@/components/ui/button";

const REPO = "kaelys-js/harvest-autofill-releases";
const ZIP = `https://github.com/${REPO}/releases/latest/download/HarvestAutoFill.zip`;

export default function DownloadButton({ size = "lg" }: { size?: "lg" | "default" }) {
	const [ver, setVer] = useState<string | null>(null);
	useEffect(() => {
		fetch(`https://api.github.com/repos/${REPO}/releases/latest`)
			.then((r) => (r.ok ? r.json() : null))
			.then((d) => d?.tag_name && setVer(d.tag_name))
			.catch(() => {});
	}, []);
	return (
		<a href={ZIP} className="inline-block">
			<Button size={size} className="gap-2">
				<Download />
				Download for macOS
				{ver && <span className="font-normal opacity-80">· {ver}</span>}
			</Button>
		</a>
	);
}
