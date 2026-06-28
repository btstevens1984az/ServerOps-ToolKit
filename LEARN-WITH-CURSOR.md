# Learn to build infra GUIs with Cursor

This guide mirrors how we built **ServerOps Toolkit** and how you should prompt Cursor on your next features.

---

## Step 1: Start with intent, not code

**Bad prompt:**
> "Make a GUI"

**Good prompt (what you sent):**
> "I want to learn how to build cool GUIs for a Server/Infrastructure team. Design something for Windows servers and a PowerShell multi-purpose tool, and walk me through asking Cursor to build it."

Include:

| Piece | Example |
|-------|---------|
| **Audience** | Server / infra team |
| **Platform** | Windows Server, PowerShell |
| **Goal** | Learn + ship something useful |
| **Constraint** | Walk me through the process |

Cursor used that to pick **PowerShell + WPF** (native on Windows, no extra install for the GUI framework).

---

## Step 2: Let Cursor design v1, then narrow

After the first build, iterate in **small slices**. One tab or one button per prompt.

**Example follow-ups:**

```
Add a Services tab that lists Windows services on the connected server,
with Start / Stop / Restart buttons and a filter box.
```

```
On the Health tab, show disk free space as a colored bar:
green > 20%, yellow 10–20%, red < 10%.
```

```
Extract the remote disk query into ServerOpsToolkit.psm1 as Get-ServerDiskHealth.
```

---

## Step 3: Use @ references in Cursor

When editing, **@-mention files** so the model sees real code:

- `@Launch-ServerOpsToolkit.ps1` — event handlers and wiring
- `@ui/MainWindow.xaml` — layout and styles
- `@src/ServerOpsToolkit.psm1` — remote logic

**Example:**

```
In @src/ServerOpsToolkit.psm1, add Get-ServerPendingReboot that checks
PendingFileRenameOperations and CBS reboot flags. Surface it on the
Dashboard tab in @Launch-ServerOpsToolkit.ps1.
```

---

## Step 4: Add a project rule (already included)

We added `.cursor/rules/powershell-wpf.mdc`. It tells Cursor:

- Use WPF + XAML, not WinForms
- Keep remote logic in `.psm1`, UI in XAML, glue in the launcher
- Prefer CIM over deprecated WMI where possible

**You can extend it:** Cursor → Settings → Rules, or ask:

```
Add a rule: all new tabs must use the same card style as the Dashboard.
```

---

## Step 5: Debug with Cursor like a teammate

Paste errors verbatim:

```
When I click Connect on WEB01 I get:
"WinRM cannot complete the operation. Verify that the specified computer name is valid."

Server is reachable via ping. What should I check and what code change
handles this more clearly in the UI?
```

Cursor will suggest WinRM enablement, firewall, and clearer error text in the app.

---

## Step 6: Prompt patterns that work for infra GUIs

### New screen
```
Add a [name] tab to ServerOps Toolkit that [user action].
Data from [cmdlet/API]. Match styling in MainWindow.xaml.
Handle offline server with a message in the status bar.
```

### Refactor
```
Move all CIM calls from Launch-ServerOpsToolkit.ps1 into
ServerOpsToolkit.psm1. Launcher should only wire buttons to module functions.
```

### Polish
```
Improve the Health tab layout: two columns on wide windows,
loading spinner while CIM queries run, disable buttons until connected.
```

### Learning
```
Explain how Launch-ServerOpsToolkit.ps1 loads XAML and attaches
button click handlers. Use comments in the file for a beginner.
```

---

## Step 7: Your homework (try these in order)

1. Run the app on a Windows VM and connect to `localhost`.
2. Ask Cursor: *"Add a Copy Output button on the Command Runner tab."*
3. Ask Cursor: *"Add a README section on enabling WinRM for workgroup servers."*
4. Ask Cursor: *"Add a second server compare view on the Health tab."*
5. Create a **Cursor Rule** for your org: allowed servers, naming, no `Format-Table` in GUI output.

---

## Why PowerShell + WPF for infra teams?

| Approach | Pros | Cons |
|----------|------|------|
| **PowerShell + WPF** | No install for ops; uses skills they have; CIM/remoting built-in | Windows-only UI |
| **Electron + REST** | Pretty, cross-platform | Extra stack; needs an API layer |
| **PowerShell Universal** | Web dashboards, auth | License / server to host |

For a first learning project on Windows Server, WPF is the sweet spot: you edit XAML for looks and PowerShell for server logic.

---

## Conversation you can reuse

Copy-paste this starter for your next project:

```
I'm on an infrastructure team. Design and build a PowerShell WPF tool for
[specific task]. Requirements:
- Target Windows Server 2019+
- Tabs: [list]
- Remote via CIM/WinRM
- Clear errors when server is unreachable
- Put UI in XAML, logic in a .psm1 module
- Include a short LEARN-WITH-CURSOR.md for how you built it

Start with an MVP I can run with Launch-*.ps1, then suggest 3 follow-up features.
```

That is the same shape of request that produced this repo.
