# Valo AI — Mega Outline (from 9 YouTube Video Transcripts)

**Channel:** @Valo-AI | **Videos analyzed:** 9 | **Source:** youtube.com/@Valo-AI

---

## What Is Valo?

Valo is a **context and project manager built around Claude Code**. Unlike VS Code or Cursor (an IDE with AI bolted on), Valo inverts the paradigm: **the AI is the center, everything lives around it**. It manages Claude's context window, orchestrates agents, handles skills, and provides a visual project map — all in a macOS menu bar app.

**Core philosophy:** "Working with AI is managing context." Valo's entire feature set exists to solve the context window problem.

---

## Architecture

### Stack
- **macOS menu bar app** (status bar icon, popover UI)
- **Claude Code CLI** (`claude code`) — the core AI engine Valo wraps
- **MCP (Model Context Protocol)** tools — Valo's own tools exposed to Claude
- **Haiku** — small/fast model used for filtering, transcription, lightweight tasks
- **Claude** ( Sonnet 4/4.5?) — main coding model
- **Faster Whisper** — speech-to-text (better than Super Whisper because it has Claude context)
- **Local** model runs on-device for privacy-sensitive features

### Local vs Val MCP Tools
- **Local commands** — directly on the machine (no AI interpretation)
- **Val MCP tools** — go through MCP, potentially get interpreted by a model
- Valo wraps MCP tools in **Skills** for cleaner UX

---

## Core Features

---

### 1. Context Management (The Heart of Valo)

#### The Problem
Claude receives the entire conversation history every turn. As projects grow, this becomes:
- Slow (more tokens = slower responses)
- Expensive
- Hallucination-inducing (too much context)

Traditional solutions like **compaction** (automatic summarization) are described as "automatic and dumb" — they compact the entire conversation without user control, losing important context.

#### Valo's Solution: Surgical Context Trimming

Valo gives **both the user AND Claude** control over context trimming:

**User-side:**
- Delete messages from the chat (both UI and actual JSON context)
- Messages show as **tombstones** (e.g., "trimmed to save context") so Claude knows something was removed but understands why
- Trim entire message blocks (user's turn + Claude's thinking + tool calls) → replaced with a short summary

**Claude-side:**
- Claude can delete its own messages via an MCP tool
- Claude can **trim context surgically** — removes 70-90% of bloat from tool calls while preserving conversation meaning
- The trimming keeps the "spirit and meaning" of conversations in a way compaction and handoffs can't

**Key insight:** 80% of context weight comes from tool calls and code Claude read, NOT from the conversation itself. Valo trims tool call outputs to summaries while keeping the conversation turns intact.

**vs Compaction:** No need to wait for automatic compaction. No need to shape the conversation at the end to influence compaction. Trimming happens in real-time, conversation continues seamlessly.

**vs Handoff:** Handoff transfers to a new chat. Context trimming lets you stay in the same focused chat indefinitely, preserving conversation spirit.

---

### 2. Skills System

Skills are **MCP tools wrapped in natural-language wrappers**. Claude can invoke them naturally.

#### Built-in Skills

**Handoff Skill**
- Transfers entire context to a new chat
- Claude names the new chat
- User reviews and clicks send
- Used for: switching topics, starting fresh while preserving context

**Remember / Search Skill**
- Semantic search across all chat history
- Works across all saved chats
- Can search by title or full-text
- Claude uses it automatically when asked "remember when we talked about..."
- Better than exact-match search — understands conversational semantics

**Context Trimming Skill**
- Wraps the context trimming MCP tool
- Claude and user both use it
- Shows tombstones for deleted messages

**Guardian Skill** (see dedicated section)

#### Custom Skills
- Written in natural language
- Stored in `.md` files (Cloud MD format)
- Haiku understands context
- Can be global (all projects) or project-specific
- Skills are part of the app itself, not just project-level

---

### 3. The Guardian — Proactive AI Correction

**What it does:** Watches Claude's output and proactively reminds Claude of abilities Claude "forgets" it has.

**Problem being solved:** Claude was trained before MCP tools existed. It frequently tells users to run terminal commands, check console logs, "I don't have browser access" — even when it has those abilities through MCP. The Guardian corrects this behavior in real-time.

