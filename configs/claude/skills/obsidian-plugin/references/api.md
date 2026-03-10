# Obsidian Plugin API Reference

## Plugin Lifecycle

```ts
import { Plugin } from "obsidian";

export default class MyPlugin extends Plugin {
  async onload() {
    // Called when plugin is loaded. Register all events, commands, views here.
  }

  async onunload() {
    // Called when plugin is disabled. Anything registered with
    // registerEvent/registerInterval/registerDomEvent is auto-cleaned.
    // Only use for custom cleanup (closing connections, etc.)
  }

  async onUserEnable() {
    // Called only when user manually enables the plugin (not on startup).
    // Use for one-time setup like showing a welcome notice.
  }

  onExternalSettingsChange() {
    // Called when settings are modified externally (e.g., sync).
    // Reload settings: this.loadData()
  }
}
```

## Settings

### Settings Interface & Defaults

```ts
interface MyPluginSettings {
  settingA: string;
  settingB: boolean;
  settingC: number;
}

const DEFAULT_SETTINGS: MyPluginSettings = {
  settingA: "default",
  settingB: true,
  settingC: 42,
};
```

### Loading & Saving (in Plugin class)

```ts
settings: MyPluginSettings;

async onload() {
  await this.loadSettings();
  this.addSettingTab(new MySettingTab(this.app, this));
}

async loadSettings() {
  this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
}

async saveSettings() {
  await this.saveData(this.settings);
}
```

### Settings Tab

```ts
import { App, PluginSettingTab, Setting } from "obsidian";

class MySettingTab extends PluginSettingTab {
  plugin: MyPlugin;

  constructor(app: App, plugin: MyPlugin) {
    super(app, plugin);
    this.plugin = plugin;
  }

  display(): void {
    const { containerEl } = this;
    containerEl.empty();

    new Setting(containerEl)
      .setName("Setting name")
      .setDesc("Description of this setting")
      .addText((text) =>
        text
          .setPlaceholder("placeholder")
          .setValue(this.plugin.settings.settingA)
          .onChange(async (value) => {
            this.plugin.settings.settingA = value;
            await this.plugin.saveSettings();
          })
      );

    new Setting(containerEl)
      .setName("Toggle setting")
      .setDesc("Description")
      .addToggle((toggle) =>
        toggle.setValue(this.plugin.settings.settingB).onChange(async (value) => {
          this.plugin.settings.settingB = value;
          await this.plugin.saveSettings();
        })
      );
  }
}
```

### Setting Class Methods

```ts
new Setting(containerEl)
  .setName("Name")
  .setDesc("Description")
  .setClass("my-custom-class")
  .setHeading()                    // Makes this a section header
  .setDisabled(condition)
  .addText(cb)                     // Text input
  .addTextArea(cb)                 // Multi-line text
  .addToggle(cb)                   // Boolean switch
  .addSlider(cb)                   // Numeric slider
  .addDropdown(cb)                 // Select dropdown
  .addColorPicker(cb)              // Color picker
  .addButton(cb)                   // Button
  .addExtraButton(cb)              // Secondary button (icon)
  .addMomentFormat(cb)             // Date format input
  .addSearch(cb);                  // Search input

// Dropdown example
.addDropdown(dropdown => dropdown
  .addOption("value1", "Label 1")
  .addOption("value2", "Label 2")
  .setValue(this.plugin.settings.choice)
  .onChange(async (value) => {
    this.plugin.settings.choice = value;
    await this.plugin.saveSettings();
  })
);

// Slider example
.addSlider(slider => slider
  .setLimits(0, 100, 5)           // min, max, step
  .setValue(this.plugin.settings.settingC)
  .setDynamicTooltip()
  .onChange(async (value) => {
    this.plugin.settings.settingC = value;
    await this.plugin.saveSettings();
  })
);
```

## Commands

