# Axis — Specification

**Type:** macOS Menu Bar App  
**Core:** Context and project manager built around Claude Code. AI is the center; everything lives around it.  
**Reference:** Valo AI (@Valo-AI YouTube channel) — same feature set, native macOS quality  
**Design bar:** ChatGPT app / Apple / Google / Claude / Raycast — high quality, polished, native
**Light + dark mode:** System preference by default; manual toggle in settings  
**Platform:** macOS (menu bar popover + optional window)  
**Stack:** SwiftUI + Claude Code CLI + MCP + Haiku  

---

## 1. Concept & Vision

Axis is a **context-native coding environment** — not an IDE with AI bolted on, but an AI workspace with code-editing capabilities. The paradigm is inverted: Claude is the center, and all tools (file tree, terminal, map, agents, skills) exist to help Claude manage context and build software.

The feeling: **a professional cockpit for AI-assisted development.** Clean, focused, powerful. Every pixel earns its place. Nothing decorative that doesn't serve the workflow.

Core philosophy: *"Working with AI is managing context."*

---

## 2. Design Language

### Aesthetic Direction
**Reference:** Raycast + Apple Intelligence app — clean dark surfaces, subtle depth, precise typography, purposeful whitespace. Not minimalism for its own sake — every element has a job.

### Color Palette
```
Background:       #0A0A0C (near-black, slightly cool)
Surface:          #161619 (elevated surface)
SurfaceElevated:  #1E1E22 (cards, panels)
Border:           #2C2C30 (subtle dividers)
TextPrimary:      #FAFAFA (crisp white)
TextSecondary:    #8E8E93 (muted)
TextTertiary:     #5C5C60 (disabled/hints)
Accent:           #4B9EFF (electric blue — primary action)
AccentSecondary:  #7B61FF (purple — AI/agents)
Success:          #30D158 (green — success, connected)
Warning:          #FFD60A (gold — caution)
Destructive:      #FF453A (red — delete, error)
```

### Typography
```
Display:    SF Pro Display, 28pt, semibold  (app name, large headers)
Title:      SF Pro Display, 20pt, semibold  (section headers)
Headline:   SF Pro Text, 16pt, medium       (card titles)
Body:       SF Pro Text, 14pt, regular     (standard text)
Caption:    SF Pro Text, 12pt, regular     (secondary info)
Mono:       SF Mono, 13pt, regular         (code, paths, terminal)
```

All text uses the system font stack (SF Pro via `.font()`). No custom font loading.

### Spatial System
```
4pt base unit
Spacing scale: 4, 8, 12, 16, 20, 24, 32, 40, 48
Corner radius: 8 (small), 12 (medium), 16 (large), 24 (cards)
```

### Motion Philosophy
- **Functional first:** animations communicate state changes, not decoration
- **Fast:** 150-250ms for micro-interactions
- **Reduce Motion compliant:** all animations respect `accessibilityReduceMotion`
- **Spring-based:** `SwiftUI.animation(.spring(response: 0.25, dampingFraction: 0.8))` for UI transitions
- No `withAnimation(.linear)` anywhere in production UI

### Visual Assets
- **Icons:** SF Symbols exclusively — `brain.head.profile`, `map`, `terminal`, `gear`, `bell`, `magnifyingglass`, `trash`, `arrow.right`
- **No emoji** in production UI
- **Code highlighting:** use system SwiftUI `Text` with syntax-colored inlays, or native code editor component
- **Map nodes:** custom drawn with SwiftUI shapes — circles for files, lines for connections

---

## 3. Layout & Structure

### Menu Bar App
- Status bar icon: brain + subtle glow when active
- Click: popover appears (480×640 default)
- Popover has three zones:
  1. **Header bar** — project name, chat name, settings gear
  2. **Main area** — tabbed: Chat | Map | History | Skills
  3. **Context ring** — collapsible strip at bottom showing context usage

### Tab: Chat (Primary)
```
┌─────────────────────────────────────┐
│ ● AXISBLUEPRINT     [project]  [⚙] │  ← header
├─────────────────────────────────────┤
│                                     │
│  [Claude messages + tool output]     │  ← scrollable
│                                     │
│  ─────────────────────────────────  │
│  [User input area]           [⏎]   │  ← compose
├─────────────────────────────────────┤
│ Tokens: 2.1k / 200k  [ring strip]  │  ← context ring
└─────────────────────────────────────┘
```

### Tab: Map
```
┌─────────────────────────────────────┐
│ Project Map           [◉] [▢] [⚙]  │
├─────────────────────────────────────┤
│                                     │
│   ○ file1.swift ────○ file2.swift  │
│        │                    │       │
│   ○ file3.swift ────○ file4.swift  │
│                                     │
│  [node size = line count]            │
└─────────────────────────────────────┘
```

