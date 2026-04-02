# AXISBlueprint — Architecture

## Overview

AXISBlueprint is a macOS menu bar app that wraps Claude Code CLI, providing a native UI for context-native AI-assisted development. The paradigm is inverted from traditional IDEs: **Claude is the center, everything lives around it**.

## Design Philosophy

> *"Working with AI is managing context."*

AXISBlueprint gives both the user and Claude control over the context window through surgical trimming, real-time context tracking, and a skills system that wraps MCP tools in natural-language interfaces.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        macOS Menu Bar                           │
│                    (NSStatusItem, brain icon)                   │
│                          ⌘+Space                                │
└──────────────────────────────┬──────────────────────────────────┘
                               │ click / hotkey
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                        NSPopover (480×640)                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  PopoverContentView (SwiftUI)                            │  │
│  │  ├── TabBar: Chat | Map | History | Skills               │  │
│  │  └── TabView (selectedTab)                               │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│  Chat Tab   │       │  Map Tab    │       │ History Tab │
│  (Primary)  │       │             │       │             │
└──────┬──────┘       └─────────────┘       └─────────────┘
       │
       │ User composes message
       ▼
┌─────────────────────────────────────────────────────────────────┐
│                  ClaudeCodeService (Actor)                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Process: /usr/local/bin/claude code --no-input          │   │
│  │ stdin  ◄── message                                      │   │
│  │ stdout ──► streaming events                            │   │
│  └─────────────────────────────────────────────────────────┘   │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
           ┌─────────────┐       ┌─────────────────┐
           │ Tool Call   │       │ Streaming Text  │
           │ (MCP)       │       │ (character-by-  │
           │             │       │  character)     │
           └──────┬──────┘       └────────┬────────┘
                  │                       │
                  ▼                       ▼
           ┌─────────────┐       ┌─────────────────┐
           │ axisblueprint_│     │ ChatView        │
           │ read/write/  │     │ (live update)   │
           │ search/trim  │     │                 │
           └─────────────┘       └─────────────────┘
```

---

## Core Data Flow

### Message → Claude → Response

```
1.  User types message in ComposeView
2.  Message sent to ClaudeCodeService (via stdin)
3.  Claude Code process streams output (SSE-like over stdout)
4.  ClaudeCodeService parses events:
      - streaming text → ChatView (character-by-character)
      - tool_call → ToolCall rendered inline
      - tool_result → fed back to Claude via stdin
5.  ContextManager tracks token usage in real-time
6.  ChatStorage saves message on every user send
7.  ContextRingView updates with new totals
```

### Context Trimming Flow

```
1.  ContextManager.snapshot() called after each message
2.  If total > 150k → warning in ContextRing
3.  If total > 180k → trim suggested
4.  User clicks trim → Tombstone created for target messages
5.  Tombstones preserve conversation continuity
6.  Actual context removed from Claude's view
```

### Skills System Flow

```
1.  User or Claude invokes a skill (e.g., "Handoff")
2.  SkillRunner loads skill definition from ~/.axisblueprint/skills/<name>.md
3.  Skill wrapped as MCP tool response → fed to Claude
4.  Result returned as tool_result to Claude
5.  Chat updated with skill invocation
```

---

## Module Overview

### App Layer
| File | Responsibility |
|------|---------------|
| `AxisBlueprintApp.swift` | `@main` entry point, NSApplication bootstrap |
| `AppDelegate.swift` | NSStatusItem setup, NSPopover creation, ⌘+Space hotkey registration |
| `PopoverContentView.swift` | Root SwiftUI view, tab navigation, dark theme |

### Core Layer
| File | Responsibility |
|------|---------------|
| `ClaudeCodeService.swift` | Process lifecycle, stdin/stdout, SSE parsing, tool call handling |
| `ContextManager.swift` | Token estimation, threshold warnings, trim suggestions, tombstones |
| `ChatStorage.swift` | File-based persistence (`~/.axisblueprint/chats/`), manifest + messages |

### Features (R2+)
- **Chat** — ChatView, MessageBubbleView, ComposeView, ContextRingView
- **Map** — MapView (Canvas-based graph), NodeView, PhysicsSimulation
- **History** — HistoryView, ChatSearch
- **Skills** — SkillsView, SkillEditorView
- **Guardian** — GuardianService (Haiku-based proactive correction)

---

## Context Model

```
┌─────────────────────────────────────────────────────────────────┐
│                        Context Window                           │
│                    (200k token limit)                          │
├─────────────────────────────────────────────────────────────────┤
│  App Prompt           ████░░░░░░░░░░░░░░░  ~2k tokens           │
│  Global MD           ████░░░░░░░░░░░░░░░  variable               │
│  Project MD          ████░░░░░░░░░░░░░░░  variable               │
│  Memory Files        ████░░░░░░░░░░░░░░░  variable               │
│  Skills              ████░░░░░░░░░░░░░░░  variable               │
│  Agents              ████░░░░░░░░░░░░░░░  variable               │
│  Conversation        ████████████████░░  grows each turn        │
├─────────────────────────────────────────────────────────────────┤
│  Total tokens:  X / 200k  [████████░░░░░░░░░░] 43%                │
└─────────────────────────────────────────────────────────────────┘

