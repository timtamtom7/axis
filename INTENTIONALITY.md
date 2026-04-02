# INTENTIONALITY.md — Why AXISBlueprint is Built This Way

This document explains the **why** behind every R1 feature decision.
Not just what we built — but what we deliberately chose NOT to build,
and why R2 addresses those gaps.

Philosophy: *"Working with AI is managing context."* Every feature
exists because context management demands it. Nothing is decorative.

---

## 1. Chat Interface

### Why it exists
The chat UI is AXISBlueprint's primary interface. It's where the user
and Claude spend 95% of their time. Everything else (map, skills,
history) is in service of making that conversation more effective.

The inversion of the IDE paradigm matters: Claude is the center.
Tools exist to help Claude manage context, not the other way around.

### Intentional design choices

**Message type taxonomy (5 types: user / claude / tool / thinking / tombstone)**
We distinguish message types because each carries fundamentally different
intent:
- User = the human's goal and context
- Claude = the AI's response and reasoning
- Tool = structured output that is not prose (mono font, collapsible)
- Thinking = Claude's internal reasoning (always collapsed by default —
  showing it by default adds noise and slows comprehension)
- Tombstone = surgically trimmed content (preserved for conversation
  continuity; Claude sees it and understands why context was removed)

Treating all output as "text" loses the semantic meaning of the medium.

**Right-aligned user messages, left-aligned Claude messages**
Standard conversational convention. Users scan their own messages
(right side, accent color) differently from Claude's responses (left side,
neutral). This spatial encoding reduces cognitive load.

**Hover reveals actions (copy / delete / trim)**
Actions are contextual and secondary. Showing them by default would
clutter the interface. Hover makes them discoverable without permanence.

**Blinking cursor for streaming**
The cursor signals "I'm still alive" during long generations. It's not
decorative — it manages the user's anxiety about whether Claude is stuck.

**Auto-scroll respects manual scroll position**
If a user scrolls up to review context, we don't yank them back to bottom
when a new message arrives. This is a common UX failure in chat apps.
We track the user's scroll intent and only auto-scroll when they're
already at the bottom.

### What we explicitly did NOT do in R1 (and why)
- **Message reactions** (👍 👎) — adds noise to the conversation stream,
  no clear use case in a coding context
- **Quote/reply threading** — adds visual complexity and implies a
  conversational model (reply chains) that doesn't match Claude Code's
  flat message format
- **Edit a sent message** — technically possible but introduces ambiguity
  about which version Claude saw; surgical trim + resend is cleaner
- **Markdown rendering in user messages** — user intent is clear prose;
  rendering markdown would alter what they typed

### What R2 adds
- Message editing (edited messages marked with "edited" timestamp)
- Reply/quote pinning (reference a specific message without threading)
- Read receipts (did Claude see my last message?)

---

## 2. Compose View

### Why it exists
The input is the primary user action. Every millisecond of friction
between thought and Claude's response degrades the flow state.

### Intentional design choices

**⌘↵ to send (Enter = newline)**
Terminal convention. Developers use ⌘↵ instinctively. Enter alone
adding a newline is correct for multi-line inputs (code snippets,
long prompts). This is a deliberate departure from messaging apps
where Enter = send.

**Disabled during streaming**
Claude Code's CLI processes messages as a stream. If a user sends
a message mid-stream, the response interleaving breaks the output.
Blocking the send button is the clearest possible signal that streaming
is in progress — more visible than a subtle indicator.

**Auto-expanding 1–6 lines**
A single-line input forces users to fight the UI for multi-line input.
Auto-expansion up to 6 lines covers the 80% case (short to medium
prompts) without letting the compose area consume the entire chat.
Users can still scroll within the editor for longer inputs.

**Voice and attachment are wired stubs**
The pipeline exists: Voice → faster-whisper → Haiku → Claude.
Attachment → file picker → context injection. Both are architecturally
ready but the downstream services aren't integrated. Shipping stubs
prevents the UI from feeling broken while keeping R1 scope controlled.

### What we explicitly did NOT do in R1
- **Tab-to-complete** — adds dependency on a completion engine; future
  skill integration makes this more natural