```ts
// Simple command
this.addCommand({
  id: "my-command",
  name: "Do something",
  callback: () => {
    // Runs unconditionally
  },
});

// Conditional command (shows in palette only when check passes)
this.addCommand({
  id: "my-check-command",
  name: "Do something conditionally",
  checkCallback: (checking: boolean) => {
    const view = this.app.workspace.getActiveViewOfType(MarkdownView);
    if (view) {
      if (!checking) {
        // Actually execute
      }
      return true;
    }
    return false;
  },
});

// Editor command (only available when editor is focused)
this.addCommand({
  id: "my-editor-command",
  name: "Editor action",
  editorCallback: (editor: Editor, view: MarkdownView) => {
    const selection = editor.getSelection();
    editor.replaceSelection(selection.toUpperCase());
  },
});
```

**Never set `hotkeys` in command definitions** — let users configure their own.

## Ribbon Icon

```ts
this.addRibbonIcon("dice", "My plugin action", (evt: MouseEvent) => {
  new Notice("Ribbon clicked!");
});
```

Icon names come from Lucide icons: https://lucide.dev/icons/

## Status Bar

```ts
const statusBarEl = this.addStatusBarItem();
statusBarEl.setText("Status text");

// Update dynamically
this.registerInterval(
  window.setInterval(() => {
    statusBarEl.setText(`Words: ${getWordCount()}`);
  }, 1000)
);
```

## Modal

```ts
import { App, Modal } from "obsidian";

class MyModal extends Modal {
  result: string;
  onSubmit: (result: string) => void;

  constructor(app: App, onSubmit: (result: string) => void) {
    super(app);
    this.onSubmit = onSubmit;
  }

  onOpen() {
    const { contentEl } = this;
    contentEl.createEl("h2", { text: "Title" });

    new Setting(contentEl).setName("Name").addText((text) =>
      text.onChange((value) => {
        this.result = value;
      })
    );

    new Setting(contentEl).addButton((btn) =>
      btn.setButtonText("Submit").setCta().onClick(() => {
        this.close();
        this.onSubmit(this.result);
      })
    );
  }

  onClose() {
    const { contentEl } = this;
    contentEl.empty();
  }
}

// Usage:
new MyModal(this.app, (result) => {
  new Notice(`Got: ${result}`);
}).open();
```

## SuggestModal & FuzzySuggestModal

```ts
import { FuzzySuggestModal, FuzzyMatch } from "obsidian";

interface MyItem {
  title: string;
  value: string;
}

class MySuggestModal extends FuzzySuggestModal<MyItem> {
  items: MyItem[];
  onChoose: (item: MyItem) => void;

  constructor(app: App, items: MyItem[], onChoose: (item: MyItem) => void) {
    super(app);
    this.items = items;
    this.onChoose = onChoose;
  }

  getItems(): MyItem[] {
    return this.items;
  }

  getItemText(item: MyItem): string {
    return item.title;
  }

  onChooseItem(item: MyItem, evt: MouseEvent | KeyboardEvent): void {
    this.onChoose(item);
  }
}
```

## Notice

```ts
import { Notice } from "obsidian";

new Notice("Short message");                     // Default 5s
new Notice("Longer message", 10000);             // 10s duration
new Notice("Persistent message", 0);             // Stays until dismissed
```

## HTML Helpers

```ts
// Available on HTMLElement (and containerEl, contentEl, etc.)
const div = parentEl.createDiv({ cls: "my-class", text: "Hello" });
const span = parentEl.createSpan({ cls: "highlight" });
const el = parentEl.createEl("h3", { text: "Title", cls: "heading" });
const link = parentEl.createEl("a", { text: "Click", href: "#", attr: { target: "_blank" } });

// Empty an element (remove all children)
containerEl.empty();

// Create with attributes
parentEl.createEl("input", {
  type: "text",
  placeholder: "Enter value",
  cls: "my-input",
  attr: { "data-id": "123" },
});

// DocumentFragment for batch DOM operations
const frag = createFragment((el) => {
  el.createEl("p", { text: "Paragraph 1" });
  el.createEl("p", { text: "Paragraph 2" });
});
parentEl.appendChild(frag);
```

## Custom Views (ItemView)

