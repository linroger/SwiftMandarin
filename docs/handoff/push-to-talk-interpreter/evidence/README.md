# Evidence: push-to-talk Interpreter

Captured on 2026-11-19 during `handoff.md` Iteration 38. The command output that goes with these pictures is in that section of `handoff.md`.

Every Simulator picture was taken with the app launched with `-InterpreterSimulatorMuted`, so no sound was played. In the Simulator the transcript and the translation are scripted stand-ins, and each says so in its text.

| File | What it shows | How it was made |
|---|---|---|
| `simulator-iphone-1-ready.jpg` | The screen as it opens: the Simulator note, the empty state, both buttons enabled. | iPhone 17 Pro Max, iOS 27.2. Touch through the simulator tool. |
| `simulator-iphone-2-listening.jpg` | A held button: red, "Listening…", the labeled transcript arriving a word at a time, the other button unavailable. | A timed series of `simctl io screenshot` calls during a 3.4 s hold. |
| `simulator-iphone-3-speaking.jpg` | After release: the turn card with Stop and Copy, and the button reading 正在朗读… or "Speaking…". | As above. |
| `simulator-iphone-4-microphone-denied.jpg` | The microphone prompt declined: the banner and the error row, each with Open Settings. | From before the Simulator build stopped asking for the microphone. Device and macOS builds still ask, and show this. |
| `simulator-iphone-5-reply-interrupted-by-next-press.jpg` | A press on the other button during a reply: the reply is cut off and the next turn runs. | Two holds in quick succession. |
| `simulator-iphone-6-dark-mode.jpg` | Dark appearance. | `set_appearance dark`. |
| `simulator-iphone-7-short-press-hint.jpg` | A tap instead of a hold: "Hold the button while you speak, then let go." | A tap. Caught while the hint was fading in. |
| `simulator-iphone-8-chinese-interface.jpg` | The 中文 interface: 对话翻译, 重播, 复制, and the conversation opening on its latest turn. | App Language set to 中文, then set back to English. |
| `simulator-ipad-ready.jpg` | The screen on an iPad. | iPad Air 11-inch (M4), iOS 27.2. Opened without a touch by the self-test build's `-InterpreterShowScreen`, photographed with `simctl io screenshot`. |
| `macos-interpreter-screen.jpg` | The screen on macOS with the real models installed: no banner, both buttons enabled, the Space hint on the selected one. | The self-test build's `-InterpreterShowScreen -InterpreterSnapshotWindow`: the app draws a window of its own into a bitmap. It is the screen in a window made for the picture, not the app's main window with its sidebar, and a bitmap drawn this way does not composite glass and blur the way the window server does. Read it for layout, not for finish. |

Pictures 4 to 8 predate two visual changes made after looking at them: the Mandarin speaker's colour became a deeper teal so that white text is readable on it, and (4 to 7 only) the hold buttons became a bar that the conversation fades out behind. Pictures 1 to 3, the iPad one and the macOS one show the final look.

Not pictured, because it could not be done without the person who owns this Mac: a real voice through the real microphone, a reply heard through the speaker, the MiniMax voice, and anything on a physical iPhone. `handoff.md` lists these.