- **Prompt templates** — better handled by the skills system (a "template
  skill" can be invoked naturally)
- **Character/token count in compose** — premature optimization; if
  long prompts become a problem, token counting is in the context ring

### What R2 adds
- Voice input (faster-whisper + Haiku pipeline)
- File/screenshot attachments
- Prompt history (↑ to recall previous prompts)

---

## 3. Context Ring

### Why it exists
The 200k token context window is AXISBlueprint's most critical resource.
Without visibility into token usage, users hit the ceiling without
warning — triggering automatic compaction that loses important context
mid-conversation.

Transparency is the antidote to surprise. The ring makes the invisible visible.

### Intentional design choices

**Ring + color (not a percentage number)**
A color-coded bar is faster to scan than a number. Green/yellow/red
communicates urgency faster than "73%" — and maps to a physical
metaphor (filling up) that users intuitively understand.

The exact number is still available: it's displayed in text next to
the bar, and the full breakdown is one tap away.

**Collapsed by default (32pt)**
The chat content is primary. The ring is a background monitor. Defaulting
to collapsed keeps the focus on conversation while making the ring
visible enough to catch peripheral attention. Users who care about
context will tap to expand; users in flow can ignore it.

**Per-component breakdown on tap**
Context isn't monolithic — it has sources (app prompt, MD files, memory,
skills, conversation). The breakdown shows where tokens came from so
users can make informed trimming decisions. "Delete the oldest message"
is a different action than "remove the project MD file from context."

**Real-time updates**
The ring updates on every Claude response. No polling, no lag. The
ContextManager notifies the view layer via Combine/observable.

### What we explicitly did NOT do in R1
- **Auto-trim suggestions** (toast notifications urging to trim) —
  intrusive to the conversation flow; the ring itself is the nudge
- **Per-message token counts in the chat** — would clutter the chat
  view; the breakdown panel covers this
- **Automatic trimming at 195k** — too aggressive for R1; user
  should drive trimming decisions; auto-trim is a Guardian/agent concern

### What R2 adds
- Auto-trim suggestion toasts at 180k tokens
- Per-message token counts (toggle in settings)
- Trim presets: "aggressive" vs "conservative"

---

## 4. Skills System

### Why it exists
MCP tools are powerful but low-level. A raw `trim_context` tool call
is not discoverable or intuitive. Skills wrap tools in natural language
so Claude (and the user) can invoke them conversationally.

The Skills system is the interface between Claude and AXISBlueprint's
capabilities. Without it, users would need to know implementation
details to use core features.

### Intentional design choices

**Skills are .md files**
Human-readable, editable, version-controllable. A skill isn't code —
it's a natural-language instruction set. Storing it as Markdown matches
how humans write and think about instructions.

**Built-in skills in R1: Handoff, Remember, Context Trim, Guardian**
These four solve the highest-frequency context management problems:
- **Handoff** — split context across chats without losing continuity
- **Remember** — semantic search across all chat history
- **Context Trim** — surgical reduction of tool call bloat
- **Guardian** — proactive correction of Claude's "I can't" behavior

**Claude invokes skills by name**
Claude sees skill names in context. It learns through interaction
which skill to call when. This is intentional — it feels more like
collaborating with an informed colleague than using a tool menu.

### What we explicitly did NOT do in R1
- **Skill marketplace / community skills** — security concern (prompt
  injection in shared skills); local-first approach for R1
- **Skill analytics** (which skills are used most) — premature;
  analytics add complexity and privacy considerations

### What R2 adds
- Custom skill editor (in-app .md editor with syntax highlighting)
- Skill invocation analytics
- Import/export skills

---

## 5. Surgical Context Trimming (vs Compaction vs Handoff)

### Why it's the most important feature
Context management is AXISBlueprint's core job. The context window
is finite. Without trimming, conversations either:
1. Hit the ceiling → forced compaction → lose important context
2. Stay short → lose valuable project history

Surgical trimming is the third path: remove the bloat without removing
the meaning.

### Intentional design choices

**Tombstones preserve conversation continuity**
A deleted message isn't simply gone — it's replaced with a tombstone
that says "trimmed to save context." Claude sees this and understands
why the conversation jumped. This is critical: Claude doesn't think
itself broken when context disappears.

**User-side and Claude-side trimming**
Both the user and Claude can initiate trimming. Users trim what they
see is bloated. Claude trims what it knows is verbose. This distributes
the context management burden.

**Trim tool calls, not conversation turns**
80% of context weight comes from tool call outputs, not from the
conversation itself. We trim tool outputs to summaries while preserving
the conversation turns intact. This is why surgical trimming achieves
70–90% context reduction while compaction achieves ~40%.

### What we explicitly did NOT do in R1
- **Automatic compaction at 195k** — too aggressive; forces a
  summary that may lose nuance; manual trim + handoff is preferred
- **One-click "optimize context"** — leaves too much agency with the
  machine; context decisions should be human-informed

