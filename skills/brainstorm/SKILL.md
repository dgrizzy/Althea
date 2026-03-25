---
title: Brainstorm
description: Turn a rough idea into a detailed technical spec through guided conversation and deep thinking
author: You + Me
version: 1.0
status: active
---

# Brainstorm Skill

Transform a messy idea into a locked, actionable technical specification through structured dialogue and architectural analysis.

## When to Use

- You have a feature idea but it's rough / half-baked
- You want to think through implications before building
- You need to understand tradeoffs and architectural questions
- You want a detailed game plan before handing off to Claude Code

## The Workflow

### Phase 1: Brain Dump (You)
You provide a raw, unstructured dump of:
- What you want to build
- Why it matters
- Rough constraints / preferences
- Anything vague or uncertain is fine — that's expected

### Phase 2: Clarification (Me)
I ask targeted questions to:
- Uncover hidden assumptions
- Push on scope and priorities
- Connect to existing codebase patterns
- Expose ambiguities

Questions follow a pattern:
1. **Domain understanding** — How does this fit with existing concepts?
2. **Constraints and tradeoffs** — What are we optimizing for? What are we willing to sacrifice?
3. **Architecture** — How does this layer into the system? What dependencies exist?
4. **Unknowns** — What do we not know yet? What's the risk?

### Phase 3: Deep Thinking (Opus Subprocess)
I spawn an isolated Opus session with high thinking to:
- Analyze the idea systematically
- Identify architectural patterns and antipatterns
- Surface non-obvious implications
- Suggest angles you might not have considered
- Propose concrete questions back for you

You see the output — I use it to inform my next round of clarification.

### Phase 4: Iteration
Repeat phases 2-3 until:
- Scope is locked (what's in/out)
- Architecture is clear (how it layers in)
- Tradeoffs are explicit (what we chose and why)
- Unknowns are identified (what we might learn during build)
- The spec is detailed enough that Claude Code can execute without guessing

### Phase 5: Spec Lock
Output a detailed specification document that includes:
- **Vision**: One paragraph — what and why
- **Scope**: In/out list
- **Architecture**: How it fits, what components change
- **Acceptance criteria**: What done looks like
- **Risks and unknowns**: What could go wrong, what we'll learn
- **Tasks breakdown**: Phased list of implementation steps

### Phase 6: Handoff
Pass the locked spec to Claude Code for implementation.

## Tips

- **Radical honesty about unknowns.** If you're uncertain, say it. That's what this phase is for.
- **Give me context.** The more you explain the problem you're solving, the better questions I ask.
- **Expect me to push back.** If something seems risky or unclear, I'll say so. That's the point.
- **Tradeoffs are real.** We'll likely find that you can't have everything. Better to discover that now.

## Example Invocation

**You**: "Here's my brain dump on a feature..."

**Me**: "Got it. A few clarifying questions..."

**You**: "Here's the answer, plus more context..."

**Me**: [Spawns Opus] "Deep thinking happening..."

**Opus output**: "Consider these angles..."

**Me**: "That adds some interesting questions. Here's what I'd push on next..."

**You + Me**: Iterate until we have a locked spec.

## Handoff to Claude Code

Once the spec is locked, I invoke Claude Code with:
```
task: [locked spec from phase 5]
```

Claude Code builds from the spec, using the breakdown and acceptance criteria to guide implementation.

## Files in This Skill

- `SKILL.md` — this file
- `spec-template.md` — template for locked specs
- `example-spec.md` — real example of a completed brainstorm spec
