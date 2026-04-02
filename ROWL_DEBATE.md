# Rowl vs. AXISBlueprint 2 — Strategic Debate

## What Rowl Does Well (That AXISBlueprint 2 Should Learn From)

### 1. Ecosystem Thinking
Rowl isn't just an IDE — it's a **platform**. Monaco Editor, multi-provider AI, Git integration, terminal, skills, cloud sync, mobile companion apps. The scope is ambitious, but the result is an environment where everything is connected. AXISBlueprint 2 should aspire to this coherence: its features (map, guardian, context ring, skills) shouldn't feel like a collection of panels but like a unified **context cockpit**.

### 2. Skills System Architecture
Rowl's skills are modular, written in YAML/structured configs, and built to be discovered. The architecture (Skills as AI Capabilities, pluggable, composable) is solid. AXISBlueprint 2's skills-as-markdown approach is more Claude-native and flexible, but Rowl's pattern of `trigger → step → ai-review` is worth borrowing for the agent pipeline.

### 3. AI Provider Abstraction
Rowl cleanly abstracts OpenAI, Anthropic, Google, and local LLMs behind a unified interface. AXISBlueprint 2 is tightly coupled to Claude Code CLI — that's intentional, but it means AXISBlueprint 2 is a one-trick pony riding Claude. Rowl's multi-provider model future-proofs it.

### 4. Cross-Platform Vision
Rowl is serious about macOS/Windows/Linux + mobile. AXISBlueprint 2 is explicitly macOS-only for R1. That's fine for now, but the ambition should be noted: a context management tool that only works on one platform limits its audience significantly.

### 5. Production Quality Bar
Rowl has CI/CD, code coverage, releases with download badges. It's being built like a product people will actually use, not a hobby project. AXISBlueprint 2 should match this discipline from day one.

---

## What AXISBlueprint 2 Does That Rowl Can't Easily Add

### 1. Surgical Context Trimming
Rowl's context management is basic: token counting, warnings at limits, auto-trim of old tool calls. AXISBlueprint 2's **surgical trimming** — deleting specific messages, showing tombstones, preserving conversation continuity — is a fundamentally better UX. Rowl would need to redesign its entire context pipeline to match this. That's not a feature add; it's an architectural rebuild.

### 2. Guardian (False Modesty Detection)
The idea of running a lightweight Haiku model to detect when Claude is underselling its own capabilities and proactively reminding it is **genuine innovation**. This isn't a feature Rowl can bolt on — it requires a separate process, a rule engine, and an MCP integration that intercepts Claude's responses. Rowl's Claude integration is pass-through; AXISBlueprint 2's is **proactive**.

### 3. Project Map (Visual Dependency Graph)
Rowl has a file tree and symbol search. AXISBlueprint 2 has a **physics-simulated graph** showing files as nodes sized by line count, with dependency edges, pulsing when Claude touches them. This is a fundamentally different way of understanding a codebase. You can't build this from a file tree. You need a dedicated canvas renderer, graph analysis, and real-time update integration. Rowl would need months of work to match this.

### 4. Menu Bar Architecture (Always-On-Top, Zero Friction)
A menu bar popover is **always accessible**, doesn't require launching a full IDE, and stays out of your way. Rowl is an application you switch to; AXISBlueprint 2 is a tool that lives at the edge of your screen. These are different interaction paradigms. You can't make an Electron app feel like a native menu bar app.

### 5. Stop-Safe Architecture
Rowl doesn't address what happens when Claude Code stops mid-process and loses context. AXISBlueprint 2's handoff-before-stop flow is a **real pain point solved**. Until Rowl has a solution for this, AXISBlueprint 2 has a genuine advantage for long-running Claude sessions.

### 6. Voice Input Pipeline (faster-whisper + Haiku)
Rowl has no voice input at all. AXISBlueprint 2's pipeline — local STT → Haiku translation → Claude with full context — is a materially different capability. It's the difference between "AI that responds to text" and "AI you can talk to like a colleague."

