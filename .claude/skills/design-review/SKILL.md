---
name: design-review
description: Review and polish every newly implemented or modified screen in OshiNium before considering a UI task complete. Use after any SwiftUI view is added or changed — Home, Chat, MyPage, Calendar, or the OshiNium tab — to catch inconsistencies and push the screen toward first-party Apple polish while preserving OshiNium's own visual identity. Also use when the user asks to "review the design," "polish the UI," or "make it feel more native."
---

# Design Review

Review every newly implemented or modified screen before considering the task complete. The goal is not only to detect UI issues, but to redesign and polish the screen until it feels like a first-party Apple application while preserving OshiNium's unique identity.

**This is a standing check, not a one-time task.** Run it as the last step of any UI-touching change, not just when explicitly asked to "review design."

## General Design Principles

- Follow Apple Human Interface Guidelines.
- Prioritize simplicity and consistency.
- Maintain generous spacing and clean visual hierarchy.
- Use smooth animations without unnecessary effects.
- Avoid visual clutter.
- Every screen should feel premium and production-ready.
- Keep design consistent across the entire application.
- Never sacrifice usability for decoration.

## Per-Screen Structural References

Each tab has its own structural inspiration to hold it to — use these as the lens for review, not as a license to copy their branding or exact layouts wholesale.

### Home

Feel similar to Apple's own apps while using Instagram and Threads as structural inspiration.

Review:
- spacing
- typography
- hierarchy
- card layouts
- scrolling experience
- timeline readability
- image presentation
- interaction feedback
- empty states

### Chat

Resemble Apple's Messages app while using Instagram DM as the structural reference.

Review:
- conversation list
- message bubbles
- timestamps
- unread indicators
- typing states
- transitions
- scrolling
- group chats

Improve every detail until it feels native.

### My Page

Use Instagram Profile as the structural inspiration while keeping Apple's design language.

Review:
- profile header
- statistics
- buttons
- grid layout
- spacing
- cards
- transitions

Maintain premium appearance.

### Calendar

Use TimeTree as the structural inspiration.

Hard requirements (regressions here are release-blocking, not polish nits):
- The calendar must never stretch or deform.
- Calendar size should remain stable during navigation.
- Opening event lists or event details must not resize the calendar.
- Navigation should feel seamless.
- Calendar animation should feel native.
- Preserve Apple's spacing and typography.

Review:
- event list
- navigation
- month transition
- calendar rendering
- scroll behavior
- performance

### OshiNium Tab

This is the signature screen of the application — hold it to a higher bar than the others.

Review:
- information hierarchy
- event dashboard
- ticket section
- goods section
- maps
- weather
- surrounding facilities
- premium appearance

The screen should become the identity of OshiNium while remaining visually consistent with the rest of the application.

## Animation

Always review animations as part of the pass.

Remove:
- unnecessary fade transitions
- dark flash / screen-darkening on navigation
- heavy or slow transitions

Prefer:
- spring animation
- smooth, subtle transitions
- `matchedGeometryEffect` where it genuinely clarifies continuity (not decoratively)
- Apple's native feeling — instant where Apple would be instant, animated only where it earns its keep

## Final Review Checklist

Before completing any UI task, automatically verify:
- Apple HIG compliance
- spacing consistency (with nearby screens, not just internally)
- typography consistency (sizes/weights reused, not invented per-screen)
- accessibility (tap targets, contrast, VoiceOver labels on icon-only controls)
- visual hierarchy (the most important thing on screen reads first)
- interaction quality (tap/press states, disabled states, loading states)
- animation quality (see above)
- design consistency across every tab (a component styled one way on Home shouldn't drift on MyPage)

If improvements are possible, continue refining before finishing — don't stop at "technically works."