Threshold markers:
  150k — Warning (yellow)
  180k — Trim suggested (orange)
  195k — Auto-trim imminent (red)
  200k — Hard limit (Claude max)
```

---

## Security Model

### API Key
- Stored in macOS Keychain, never written to disk in plaintext
- Retrieved at session start, passed via environment to Claude Code
- Never logged, never displayed in Streamer Mode

### No Telemetry
- Zero analytics, zero phone-home
- All context processing is on-device
- Chat storage is user-controlled (`~/.axisblueprint/chats/`)

### Streamer Mode
- When enabled, API keys, tokens, emails, and usernames are redacted from all UI
- Affects both chat view and side panels in real-time

### Encrypted Storage (R2+)
- Chats can optionally be saved to an encrypted disk image or Keychain-protected folder

---

## Process Model

### Claude Code Process
- Single `claude code` subprocess per session
- Communicates via:
  - **stdin** — user messages, tool results
  - **stdout** — streaming text, tool calls, status events
  - **stderr** — error logs (captured for debugging, not shown to user)
- Process is long-lived: survives across multiple turns
- Stop button terminates the process and starts a fresh one (via Handoff to preserve context)

### Stop-Safe Architecture
```
Problem: Claude Code's stop button creates a new process with no context.

Solution:
  1. Before stopping, run Handoff skill
  2. Handoff transfers full context to a new chat
  3. New process continues from where the old one left off
  4. User picks up in the new chat with full history intact
```

---

## Dependencies

### External (installed separately)
- **Claude Code CLI** — invoked via `Process`, must be in PATH
- **faster-whisper** (R2+) — local speech-to-text
- **Haiku** (R2+) — lightweight model for transcription correction and Guardian

### No SPM for R1
The core app has zero Swift Package Manager dependencies. Claude Code CLI is the sole external dependency. This keeps the build lean and avoids dependency conflicts with Claude Code's own package resolution.

---

## File Structure (R1)

```
AXISBlueprint/
├── project.yml                    # XcodeGen configuration
├── Sources/
│   ├── App/
│   │   ├── AxisBlueprintApp.swift # @main entry point
│   │   ├── AppDelegate.swift       # NSApplication setup, menu bar
│   │   └── PopoverContentView.swift # Root SwiftUI view
│   └── Core/
│       ├── ClaudeCodeService.swift  # CLI process wrapper
│       ├── ContextManager.swift      # Token tracking & trimming
│       └── ChatStorage.swift         # File-based persistence
└── ARCHITECTURE.md               # This document
```

R2 will expand to the full structure documented in SPEC.md:
- Features/ (Chat, Map, History, Skills, Guardian, Agents)
- Services/ (Whisper, Haiku, LivePreview, Notifications)
- Models/, Theme/, Utilities/

---

## Key Design Decisions

1. **Actor-based service** — `ClaudeCodeService` is a Swift actor, making it thread-safe for concurrent message sends and streaming receives.

2. **File-per-message storage** — Each chat message is a separate JSON file inside the chat folder. This enables surgical deletion without rewriting entire chat histories.

3. **Character-based token estimation** — For R1, tokens are approximated as `char_count × 0.25`. This is sufficient for context ring display. R2 will integrate `cl100k_base` encoding for accuracy.

4. **Transient popover** — The popover uses `.transient` behavior (closes when clicking outside). This respects the menu bar paradigm and avoids the app "hanging around" like a window would.

5. **MCP tools as skills** — Skills are the user-facing layer; MCP is the protocol layer. This mirrors how Valo works and keeps the UX natural.
