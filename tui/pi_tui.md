# `@earendil-works/pi-tui` Reference

Notes on using `@earendil-works/pi-tui`. Covers rendering, screen modes, built-in components, themes, input, and custom components.

---

## 1. Overview

`@earendil-works/pi-tui` is a TypeScript terminal UI library for text streaming and interactive terminal apps.

- **Differential rendering:** Diffs lines against the previous frame and writes only changed rows.
- **Synchronized output (CSI 2026):** Wraps updates in `\x1b[?2026h` and `\x1b[?2026l`. The terminal renders the frame all at once instead of line-by-line, preventing screen flicker during fast token streaming.
- **Primitives only:** Provides base components (`Container`, `Text`, `Markdown`, `Editor`, `Loader`, `SelectList`). It does not include chat or message widgets; you build those with the primitives.

---

## 2. Rendering Model & Tree Mutation

### The `Component` Interface

Every UI element implements `Component`:

```typescript
interface Component {
  render(width: number): string[];
  handleInput?(data: string): void;
  handleMouse?(event: TuiMouseEvent): TuiMouseEventResult | undefined;
  invalidate(): void;
}
```

- `render(width: number)`: Takes terminal column width. Returns an array of lines. Every string must be `<= width` visible columns.
- `invalidate()`: Drops cached lines. Tells the TUI to re-render this component on the next tick.

### Root Tree vs Child Mutation

> **A component owns its children. Never add or remove components on the root screen during streaming.**

Pi-TUI tracks terminal rows using component positions. Adding or removing components directly on `TuiMainScreen` while streaming shifts row offsets and causes lines to duplicate on screen.

- **Right:** Put dynamic content inside a `Container`. Mutate inside the container using `this.clear()`, add child nodes, and call `super.invalidate()`.
- **Wrong:** Calling `tui.addChild()` and `tui.removeChild()` on the main screen for every streaming token or block.

Keep the top-level tree static:
```text
[ transcriptContainer, loader?, editor ]
```

---

## 3. Screen Modes

Pi-TUI provides two screen drivers:

| Feature | `TuiMainScreen` | `TuiAltScreen` |
|---|---|---|
| Buffer | Main terminal buffer (scrollback preserved) | Alternate buffer (full-screen, clears on exit) |
| Scrolling | Terminal emulator owns scrollback | App owns scrollback via `ScrollView` |
| Mouse | Not captured (terminal handles selection) | Captured (supports click hit-testing) |
| Copy/Paste | Native terminal selection | Virtual selection via OSC 52 |
| Exit | Output stays in terminal history | Restores terminal, clears screen |

### How `TuiMainScreen` Draws

1. **First render:** Writes all lines down the screen.
2. **Normal update:** Moves cursor to the first changed line, clears down with `\x1b[J`, writes changed lines.
3. **Resize or height change above viewport:** Clears screen and redraws everything.

*Note:* Because `TuiMainScreen` does not capture mouse events, click handlers do not work. Collapsible toggles must use keyboard shortcuts (e.g. `Ctrl+O`).

---

## 4. Built-in Components

### `Container`
Base class for grouping components vertically:
```typescript
import { Container } from "@earendil-works/pi-tui";

const box = new Container();
box.addChild(child);
box.removeChild(child);
box.clear();       // removes all children
box.invalidate();  // marks for redraw
```

### `Text`
Multi-line text with automatic word wrapping:
```typescript
import { Text } from "@earendil-works/pi-tui";

const text = new Text("Hello world", paddingX, paddingY);
text.setText("New text");
```
- `paddingX`: Number of spaces added to the left and right.

### `TruncatedText`
Single-line text clipped to width:
```typescript
import { TruncatedText } from "@earendil-works/pi-tui";

const header = new TruncatedText("Single line text...", paddingX, paddingY);
```
- Never wraps. Truncates at the right edge if text exceeds available columns. Use for headers or lines that must stay on a single row.

### `Markdown`
Renders markdown syntax with ANSI colors:
```typescript
import { Markdown } from "@earendil-works/pi-tui";

const md = new Markdown(content, paddingX, paddingY, mdTheme);
```

**Streaming pattern:** Recreate `Markdown` inside a container on every token delta:
```typescript
class MessageBlock extends Container {
  private text = "";

  append(delta: string) {
    this.text += delta;
    this.clear();
    this.addChild(new Markdown(this.text, 1, 0, mdTheme));
    super.invalidate();
  }
}
```

### `Editor`
Multi-line input field with arrow navigation, paste handling, and history:
```typescript
import { Editor } from "@earendil-works/pi-tui";

const editor = new Editor(tui, editorTheme, { paddingX: 1 });

editor.onSubmit = (text: string) => {
  // fires on Enter
};
```
- Must call `tui.setFocus(editor)` to receive keyboard input.

### `Loader`
Animated spinner:
```typescript
import { Loader } from "@earendil-works/pi-tui";

const loader = new Loader(tui, spinnerColorFn, messageColorFn, "working…");
loader.start();
loader.setMessage("thinking…");
loader.stop();
```

**Leading empty line gotcha:** `Loader.render()` in Pi-TUI hardcodes `return ["", ...super.render(width)]`, adding an empty line above the spinner. To remove the extra line, subclass it:
```typescript
class TightLoader extends Loader {
  override render(width: number): string[] {
    const lines = super.render(width);
    return lines.length > 0 && lines[0] === "" ? lines.slice(1) : lines;
  }
}
```

