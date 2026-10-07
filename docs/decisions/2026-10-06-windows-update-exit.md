# Leaving the app cleanly before a Windows update

Date: 2026-10-06

## Context

On 2026-10-06 a VMLab Windows 11 copy of v0.3.0 played a clip, then updated through the in-app badge. The app started the v0.4.0 installer and called `exit(0)`, but the process never finished exiting: it stayed with one waiting thread and its frozen window until Windows restarted. The installer found it, `taskkill /F` failed with "There is no running instance of the task", and the installer stopped with "Failed to kill Project Swiftie". The same update with no clip played in the session worked.

flutter_soloud keeps its native player in a global. Under clang that global is marked never to be destroyed, but the Windows build uses MSVC, so its destructor runs while the process exits. On Windows `exit(0)` is `ExitProcess`, which stops every other thread first and then unloads each DLL. If the engine is still running, the destructor stops the audio device and joins its scheduler thread, and both wait on threads that `ExitProcess` has already stopped. flutter_soloud says `deinit()` is meant to run before the app exits; the app never called it. A process stuck in `ExitProcess` cannot be killed from outside, and every exe and DLL it loaded stays locked, so the installer cannot write over them.

The installer also paused a fixed 500 ms after `taskkill`. In one run that was not long enough for Windows to release `flutter_windows.dll`, and the copy stopped with "Error opening file for writing".

## Decision

**The app shuts its audio engine down before it exits.** The in-app updater on both platforms leaves through `appExitProvider`, which calls `AudioEngine.shutdown()` and then exits. A quit request from the window, Alt+F4 or Cmd+Q goes through an `AppLifecycleListener` that does the same. The shutdown uses flutter_soloud's `deinitAsync()`, which stops the device on a helper isolate, so the two-second limit holds even if the device stalls; a failure or timeout is logged and never blocks the exit. It also stops an engine that is still starting, and an engine that has shut down refuses to start again, so a late clip cannot bring it back before the process ends.

**The installer waits for the app, then works around one that will not go.** After `taskkill` it checks every 250 ms, twenty times, for the process to disappear. Then, when the folder already holds `swiftie-quiz.exe`, it renames the app's own files to `<name>.replaced-<tick count>`: `swiftie-quiz.exe`, the DLLs beside it, and everything under `data`. Windows allows renaming an exe or DLL that a stuck process still has loaded. If any file will not rename, the installer renames this run's files back and stops with the same message as before, so a failed update leaves the old install exactly as it was. Once every file has moved, it deletes the renamed files, keeping any a stuck process still holds, and copies the new files to the original names; the update then relaunches into them. A later install, or the uninstaller, deletes leftover `.replaced-` files once nothing holds them.

On a first install into a folder without `swiftie-quiz.exe`, which the directory page lets a user type by hand, the installer touches nothing that is already there. In an existing install it only renames and deletes inside the same three places the uninstaller has always removed, plus the `.replaced-` files it made itself.

Copies already installed run the new installer when they update, so the installer change helps a v0.3.0 or v0.4.0 that gets stuck on the way out. The app change stops the next version getting stuck at all. The updater protocol, the install folder, the exe name and the uninstall key are unchanged.