**How it works:**
1. Haiku reads Claude's last message
2. Pattern-matches against a list of "false modesty" phrases (e.g., "I can't use the web", "I don't have permission to check ports")
3. If match found → fires a reminder to Claude that it CAN do this
4. After a few reminders, Claude stops the behavior for the session

**Characteristics:**
- Uses Haiku (fast, cheap) — negligible cost
- Runs as a background/warm process
- User can turn it on/off per session
- Custom rules written in natural language
- Base prompt is editable by asking Claude to modify it

**Remember Skill integration:** Claude can use the remember skill to find all instances where it said "I can't" — then those exact phrases are added to Guardian's pattern list.

---

### 4. Project Map (Visual Codebase Graph)

**What it is:** A visual graph showing how files connect. Nodes = files, edges = dependencies. Node size = file size (line count).

**Why it matters:**
- At a glance: is the codebase one 2000-line blob, or is it organized?
- See file sizes visually
- Watch Claude "jump between nodes" in real-time as it works
- Understand what files are connected before making changes

**vs File Tree:**
- File trees require expanding everything and still don't show structure
- Map shows the entire picture at once
- Makes it obvious when files are "drifting" (becoming disconnected)

**Relation awareness:** When Claude needs to edit a file, the map shows which other files it needs to understand (connections). Claude reads only the relevant subgraph, not the entire codebase.

**File size correlation:** Node sizes correlate to line counts. The map shows how bloated individual files are.

**Map types:** Solar (more organized) and other layout options.

---

### 5. Live Preview

Valo can show a **live preview of the app/website being built** without:
- Spinning up a local host server
- Local host constantly dying
- Restarting the dev server

This means Claude can see the result of code changes in real-time without interrupting its flow.

---

### 6. Agents System

Agents are sub-processes that run in the background. Valo runs multiple agents in parallel:

- **Code Reviewer Agent** — reviews code, finds bugs
- **Researcher Agent** — researches topics, finds more test cases
- **Project Explorer Agent** — explores the codebase structure
- **Background agents** send notifications when done (Valo fixed a bug where Claude said "I'll notify you when done" but never did)

**Pipeline system:** Multiple agents can run in sequence or parallel. "Light pipeline" = code reviewer + tidier run together.

**Foreground agents:** Can run specific tasks with granular permission control.

---

### 7. Background / Autonomous Mode

**The Problem:** Claude normally waits for user input between turns. For long-running tasks, this is slow.

**Valo's Solution:** Claude can be set to run autonomously with configurable parameters:
- **Max turns** — how many times to iterate before stopping
- **Custom interval** — e.g., every 5 minutes
- **Jitter/randomization** — add ±20 seconds randomness so actions don't look bot-like
- **Custom prompt** — the instruction to repeat

This is a "**cron job without the cron language**" — just a prompt on a timer.

---

### 8. Voice / Speech-to-Text

**Implementation:**
1. **Faster Whisper** transcribes user's speech locally
2. **Haiku** "translates" the transcript — corrects domain-specific terms (e.g., "tool tip" → "toolTip"), handles accents, cleans up code-related vocabulary
3. Result sent to Claude

**Why better than Super Whisper:**
- Super Whisper uses ChatGPT, which has no codebase context
- Valo's Whisper has **Claude context** — knows the codebase, understands technical terms
- Haiku post-processing catches code-specific terminology mistakes

**Use case:** The creator uses Valo primarily by voice. Valo Voice is described as "faster than Super Whisper" for their workflow.

---

### 9. Built-in Drawing / Sketching

- Click pen icon → sketch UI ideas directly in Valo
- Drawing attached to message and sent to Claude
- Claude can see the sketch while working
- Claude can draw back (upcoming feature)

**Why:** Instead of explaining "I want two buttons and one big button below" — just sketch it.

---

### 10. Chat History & Memory

**Storage:**
- All chats saved to a user-specified custom folder
- Each chat = backup / commit history
- Chats can be saved to **encrypted containers**
- Search across all history (title + full-text + semantic)

**Comparison to Git:**
- Claude commits to GitHub = codebase backup
- Chats saved locally = user's backup / "commits" of work
- When something breaks → find the working chat and pick up from there

**Memory files:** Stored as `.md` files, loaded into context as part of the context ring.

---

### 11. Permissions & Security