### 7. Background/Autonomous Mode
Rowl's automations are YAML workflows triggered by events. AXISBlueprint 2's autonomous mode is "set a prompt on a timer with jitter" — dead simple, fundamentally different. This is the difference between a CI/CD pipeline and a real AI coworker you can leave running.

---

## The Five Debate Questions

### 1. Should AXISBlueprint 2 Merge Into Rowl as a Feature?

**No. Not yet. Probably not ever in the traditional sense.**

The architectural mismatch is the core problem:
- **Rowl:** Electron, multi-provider, Monaco Editor, full IDE, cross-platform
- **AXISBlueprint 2:** SwiftUI, Claude Code CLI wrapper, native menu bar, macOS-only

These are different **runtime environments**. Electron apps don't run as menu bar popovers with native SwiftUI panels. You can't embed SwiftUI inside an Electron renderer without significant friction. And AXISBlueprint 2's tight coupling with Claude Code CLI — MCP tools, process management, streaming stdout — is fundamentally different from Rowl's multi-provider API approach.

**What COULD happen:** Rowl could adopt AXISBlueprint 2's **context management philosophy** and begin building surgical trimming, the guardian, and project map as native Rowl features. But "merge AXISBlueprint 2 into Rowl as a feature" means rewriting AXISBlueprint 2 in TypeScript/Electron, which would likely destroy the native quality that makes it worth building.

**Verdict:** Stay separate. Cross-pollinate ideas. Don't merge codebases.

---

### 2. Should They Share the Same Skills System?

**Partially. Not a full merge.**

Rowl's skills are **IDE extensions** — they generate code, docs, tests, run security scans. They're tool-centric.

AXISBlueprint 2's skills are **Claude Code wrappers** — they're natural-language prompts that tell Claude how to behave when invoked. They're prompt-centric.

These are different mental models. A "Code Review" skill in Rowl runs a static analysis tool. A "Code Review" skill in AXISBlueprint 2 tells Claude: "here are the changed files, rate the severity."

**What makes sense:** Establish a **shared skills concept** with a compatible file format, so skills written for AXISBlueprint 2 could theoretically be adapted for Rowl and vice versa. But they should remain separate skill directories with separate runtimes. The skills are similar enough to benefit from shared conventions; different enough to need separate implementations.

**Verdict:** Share conventions. Share format ideas. Keep runtimes separate.

---

### 3. Design System: Adopt Rowl's or Keep Its Own?

**Keep AXISBlueprint 2's own design system. It's better suited to its purpose.**

Rowl's design is a "next-generation IDE" — Electron-style with dark surfaces, Monaco-centric layout, feature-dense panels. It's a **product website aesthetic** applied to an IDE.

AXISBlueprint 2's design is Raycast + Apple Intelligence: near-black backgrounds, SF Symbols, SF Pro typography, spring-based animations, spatial system built on 4pt grid. This is **native macOS quality** — the bar AXISBlueprint 2 set for itself.

These designs serve different platforms and different expectations:
- Rowl: feature-rich, visual density acceptable, cross-platform
- AXISBlueprint 2: focused, minimal, native, macOS-only

AXISBlueprint 2 adopting Rowl's design would be a downgrade. Rowl's design would look Electron-ish on a native menu bar app. Keep them separate.

**One exception:** If AXISBlueprint 2 ever expands beyond a menu bar popover (a full standalone window, or desktop app), it should take Rowl's **color palette conventions** — not because Rowl's is better, but because consistency across Tommaso's tools reduces cognitive load. The same accent blue, the same semantic colors (success/warning/destructive). But the **component patterns** should stay native SwiftUI.

**Verdict:** Keep separate design systems. Consider sharing color semantics.

---

### 4. Naming: Should AXISBlueprint 2 Become "Axis"?

**"Axis" is a strong name. But the positioning matters more than the name.**

