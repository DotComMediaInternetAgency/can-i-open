# User Interface and Accessibility Guidelines

## Design intent

Use a calm, information-dense native macOS interface. Prioritize quick scanning and safe, understandable association changes over decorative styling. The File Types and Apps views should feel like parts of one product: use the same toolbar conventions, typography hierarchy, spacing rhythm, selection behavior, and language.

## Native macOS patterns

- Prefer standard SwiftUI controls, toolbar items, menus, sheets, tables, split views, and confirmation dialogs.
- Use SF Symbols with labels where an icon alone would be ambiguous. Icon-only toolbar controls need an accessibility label and useful help text.
- Respect system light/dark appearance and dynamic type. Use semantic colors (`.primary`, `.secondary`, `.tertiary`, and system accent colors) instead of fixed text colors when possible.
- Use consistent spacing: compact spacing within related controls, larger spacing between sections. Avoid arbitrary one-off colors, shadows, rounded-card treatments, and custom controls unless they solve a demonstrated usability need.
- Keep table columns concise and useful at the app's minimum window size. Avoid relying on color alone to signal default ownership, errors, or selection.
- Keep standard application commands, including About, in their native macOS menu locations. The About panel should use the system panel and provide accurate, centered app credits with clickable project links.

## Interaction language and safety

- Use one consistent name for an action: “Set Default App.” Do not imply that the action separately changes editor and viewer roles.
- In the Apps view, provide **Change Defaults…** for the selected source app. Explain that only types currently defaulted to that app are included; types it merely claims remain untouched.
- In the app-to-app review, preselect types the target app declares as handlers. Mark unsupported types clearly and allow a deliberate **Select > All Current Defaults** override with a warning. Revalidate source ownership immediately before applying the batch.
- Before a global association change, show how many file types will change and which app will receive them. Keep macOS confirmation behavior clear.
- Auto-confirm must be opt-in, visibly enabled/disabled, explain its Accessibility permission requirement, and remain scoped to the expected dialog/app.
- Show operation progress while work is running and a completion summary afterward. Distinguish complete success, partial success, and failure. Make error details accessible without overwhelming the main view.
- Undo and history must explain their limits: history is session-only, and a role with no previous handler cannot be cleared back to empty. Ask for confirmation before restoring global associations.
- Every loading, empty, filtered-empty, and error state should explain what happened and offer an appropriate next action (for example, refresh or clear filters).
- Keep selection stable and predictable when refreshing or filtering. Avoid silently acting on an invisible or stale selection.

## Accessibility

- Use native controls with meaningful accessibility labels, values, and help text.
- Ensure all actions can be reached and operated by keyboard; retain standard Return and Escape behavior for primary and cancel actions where appropriate.
- Preserve VoiceOver context for table rows, toolbar actions, progress, and operation results. Do not rely only on icons or color.
- Make identifiers selectable when copying them is useful; use secondary text styles for technical details without making them illegible.
- Avoid using `@EnvironmentObject` inside `Table` or `List` row/cell subviews. Resolve values in the parent and pass concrete values into rows to avoid SwiftUI cell reuse crashes (see `.claude/memory/corrections.md`).
- Inspect the Accessibility tree when interaction structure changes. Check the app at its minimum supported window dimensions and in both system appearances for meaningful UI changes.

## Review checklist

- Are terms and action labels consistent across toolbar, menus, sheets, history, and README?
- Is the scope and consequence of a system-level change clear before confirmation?
- Can the user identify progress, completion, partial errors, and the next action?
- Are keyboard and VoiceOver affordances present?
- Does the layout remain understandable at the minimum window size and with long app names or UTIs?
