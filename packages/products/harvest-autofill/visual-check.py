#!/usr/bin/env python3
"""App visual regression: render every screen with the app's --render hook and pixel-diff it
against a committed baseline. Baselines are generated on the macOS runner for font determinism.

  uv run --with pillow visual-check.py --update   # (re)generate baselines
  uv run --with pillow visual-check.py            # compare; non-zero exit on any regression

Requires a built app at dist/Harvest Auto-Fill.app (run build.sh first)."""

import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, "dist", "Harvest Auto-Fill.app", "Contents", "MacOS", "Harvest")
BASELINE = os.path.join(HERE, "visual-baseline")
SCREENS = [
    "main",
    "main-empty",
    "main-issues",
    "prefs",
    "prefs-accounts",
    "prefs-allocation",
    "about",
    "whatsnew",
    "whatsnewmanual",
    "reset",
    "verify",
    "onb0",
    "onb1",
    "onb2",
    "onb3",
    "onb4",
    "onb5",
]
THRESHOLD = 0.001  # allow <0.1% of pixels to differ (sub-pixel AA jitter)


def render(name, out):
    d = tempfile.mkdtemp()
    open(os.path.join(d, "config.json"), "w").write("{}")
    env = {**os.environ, "HARVEST_DATA_DIR": d}
    subprocess.run(
        [APP, "--render", name, out],
        env=env,
        timeout=60,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if not os.path.exists(out):
        raise RuntimeError(f"render '{name}' produced no PNG")


def diff_fraction(a, b):
    ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    if ia.size != ib.size:
        return 1.0
    bbox = ImageChops.difference(ia, ib).getbbox()
    if not bbox:
        return 0.0
    diff = ImageChops.difference(ia, ib).convert("L")
    changed = sum(1 for p in diff.getdata() if p > 8)
    return changed / (ia.width * ia.height)


def main():
    update = "--update" in sys.argv
    if not os.path.exists(APP):
        sys.exit(f"no built app at {APP} — run build.sh first")
    os.makedirs(BASELINE, exist_ok=True)
    tmp = tempfile.mkdtemp()
    failures = []
    for name in SCREENS:
        out = os.path.join(tmp, f"{name}.png")
        render(name, out)
        base = os.path.join(BASELINE, f"{name}.png")
        if update:
            Image.open(out).save(base)
            print(f"baseline updated: {name}")
            continue
        if not os.path.exists(base):
            failures.append(f"{name}: no baseline (run --update)")
            continue
        frac = diff_fraction(out, base)
        status = "ok" if frac <= THRESHOLD else "REGRESSED"
        print(f"{name:16} {frac * 100:6.3f}% changed  {status}")
        if frac > THRESHOLD:
            failures.append(f"{name}: {frac * 100:.3f}% of pixels changed")
    if failures:
        print("\nVISUAL REGRESSION:")
        for f in failures:
            print("  -", f)
        sys.exit(1)
    print("\nAll screens match their baselines." if not update else "\nBaselines written.")


if __name__ == "__main__":
    main()