"AXISBlueprint 2" is cumbersome — too many characters, too many concepts (AXIS + Blueprint + version 2). If the goal is a product people can remember and say, "Axis" is cleaner.

The positioning question is more important:
- **If AXISBlueprint 2 stays separate:** "Axis" is a great standalone name. Short, memorable, hints at the core value (context axis, coordinate system for projects).
- **If AXISBlueprint 2 is positioned as Rowl's context management module:** "Axis" works perfectly — "Axis for Rowl" positions it as Rowl's context/session layer. Think of it like "GitHub Copilot" being separate from "GitHub" but deeply integrated.

**"Axis" as a name also survives the "what does it do?" question better than "AXISBlueprint 2".** "What does Axis do?" → "It's a context cockpit for Claude Code." Clean.

**Recommendation:** Rename to **Axis** (drop the "Blueprint 2" entirely). Position it as: *"Axis — Context management for Claude Code. Built native for macOS."*

Rowl keeps its name for the IDE. Axis keeps its name for the context tool. They're related but distinct products from the same maker.

**Verdict:** Rename to "Axis." Don't merge. Position as companion, not sub-feature.

---

### 5. What Should AXISBlueprint 2 (Axis) Solve for Rowl?

**The gaps Rowl has that Axis should own:**

1. **Context amnesia on stop** — Rowl will eventually need a stop-safe architecture. Axis already has it.
2. **Claude Code underselling** — Guardian pattern is proven. Rowl needs it.
3. **Surgical trimming** — Rowl's auto-trim is blunt. Axis's tombstone model is surgical.
4. **Project understanding** — Map vs. file tree is a fundamentally different UX. Rowl should adopt the graph concept.
5. **Always-on-top context** — A menu bar Axis gives you context access without switching apps. This complements Rowl perfectly.

**The key insight:** Rowl is where you **edit code**. Axis is where you **manage sessions**. They're different workflows. A developer using Axis for context management and Rowl for code editing is a more powerful combination than either tool alone.

---

## Final Recommendation

### Stay Separate. Share Ideas. Coexist.

| Question | Recommendation |
|---|---|
| Merge into Rowl? | **No** — different architectures, different paradigms |
| Share skills system? | **No** — share conventions, keep runtimes separate |
| Adopt Rowl's design? | **No** — Axis's native SwiftUI design is its strength |
| Rename to "Axis"? | **Yes** — clean, memorable, positions well as companion |
| What should Axis solve for Rowl? | **Context philosophy**: trimming, guardian, map, stop-safe |

### How They Should Relate

```
┌─────────────────────────────────────────────────┐
│                  Tommaso's Stack                  │
│                                                  │
│   ┌──────────────┐         ┌──────────────┐     │
│   │    Rowl      │         │    Axis      │     │
│   │  (IDE)      │◄───────►│  (Context)   │     │
│   │             │  shared  │              │     │
│   │ • Edit code │  design  │ • Manage     │     │
│   │ • Full IDE  │  ideas   │   sessions   │     │
│   │ • Multi-AI  │         │ • Guardian    │     │
│   │             │         │ • Map         │     │
│   │             │         │ • Trim        │     │
│   └──────────────┘         └──────────────┘     │
│                                                  │
│   Shared: color semantics, skill conventions    │
│   Separate: architecture, runtime, design system │
└─────────────────────────────────────────────────┘
```

### The Strategic Argument

The biggest risk for both projects is **scope creep killing both**. If Axis tries to become an IDE, it loses what makes it great (fast, focused, native). If Rowl tries to absorb every Axis feature, it becomes bloated and loses its IDE identity.

The smarter play: **two focused tools, built by the same person, sharing conventions where it makes sense.** A developer who uses Rowl for coding and Axis for context management gets a better experience than either tool provides alone.

Build Axis. Build Rowl. Keep them separate. Let them talk to each other.

---

*Debate authored: 2026-04-02*
*Products by: Tommaso Mauriello*
