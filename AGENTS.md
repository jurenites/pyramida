# Project instructions

- Keep the game UI clean. Explain mechanics through gameplay or visuals, never through large text blocks, tutorial paragraphs, or persistent lists of controls.
- Use concise labels and essential values only where needed. Keep the bottom instruction panel hidden.
- Keep the persistent goal text and goal progress count hidden. Ask the user before introducing a replacement goal display or other unrequested UI content.
- Follow the user-confirmed direction in `docs/DESIGN_DIRECTION.md`.
- Make buildings communicate their purpose and activity through their models and visible behaviour. Avoid complex building configuration panels, production sliders and player-configured shift schedules.

- Use the shared UI point system in `scripts/ui_visual_tokens.gd` and `docs/UI_GUIDELINES.md`: 1 point is 1 logical UI pixel; solid UI strokes are 4 points, and padding/gaps use the same unit.

- Keep agent-run Godot tests silent and out of the user's way. Default to `--headless` (no window; uses the Dummy audio driver). For checks that require actual rendering, use `--audio-driver Dummy` and a verified background/non-activating launch; never steal focus or raise the game over the user's current work. If a check requires foreground interaction, ask first. Only launch a normal visible, audible game when the user requests it.

- Never use em dashes, emojis or bullet-dot separators (U+2022 or U+00B7) in responses or new UI text. Use plain sentences and ordinary punctuation.