### `SelectList`
Keyboard-navigable list:
```typescript
import { SelectList } from "@earendil-works/pi-tui";

const list = new SelectList(
  [
    { value: "opt1", label: "Option 1", description: "Details" },
    { value: "opt2", label: "Option 2" },
  ],
  maxVisibleRows,
  selectListTheme
);

list.onSelect = (item) => { /* Enter */ };
list.onCancel = () => { /* Esc */ };
```
- Must call `tui.setFocus(list)` for arrow keys and Enter to work.

### `Spacer`
Adds empty vertical rows:
```typescript
import { Spacer } from "@earendil-works/pi-tui";

new Spacer(1); // 1 blank line
```

---

## 5. Themes & Colors

Theme properties are functions that wrap a string in ANSI escape codes: `(text: string) => string`.

```typescript
const cyan = (s: string) => `\x1b[36m${s}\x1b[0m`;
const dim = (s: string) => `\x1b[90m${s}\x1b[0m`;
const bold = (s: string) => `\x1b[1m${s}\x1b[0m`;
```

### `MarkdownTheme`
Requires all 14 functions (missing keys throw at runtime):
```typescript
import type { MarkdownTheme } from "@earendil-works/pi-tui";

export const mdTheme: MarkdownTheme = {
  heading: bold,
  link: cyan,
  linkUrl: dim,
  code: (s) => `\x1b[32m${s}\x1b[0m`,
  codeBlock: (s) => `\x1b[32m${s}\x1b[0m`,
  codeBlockBorder: dim,
  quote: dim,
  quoteBorder: dim,
  hr: dim,
  listBullet: cyan,
  bold: bold,
  italic: (s) => `\x1b[3m${s}\x1b[0m`,
  strikethrough: (s) => `\x1b[9m${s}\x1b[0m`,
  underline: (s) => `\x1b[4m${s}\x1b[0m`,
};
```

### `EditorTheme`
Requires border color and select list styles:
```typescript
import type { EditorTheme, SelectListTheme } from "@earendil-works/pi-tui";

export const selectListTheme: SelectListTheme = {
  selectedPrefix: cyan,
  selectedText: cyan,
  description: dim,
  scrollInfo: dim,
  noMatch: dim,
};

export const editorTheme: EditorTheme = {
  borderColor: dim,
  selectList: selectListTheme,
};
```

---

## 6. Keyboard Input & Focus

### Raw Mode and `Ctrl+C`

Pi-TUI runs the terminal in raw mode. In raw mode, `Ctrl+C` does not raise an OS `SIGINT`. You must listen for it:

```typescript
import { Key, matchesKey } from "@earendil-works/pi-tui";

tui.addInputListener((data: string) => {
  if (matchesKey(data, Key.ctrl("c"))) {
    tui.stop();
    process.exit(0);
  }

  if (matchesKey(data, Key.ctrl("o"))) {
    toggleCollapse();
    return { consume: true }; // prevents key reaching focused input
  }
});
```

- Return `{ consume: true }` to stop the keystroke from passing to the focused widget.
- Available key helpers: `Key.ctrl("c")`, `Key.esc`, `Key.up`, `Key.down`, `Key.shift("tab")`.

### Focus

Keystrokes go to the currently focused component:
```typescript
tui.setFocus(editor); // typing goes into editor
tui.setFocus(list);   // arrow keys navigate list
```

---

## 7. Autocomplete (`CombinedAutocompleteProvider`)

Wires slash command and file path completion into `Editor`:

```typescript
import { CombinedAutocompleteProvider, type SlashCommand } from "@earendil-works/pi-tui";

const slashCommands: SlashCommand[] = [
  { name: "clear", description: "Clear conversation" },
  {
    name: "resume",
    description: "Switch session",
    argumentHint: "<id>",
    async getArgumentCompletions(prefix: string) {
      const rows = await fetchSessions();
      return rows.map((r) => ({ value: r.id, label: r.id }));
    },
  },
];

editor.setAutocompleteProvider(
  new CombinedAutocompleteProvider(slashCommands, process.cwd(), "/usr/bin/fd")
);
```

- `/` triggers slash commands.
- `./`, `../`, `~/` triggers file path suggestions.
- `@` triggers fuzzy file search (requires path to `fd` binary).

---

## 8. Custom Components

To build custom components, subclass `Container` and assemble existing primitives:

```typescript
import { Container, TruncatedText, Text } from "@earendil-works/pi-tui";

class StatusCard extends Container {
  private header: string;
  private detail: string;

  constructor(header: string, detail: string = "") {
    super();
    this.header = header;
    this.detail = detail;
    this.sync();
  }

  update(header: string, detail: string = "") {
    this.header = header;
    this.detail = detail;
    this.sync();
  }

  private sync() {
    this.clear(); // remove existing children
    this.addChild(new TruncatedText(this.header, 1, 0));
    if (this.detail) {
      this.addChild(new Text(this.detail, 1, 0));
    }
    super.invalidate(); // request redraw
  }
}
```

- Mutate state inside the component.
- Call `this.clear()` to remove old children, re-add updated primitives, and call `super.invalidate()`.