### What R2 adds
- Trim presets (conservative / aggressive / tool-outputs-only)
- Scheduled auto-trim (trim every N messages regardless of token count)
- Trim history (what was trimmed, when, why)

---

## 6. The Guardian

### Why it exists
Claude Code's CLI was built before MCP tools existed. Claude frequently
tells users "I can't do X" even when it has MCP tools for X. This wastes
time (user explains what Claude can do) and breaks flow.

Guardian fixes this proactively. It watches Claude's output and
reminds Claude of abilities it forgot it has.

### Intentional design choices

**Haiku, not Sonnet/Opus, for pattern matching**
Guardian runs on every Claude response. Using a fast, cheap model
(Haiku) keeps the cost negligible (~$0.001/session). This isn't
reasoning — it's pattern matching. Haiku is the right tool.

**Natural language rules**
Guardian rules are written as "If Claude says: [pattern] → Remind: [ability]"
This is readable by non-technical users and editable via chat
("Claude, add a rule: if you say 'I can't use regex' → remind you have terminal access").

**User-editable rules**
guardian.md lives in ~/.axisblueprint/ and is user-editable.
No settings UI needed for rule management — editing a text file
is more powerful and transparent than a GUI.

### What we explicitly did NOT do in R1
- **Guardian rules UI** — text file is more powerful; a GUI would add
  complexity without adding capability
- **Automatic rule learning** (Claude adds its own patterns) — too
  risky for R1; rules could proliferate without oversight

### What R2 adds
- In-app guardian rule editor
- Guardian activity log (what reminders fired, when)
- Automatic rule suggestion (Claude notices it was reminded → offers to add permanent rule)

---

## 7. Project Map (R1 placeholder / stub)

### Why it's in R1 (as a stub)
The map is AXISBlueprint's most visually distinctive feature. It's
also the most complex to implement correctly (physics simulation,
real-time node updates). R1 ships the placeholder so the UI has
structural completeness and users understand where the feature
will live.

### What R1 actually ships
A stub MapView with empty state ("No project open"). The tab exists;
the feature doesn't.

### What R2 builds
- Canvas-based node rendering (SwiftUI Canvas + custom node shapes)
- File dependency graph extraction (via AST parsing or static analysis)
- Physics simulation for auto-layout (attraction/repulsion between nodes)
- Real-time node highlighting as Claude reads/writes files
- Node size = line count, color = file type
- Click/double-click to open file in right panel

### What we explicitly did NOT do in R1 (and why)
- **File tree as fallback** — a file tree is the opposite of the map's
  purpose; it shows structure but not relationships; shipping a tree
  would feel like a regression from the SPEC's vision

---

## 8. History & Memory (R1 partial)

### What R1 ships
Chat history list with date grouping and title search. Chats are
saved to ~/.axisblueprint/chats/ as JSON. The "Remember" skill
does semantic search across history.

### Intentional design choices

**File-based storage (not a database)**
Chats as folders + JSON is:
- Human-readable (inspectable without tooling)
- Git-friendly (versionable, diffable)
- Simple (no SQLite, no migration logic)
- User-controllable (can move, rename, back up with standard tools)

**Semantic search via Remember skill**
Full-text search is in R1 ("search history for X"). Semantic search
("remember when we talked about X") is handled by the Remember skill
using the existing Claude context pipeline. No separate search index needed.

### What we explicitly did NOT do in R1
- **Full semantic search UI** — handled by Remember skill; a separate
  search interface would fragment the interaction model
- **Chat encryption** — R2 (Keychain-protected storage)
- **Export/import chats** — R2

### What R2 adds
- Encrypted chat storage
- Full semantic search UI
- Chat export (JSON, Markdown)
- Automatic chat naming based on content

---

## Summary: R1 Scope Rationale

| Feature | R1 Status | Reason |
|---|---|---|
| Chat UI | ✅ Complete | Core; must be excellent |
| Compose | ✅ Complete | Core; must be excellent |
| Context Ring | ✅ Complete | Core; transparent context management |
| Skills | ✅ Core skills | Must-haves for context management |
| Guardian | ✅ Core skills | Must-have for Claude behavior |
| Surgical Trim | ✅ Via skills | Integrated into chat interactions |
| History | ✅ Partial | File persistence + search; encryption R2 |
| Map | ⚠️ Stub | Too complex for R1; structural placeholder |
| Voice | ⚠️ Stub | faster-whisper not integrated |
| Agents | ⚠️ Stub | Background processes; R2 |
| Encrypted storage | ❌ R2 | Complexity trade-off |
| Live Preview | ❌ R2 | Separate service integration |
