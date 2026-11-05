# girlfriend

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Performance

Chats reuse one immutable conversation-list snapshot per provider build instead
of copying the entire list for each row. Sent ticks query only message roles,
not message bodies or image metadata. Both history queries share the existing
`time ASC`, 500-row window; refreshes, ordering, history retention, and clear
history behavior are unchanged. Static ambient-glow widgets are reused while
their original positions, colors, and animation clock continue to animate.

Measured on an Apple M1 with an iPhone 18 Pro / iOS 27 simulator:

| Workload | Before | After |
| --- | ---: | ---: |
| Native SQLite reads for 40 conversations × 500 cached messages | 197.3 ms | 37.9 ms |
| Conversation-list copies during a 200-conversation opening/20-drag widget run | 210 | 1 |
| Static glow subtree rebuilds over 360 animation frames | 720 | 0 |

SQLite values are medians of ten measured batches after two warmup batches.
Full-history and role-only reads were interleaved on identical local fixtures,
using the actual database helper/plugin with native profiling disabled and
debug printing suppressed for both paths. These are debug-simulator component
benchmarks, not release-device startup measurements.
Smoke scenarios also exercised conversation reordering and history-window
boundaries (empty, 1, 499, 500, 501, and 650 messages), tied timestamps,
companion isolation, new messages, replies, and clearing history.

No ad, consent, purchase, startup-delay, network-request, or pagination policy
was changed. The startup interstitial was observed before and after the changes.
End-to-end startup speed and release-device scrolling improvements are not
claimed from these component measurements. Xcode's native CPU/hang trace export
failed with `Document Missing Template Error`; no native CPU or hang result is
inferred from that trace.