**Granular permissions:** Instead of VS Code's "allow for session" (which only allows reading ONE file for the session), Valo lets you:
- Allow per task (not per file)
- Claude won't prompt for confirmation for that task's duration

**Security features:**
- **Streamer mode** — masks API keys, tokens, usernames, sensitive data in real-time during screen recording
- **Encrypted containers** for chat storage
- Data stays local

---

### 12. Context Ring (Transparency)

Valo shows exactly what's in the context window and how much each component uses:
- App prompt
- Global Cloud MD
- Project Cloud MD
- Memory files
- Skills
- Agents

This is **how Claude sees your project** — a transparent breakdown of what's influencing the AI.

---

### 13. MCP Tools (Full List from Transcripts)

Valo exposes these MCP tools to Claude:
- `val_bash` — run terminal commands (with permission)
- `val_read` — read files
- `val_edit` — edit files
- `val_write` — write files
- `val_glob` — find files
- `val_grep` — search within files
- `val_delete_messages` — delete messages from context (user and Claude)
- `val_trim_context` — surgical context trimming
- `val_search_conversations` — search chat history
- `val_create_handoff` — create a new chat with context
- `val_create_skill` — create a new skill
- `val_web` / Playwright — browser control (when Claude "forgets" it has this)

---

## UX Philosophy

### The Paradigm Shift
> "Unlike VS Code or Cursor, which are code editors with AI bolted on — this is the opposite. The AI is the center and everything lives around it."

### Sweet Spot for Conversations
- **250-500 lines** of context per focused chat
- Split topics into separate chats rather than having one monolithic chat
- Claude can handle ~500 lines if the task is tightly coupled
- Splitting = less context bloat, clearer conversations

### Talk to Claude Like a Person
- Explain WHY you're building something, not just WHAT
- When Claude understands the bigger picture, performance is "completely different"
- Voice input (talking about your idea) provides the right amount of context naturally

### Stop Button Problem (Fixed)
When you click stop mid-conversation, Claude Code (and VS Code) creates a **new process with amnesia** — it loses context of the previous conversation. Valo:
1. Detects when Claude arrives into an unknown context
2. Tells the user "this might be a fresh session"
3. Fixed by running the **handoff skill** before stopping

### Tests as First-Class citizens
- Claude writes tests automatically
- Tests run in seconds
- Tests can be inserted into the code reviewer agent
- 66+ tests written for a single feature (stop button behavior)
- Claude also runs researcher agent to find more edge cases

---

## Pricing / Business Model

- **Free tier** — core features available
- **Pro features** — some advanced features behind paywall
- CLI connects to user's own Claude API key (Bring Your Own Key)
- Valo is the management layer, Claude is the engine

---

## Competitive Positioning

**vs Lovable:** Lovable auto-deploys small apps but can't build meaningful/big things. Valo bridges the gap — lets non-coders build real products by handling all the context management.

**vs Super Whisper:** Valo's voice has Claude context, not just generic STT.

**vs Claude Code (standalone):** Claude Code has no UI, no project map, no skills system, no context trimming, no agents pipeline.

**vs Cursor:** Cursor is an IDE with AI. Valo is an AI native app with IDE-like features.

---

## What's Unique / Differentiating

1. **Surgical context trimming** — 70-90% context reduction while preserving conversation meaning. Better than compaction or handoff.
2. **Guardian** — proactive correction of Claude's "I can't" behavior
3. **Project map** — visual graph of codebase structure, not just a file tree
4. **Skills as MCP wrappers** — natural language interface to tools
5. **Memory across chats** — semantic search of all conversation history
6. **Background agents with notifications** — actually delivers notifications (unlike Claude Code which says it will and doesn't)
7. **Voice with codebase context** — Haiku post-processing understands code terms
8. **Stop-safe architecture** — context preserved through handoffs even when stopping mid-conversation
9. **"AI is center" paradigm** — everything from the ground up designed for AI collaboration, not AI-assisted coding

---

## Key Quotes

- "Working with AI is managing context."
- "Compaction is automatic and dumb."
- "The AI is the center and everything lives around it."
- "Valo is a context and project manager to work with Claude."
- "Context trimming is better than compaction — you don't wait, you don't shape your conversation, you just keep going."
- "Stop button problem is a known Anthropic bug — their own VS Code extension has it."