```ts
import { ItemView, WorkspaceLeaf } from "obsidian";

const VIEW_TYPE = "my-custom-view";

class MyView extends ItemView {
  constructor(leaf: WorkspaceLeaf) {
    super(leaf);
  }

  getViewType(): string {
    return VIEW_TYPE;
  }

  getDisplayText(): string {
    return "My view";
  }

  getIcon(): string {
    return "layout-list";
  }

  async onOpen() {
    const container = this.containerEl.children[1];
    container.empty();
    container.createEl("h4", { text: "My custom view" });
  }

  async onClose() {
    // Cleanup
  }
}

// Register in Plugin.onload():
this.registerView(VIEW_TYPE, (leaf) => new MyView(leaf));

// Activate the view:
async activateView() {
  const { workspace } = this.app;
  let leaf = workspace.getLeavesOfType(VIEW_TYPE)[0];
  if (!leaf) {
    const rightLeaf = workspace.getRightLeaf(false);
    if (rightLeaf) {
      await rightLeaf.setViewState({ type: VIEW_TYPE, active: true });
      leaf = rightLeaf;
    }
  }
  if (leaf) workspace.revealLeaf(leaf);
}
```

## Editor Extensions (CodeMirror 6)

### Editor Suggest (Autocomplete)

```ts
import { Editor, EditorPosition, EditorSuggest, EditorSuggestContext, EditorSuggestTriggerInfo, TFile } from "obsidian";

class MySuggest extends EditorSuggest<string> {
  onTrigger(cursor: EditorPosition, editor: Editor, file: TFile | null): EditorSuggestTriggerInfo | null {
    const line = editor.getLine(cursor.line);
    const match = line.slice(0, cursor.ch).match(/::(\w*)$/);
    if (match) {
      return {
        start: { line: cursor.line, ch: cursor.ch - match[1].length },
        end: cursor,
        query: match[1],
      };
    }
    return null;
  }

  getSuggestions(context: EditorSuggestContext): string[] {
    return ["suggestion1", "suggestion2"].filter((s) => s.startsWith(context.query));
  }

  renderSuggestion(value: string, el: HTMLElement): void {
    el.createEl("span", { text: value });
  }

  selectSuggestion(value: string): void {
    if (this.context) {
      const { editor, start, end } = this.context;
      editor.replaceRange(value, start, end);
    }
  }
}

// Register in onload():
this.registerEditorSuggest(new MySuggest(this.app));
```

### Markdown Post Processor

```ts
// Process rendered markdown (reading view)
this.registerMarkdownPostProcessor((element, context) => {
  const codeBlocks = element.querySelectorAll("code");
  codeBlocks.forEach((code) => {
    // Transform rendered content
  });
});
```

### Code Block Processor

```ts
this.registerMarkdownCodeBlockProcessor("my-lang", (source, el, ctx) => {
  // source: raw content of the code block
  // el: container element to render into
  const rows = source.split("\n").filter((row) => row.length > 0);
  const table = el.createEl("table");
  for (const row of rows) {
    const tr = table.createEl("tr");
    for (const cell of row.split(",")) {
      tr.createEl("td", { text: cell.trim() });
    }
  }
});
```

## Vault API

```ts
const { vault } = this.app;

// Read
const content = await vault.read(file);          // TFile → string
const binary = await vault.readBinary(file);     // TFile → ArrayBuffer
const cachedRead = await vault.cachedRead(file); // Uses cache, faster

// Write
await vault.create("path/to/file.md", "content");
await vault.createBinary("path/to/file.png", arrayBuffer);
await vault.createFolder("path/to/folder");

// Modify (use process() for background edits to avoid race conditions)
await vault.modify(file, "new full content");
await vault.process(file, (data) => {
  return data.replace("old", "new");             // Return modified content
});

// Delete
await vault.delete(file);                        // Permanent delete
await vault.trash(file, true);                   // Move to system trash
await vault.trash(file, false);                  // Move to .trash folder

// File lookup
const file = vault.getFileByPath("path/to/file.md");          // TFile | null
const folder = vault.getFolderByPath("path/to/folder");       // TFolder | null
const abstractFile = vault.getAbstractFileByPath("path");     // TAbstractFile | null

// All files
const allFiles = vault.getFiles();               // TFile[] (no folders)
const markdownFiles = vault.getMarkdownFiles();  // TFile[] (only .md)
const allItems = vault.getAllLoadedFiles();       // TAbstractFile[] (files + folders)

// Rename / Move
await vault.rename(file, "new/path/file.md");
await vault.copy(file, "copy/path/file.md");
```

## Workspace API

