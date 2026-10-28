# Project instructions

- Keep the game UI clean. Explain mechanics through gameplay or visuals, never through large text blocks, tutorial paragraphs, or persistent lists of controls.
- Use concise labels and essential values only where needed. Keep the bottom instruction panel hidden.
- Keep the persistent goal text and goal progress count hidden. Ask the user before introducing a replacement goal display or other unrequested UI content.
- Follow the user-confirmed direction in `docs/DESIGN_DIRECTION.md`.

- Use the shared UI point system in `scripts/ui_visual_tokens.gd` and `docs/UI_GUIDELINES.md`: 1 point is 1 logical UI pixel; solid UI strokes are 4 points, and padding/gaps use the same unit.
