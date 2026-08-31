import "@testing-library/jest-dom/vitest";
import { vi } from "vitest";

// Node 22+ exposes an experimental global `localStorage` that stays undefined unless the
// process is started with --localstorage-file. Under jsdom it shadows window.localStorage,
// so components (and these tests) that read `localStorage` see undefined. Install a
// spec-shaped in-memory Storage when none is present. Browser runtime is unaffected.
if (!globalThis.localStorage) {
	const store = new Map<string, string>();
	const storage: Storage = {
		get length() {
			return store.size;
		},
		clear: () => store.clear(),
		getItem: (key) => (store.has(key) ? store.get(key)! : null),
		key: (index) => Array.from(store.keys())[index] ?? null,
		removeItem: (key) => {
			store.delete(key);
		},
		setItem: (key, value) => {
			store.set(key, String(value));
		},
	};
	Object.defineProperty(globalThis, "localStorage", { value: storage, configurable: true });
	Object.defineProperty(window, "localStorage", { value: storage, configurable: true });
}

// jsdom doesn't implement matchMedia; components read it for reduced-motion.
if (!window.matchMedia) {
	window.matchMedia = vi.fn().mockImplementation((query: string) => ({
		matches: false,
		media: query,
		onchange: null,
		addEventListener: vi.fn(),
		removeEventListener: vi.fn(),
		addListener: vi.fn(),
		removeListener: vi.fn(),
		dispatchEvent: vi.fn(),
	}));
}