```ts
const { workspace } = this.app;

// Active file and view
const activeFile = workspace.getActiveFile();                  // TFile | null
const mdView = workspace.getActiveViewOfType(MarkdownView);   // MarkdownView | null
const editor = mdView?.editor;                                 // Editor | null

// Leaves (tabs/panes)
const leaves = workspace.getLeavesOfType("markdown");          // WorkspaceLeaf[]
const rightLeaf = workspace.getRightLeaf(false);               // Sidebar leaf
const newLeaf = workspace.getLeaf("tab");                      // New tab
const splitLeaf = workspace.getLeaf("split");                  // Split pane

// Open file
await workspace.openLinkText("file.md", "", false);            // Open in current tab
await workspace.openLinkText("file.md", "", true);             // Open in new tab
const leaf = workspace.getLeaf("tab");
await leaf.openFile(file);

// Reveal
workspace.revealLeaf(leaf);
```

## Events

```ts
// Vault events
this.registerEvent(this.app.vault.on("create", (file) => { /* TAbstractFile */ }));
this.registerEvent(this.app.vault.on("modify", (file) => { /* TAbstractFile */ }));
this.registerEvent(this.app.vault.on("delete", (file) => { /* TAbstractFile */ }));
this.registerEvent(this.app.vault.on("rename", (file, oldPath) => { /* TAbstractFile, string */ }));

// Workspace events
this.registerEvent(this.app.workspace.on("file-open", (file) => { /* TFile | null */ }));
this.registerEvent(this.app.workspace.on("active-leaf-change", (leaf) => { /* WorkspaceLeaf | null */ }));
this.registerEvent(this.app.workspace.on("layout-change", () => { /* layout changed */ }));
this.registerEvent(this.app.workspace.on("editor-change", (editor, info) => { /* Editor, MarkdownView */ }));

// MetadataCache events
this.registerEvent(this.app.metadataCache.on("changed", (file) => { /* TFile */ }));
this.registerEvent(this.app.metadataCache.on("resolved", () => { /* all files resolved */ }));

// DOM events (auto-cleaned on unload)
this.registerDomEvent(document, "click", (evt: MouseEvent) => { /* ... */ });

// Intervals (auto-cleaned on unload)
this.registerInterval(window.setInterval(() => { /* ... */ }, 5 * 60 * 1000));
```

## MetadataCache

```ts
const { metadataCache } = this.app;

// Get cached metadata for a file
const cache = metadataCache.getFileCache(file);
if (cache) {
  cache.frontmatter;     // Record<string, any> | undefined
  cache.headings;        // HeadingCache[] | undefined
  cache.links;           // LinkCache[] | undefined
  cache.tags;            // TagCache[] | undefined
  cache.sections;        // SectionCache[] | undefined
  cache.listItems;       // ListItemCache[] | undefined
}

// Resolve link to file
const resolved = metadataCache.getFirstLinkpathDest("link-text", "source/path.md");
```

## Network Requests

```ts
import { requestUrl, RequestUrlParam } from "obsidian";

// Use requestUrl instead of fetch for mobile compatibility
const response = await requestUrl({
  url: "https://api.example.com/data",
  method: "GET",
  headers: { "Content-Type": "application/json" },
});
const data = response.json;

// POST
const postResponse = await requestUrl({
  url: "https://api.example.com/data",
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ key: "value" }),
});
```

## Obsidian Protocol Handler

```ts
// Register a custom URI handler: obsidian://my-action?param=value
this.registerObsidianProtocolHandler("my-action", (params) => {
  const value = params.param;  // ObsidianProtocolData is Record<string, string>
  // Handle the protocol action
});
```

## Utility Functions

```ts
import { normalizePath, moment } from "obsidian";

// Normalize file paths (handles slashes, removes leading/trailing whitespace)
const path = normalizePath(userInput);

// moment.js is bundled with Obsidian
const now = moment().format("YYYY-MM-DD");

// Debounce (from obsidian module)
import { debounce } from "obsidian";
const debouncedSave = debounce((data: string) => this.saveData(data), 1000, true);

// Platform detection
import { Platform } from "obsidian";
if (Platform.isMobile) { /* ... */ }
if (Platform.isDesktop) { /* ... */ }
if (Platform.isMacOS) { /* ... */ }
```