### Tab: History
```
┌─────────────────────────────────────┐
│ Chat History          [search 🔍]    │
├─────────────────────────────────────┤
│ Today                               │
│  ▸ Belief mapper      12:04  234☐ │
│  ▸ Auth flow           11:22  89☐  │
│ Yesterday                           │
│  ▸ API refactor        18:44  412☐ │
└─────────────────────────────────────┘
```

### Tab: Skills
```
┌─────────────────────────────────────┐
│ Skills                  [+ New]      │
├─────────────────────────────────────┤
│ ● Handoff             MCP tool      │
│ ● Remember            MCP tool      │
│ ● Context Trim       MCP tool       │
│ ● Guardian            MCP tool       │
│ ● Code Review         Agent          │
│ ● Researcher          Agent          │
└─────────────────────────────────────┘
```

### Window Mode (optional)
- Can expand popover to a floating window (800×700)
- Window has toolbar: tabs, project picker, context usage, settings
- Window can be pinned always-on-top

---

## 4. Features & Interactions

### 4.1 Chat Interface

**Compose area:**
- Multi-line text input, auto-expanding up to 6 lines
- `⌘↵` to send
- Voice input button (microphone icon)
- Attachment button (screenshot, file)
- Max turns indicator (when autonomous mode is set)

**Message display:**
- User messages: right-aligned, accent background
- Claude messages: left-aligned, surface background
- Tool outputs: mono font, collapsible, syntax highlighted
- Thinking block: collapsed by default, expandable
- Streaming: text appears character-by-character with cursor

**Interactions:**
- Hover on message → show: copy, delete, trim context, create skill
- Click on code block → copy button appears
- Right-click on message → context menu (copy, delete, handoff)

### 4.2 Context Ring

Collapsible bar at bottom of chat showing real-time context breakdown:
- App prompt: `Xk`
- Global MD: `Xk`
- Project MD: `Xk`
- Memory files: `Xk`
- Skills: `Xk`
- Agents: `Xk`
- Current conversation: `Xk`
- **Total: Xk / 200k**

Click to expand → detailed breakdown with per-file counts.

### 4.3 Surgical Context Trimming

**User-side:**
- Hover message → delete button (trash icon)
- Deleted messages show as tombstone: `This message was trimmed to save context`
- Tombstones preserve conversation continuity for Claude

**Claude-side:**
- Claude can call `trim_context` MCP tool
- Tool removes 70-90% of tool call bloat while preserving conversation meaning
- Result shown as tombstone in chat

**Why better than compaction:**
- No waiting for automatic compaction
- No shaping the conversation at the end
- Real-time trimming, conversation continues seamlessly
- Preserves the spirit and meaning better than handoffs

### 4.4 The Guardian

**Purpose:** Claude frequently tells users "I can't do X" even when it has MCP tools for X. Guardian fixes this proactively.

**How it works:**
1. Haiku reads Claude's last message (lightweight, ~$0.001)
2. Pattern-matches against a list of "false modesty" phrases
3. If match → fires a reminder to Claude: "You have access to [tool name] — use it directly"
4. After 2-3 reminders, Claude stops the behavior for the session

**Guardian rule format** (natural language in `.md` file):
```
If Claude says:
- "I can't access the web" → Remind: you have val_web via MCP
- "I can't check console logs" → Remind: you have terminal access
- "I don't have access to files" → Remind: you can read/write files
```

**Custom rules:** User can add rules by editing `guardian.md`

### 4.5 Project Map

**Visual graph of codebase:**
- Nodes = files, sized by line count
- Edges = import/dependency connections
- Color = file type (Swift=blue, MD=purple, JSON=gray, etc.)

**Interactions:**
- Click node → opens file in right panel
- Double-click → Claude focuses on that file
- Drag to rearrange nodes
- Scroll to zoom
- Nodes pulse when Claude is reading/writing them (real-time)

**vs File Tree:**
- File tree shows structure but not relationships
- Map shows how files actually connect
- Makes it obvious when a project is one 2000-line blob

**Implementation:** SwiftUI Canvas with custom node rendering. Physics simulation for auto-layout.

### 4.6 Skills System

**What is a skill:**
- An MCP tool wrapped in a natural-language interface
- Written as a `.md` file in `~/.axisblueprint/skills/`
- Claude invokes it by name

**Built-in skills:**
1. **Handoff** — transfers entire context to a new chat. Claude names the chat. User reviews and sends.
2. **Remember** — semantic search across all saved chats. "Remember when we talked about X"
3. **Context Trim** — calls the trim_context MCP tool
4. **Guardian** — manages the guardian rules

**Creating a skill:**
```markdown
# Skill: Code Review

You are a code reviewer. When I invoke you:
1. Read the changed files
2. Find potential bugs, style issues, security concerns
3. Present findings in a numbered list
4. Rate severity: High/Medium/Low
```

