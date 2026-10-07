# Leaving the app cleanly before a Windows update

Date: 2026-10-06

## Context

On 2026-10-06 a VMLab Windows 11 copy of v0.3.0 played a clip, then updated through the in-app badge. The app started the v0.4.0 installer and called `exit(0)`, but the process never finished exiting: it stayed with one waiting thread and its frozen window until Windows restarted. The installer found it, `taskkill /F` failed with "There is no running instance of the task", and the installer stopped with "Failed to kill Project Swiftie". The same update with no clip played in the session worked.

flutter_soloud keeps its native player in a global. Under clang that global is marked never to be destroyed, but the Windows build uses MSVC, so its destructor runs while the process exits. On Windows `exit(0)` is `ExitProcess`, which stops every other thread first and then unloads each DLL. If the engine is still running, the destructor stops the audio device and joins its scheduler thread, and both wait on threads that `ExitProcess` has already stopped. flutter_soloud says `deinit()` is meant to run before the app exits; the app never called it. A process stuck in `ExitProcess` cannot be killed from outside, and every exe and DLL it loaded stays locked, so the installer cannot write over them.

The installer also paused a fixed 500 ms after `taskkill`. In one run that was not long enough for Windows to release `flutter_windows.dll`, and the copy stopped with "Error opening file for writing".

## Decision

**The app shuts its audio engine down before it exits.** The in-app updater on both platforms leaves through `appExitProvider`, which calls `AudioEngine.shutdown()` (flutter_soloud's `deinit()`) and then exits. A quit request from the window, Alt+F4 or Cmd+Q goes through an `AppLifecycleListener` that does the same. A shutdown that fails, or takes longer than two seconds, never blocks the exit.

**The installer waits for the app, then works around one that will not go.** After `taskkill` it checks every 250 ms, twenty times, for the process to disappear. Then, before copying, it deletes the app's own files: `swiftie-quiz.exe`, the DLLs beside it, and everything under `data`. A file it cannot delete, because a stuck process still has it loaded, it renames to `<name>.replaced-<tick count>`, which Windows allows for a loaded exe or DLL. The new files are then written to the original names, and the update relaunches into them. Only a file that can be neither deleted nor renamed stops the install, with the same message as before. The next install, or the uninstaller, deletes any `.replaced-` files once nothing holds them.

The installer never deletes outside those three places, because the install folder can be chosen by hand on the directory page; the uninstaller has always kept to the same scope.

Copies already installed run the new installer when they update, so the installer change helps a v0.3.0 or v0.4.0 that gets stuck on the way out. The app change stops the next version getting stuck at all. The updater protocol, the install folder, the exe name and the uninstall key are unchanged.