### 4.7 Agents System

**Agents** are sub-processes that run in background:

**Code Reviewer Agent:**
- Runs after every commit or on-demand
- Reviews changed files
- Posts findings to chat as a message
- Notifies when done (unlike Claude Code which promises and doesn't deliver)

**Researcher Agent:**
- Finds edge cases and missing test coverage
- Runs in parallel with Code Reviewer
- "Light pipeline" = both run together

**Custom agents:** Written in natural language, stored as `.md` files.

### 4.8 Voice Input

**Pipeline:**
1. `faster-whisper` — local speech-to-text (fast, accurate)
2. `Haiku` — "translates" transcript: corrects code terms ("tool tip" → "toolTip"), handles accents
3. Result → Claude with full codebase context

**Why better than Super Whisper:**
- Super Whisper uses ChatGPT — no codebase context
- Haiku correction understands code terminology
- All local — no cloud dependency

### 4.9 Background / Autonomous Mode

Claude can be set to run autonomously with:
- **Max turns** — stop after N iterations
- **Custom interval** — e.g., every 5 minutes
- **Jitter** — add randomness so it doesn't look bot-like
- **Custom prompt** — the instruction to repeat

This is a "cron job without the cron language" — a prompt on a timer.

### 4.10 Live Preview

- Shows rendered app/website without `localhost`
- No server restarts
- Updates as Claude writes code
- Useful for UI work

### 4.11 Stop-Safe Architecture

**The Problem:** Claude Code's stop button creates a new process with amnesia — context is lost.

**Axis Fix:**
1. Before stopping, detect if Claude is in a new process (no context)
2. Offer to run Handoff skill before stopping
3. Context is transferred to new chat, user continues from where they left off

### 4.12 Chat History & Memory

**Storage:**
- All chats saved to `~/.axisblueprint/chats/`
- Each chat = a folder with `manifest.json` + message files
- Searchable by title, full-text, semantic

**vs Git:**
- Git = codebase backup
- Chats = work session backup
- When something breaks → find the working chat and pick up

**Memory files:**
- `.md` files loaded into context on every chat
- Global (all projects) or project-specific
- Written by user or by Claude (with permission)

### 4.13 Permissions & Security

**Granular per-task permissions:**
- VS Code's "allow for session" only allows reading ONE file
- Axis allows per-task: run this task without prompting

**Streamer mode:**
- Hides API keys, tokens, usernames during screen recording
- Redacts in real-time in both chat and right panel

**Encrypted chats:**
- Can save to encrypted disk image or Keychain-protected folder

---

## 5. Component Inventory

### StatusBarController
- NSStatusItem with brain icon
- Click → toggle popover
- Badge when Claude is thinking/working

### PopoverView
- Main container, 480×640 default
- Drag to resize
- Three toolbar buttons: Chat | Map | History | Skills

### ChatView
- ScrollView with LazyVStack of messages
- ComposeView at bottom (auto-expanding TextEditor + send button)
- ContextRingView at very bottom (collapsible)

### MessageBubbleView
States: user | claude | tool | thinking | tombstone
- Hover: show action buttons (copy, delete, more)
- Tool output: mono, collapsible, syntax highlighted

### ComposeView
- Auto-expanding TextEditor (1-6 lines)
- Send button (accent blue)
- Voice input button (mic icon)
- Attachment button (paperclip)
- Disabled state when Claude is streaming

### ContextRingView
- Horizontal strip showing context breakdown
- Total / limit bar
- Expand to see per-component breakdown

### MapView
- SwiftUI Canvas for rendering
- NodeView for each file (circle, sized by lines)
- EdgeView for connections (lines)
- Toolbar: layout options, zoom controls

### HistoryView
- List of saved chats grouped by date
- Search bar (title + full-text)
- ChatRowView: title, time, message count, token estimate

### SkillsView
- List of available skills
- Each row: icon, name, description, type badge (MCP | Agent | Custom)
- "+ New" button to create skill

### SettingsView
- Tabs: General | Context | Agents | Skills | Privacy
- Context tab: global MD editor, memory files, context limits
- Agents tab: enable/disable, configure prompts
- Privacy tab: streamer mode, encryption, API key

### Empty States
- No chats: "Start your first project" + large illustration
- No skills: "Skills extend Claude's abilities" + create button
- Empty map: "No project open" + open folder button

### Loading States
- Message streaming: cursor blink in message bubble
- Agent running: small pulsing dot indicator
- Map loading: skeleton circles in graph shape

### Error States
- API key missing: full-screen prompt to enter key
- Network error: inline banner with retry
- Claude crashed: "Claude stopped responding" + recovery options

---

## 6. Technical Approach

### Architecture
```
Axis/
├── App/
│   ├── AxisApp.swift      # @main, App lifecycle
│   ├── AppDelegate.swift            # NSApplication setup, menu bar
│   ├── StatusBarController.swift   # NSStatusItem management
│   └── PopoverContentView.swift    # Main popover root
├── Core/
│   ├── ClaudeCodeService.swift      # Claude Code CLI wrapper
│   ├── MCPClient.swift              # MCP protocol client
│   ├── ContextManager.swift         # Token counting, trimming
│   ├── ChatStorage.swift            # File-based chat persistence
│   └── SkillRunner.swift            # Skill invocation
├── Features/
│   ├── Chat/
│   │   ├── ChatView.swift
│   │   ├── MessageBubbleView.swift
│   │   ├── ComposeView.swift
│   │   └── ContextRingView.swift
│   ├── Map/
│   │   ├── MapView.swift
│   │   ├── NodeView.swift
│   │   └── PhysicsSimulation.swift
│   ├── History/
│   │   ├── HistoryView.swift
│   │   └── ChatSearch.swift
│   ├── Skills/
│   │   ├── SkillsView.swift
│   │   └── SkillEditorView.swift
│   ├── Guardian/
│   │   └── GuardianService.swift
│   └── Agents/
│       ├── CodeReviewerAgent.swift
│       └── ResearcherAgent.swift
├── Services/
│   ├── WhisperService.swift         # faster-whisper integration
│   ├── HaikuTranslationService.swift
│   ├── LivePreviewService.swift
│   └── NotificationService.swift
├── Models/
│   ├── Chat.swift
│   ├── Message.swift
│   ├── Skill.swift
│   ├── Agent.swift
│   └── ContextMetrics.swift
├── Theme/
│   ├── Colors.swift
│   ├── Typography.swift
│   └── Spacing.swift
└── Utilities/
    ├── TokenCounter.swift
    └── KeyboardShortcuts.swift
```

### Dependencies
- **Claude Code CLI** — user's existing installation, invoked via Process
- **faster-whisper** — via Python subprocess or local HTTP server
- **Haiku** — via Anthropic API (lightweight, cheap)
- **No Swift Package Manager dependencies** for core app (keep it lean)

### MCP Integration
Axis exposes its own MCP tools to Claude Code:
- `axisblueprint_read` — read file with context
- `axisblueprint_write` — write file
- `axisblueprint_edit` — edit file
- `axisblueprint_search` — grep/search
- `axisblueprint_trim_context` — surgical context trimming
- `axisblueprint_handoff` — create new chat with context
- `axisblueprint_notify` — send notification
- `axisblueprint_run_agent` — spawn background agent

### Data Flow
1. User types message → ComposeView
2. ComposeView → ClaudeCodeService (via stdin/stdout)
3. Claude Code responds → MCP calls → Axis handles
4. Response streamed to ChatView (character by character)
5. Tool outputs rendered inline
6. Context ring updates in real-time
7. Chat saved to disk on every user message

### Context Management
- Token counting via local estimation (cl100k_base equivalent)
- Warning at 150k / 200k limit
- Trim suggestion at 180k
- Auto-trim at 195k (oldest tool calls first)

### Build Target
- macOS 15.0+
- Swift 6
- SwiftUI
- No Catalyst, no cross-platform

---

## 7. Privacy & Security

- **API key:** stored in Keychain, never logged
- **Chat storage:** user-controlled location (default `~/.axisblueprint/chats/`)
- **Streamer mode:** redact API keys, tokens, emails from all UI
- **No telemetry:** zero analytics, zero phone home
- **Local-first:** all context processing on-device

---

## 8. Out of Scope (R1)

These are planned for future rounds but NOT in R1:
- Real-time multi-user collaboration
- Cloud sync
- iOS companion app
- Plugin marketplace
- Custom model selection (beyond Claude)

---

## R2 Features (current)

- [x] Light + dark mode (system preference, manual toggle)
- [x] MCP server (stdio JSON-RPC 2.0, exposes tools to Claude Code)
- [x] Skills system (natural language, ~/.axis/skills/*.md)
- [x] Guardian (proactive Claude self-correction)
- [x] Project Map (force-directed graph, SwiftUI Canvas)
- [x] File indexer (dependencies via import parsing)
- [x] Context trimming UI (per-message delete, tombstones)
- [x] Background agents (Code Reviewer, Researcher)
- [x] Notification service (UNUserNotificationCenter)
- [x] Settings panel (theme, context, privacy)
- [x] History tab (search, group by date, swipe delete)
- [x] Skills panel (create, edit, invoke, toggle)

## R3+ Planned

- Voice input (faster-whisper + Haiku pipeline)
- Live preview (browser without localhost)
- Stop-safe architecture (handoff before stopping)
- Encrypted chat storage
- iOS companion
