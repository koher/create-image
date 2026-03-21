# CLAUDE.md

## What this project does

A CLI tool (`swift run create-image`) that generates images using Apple's `ImageCreator` (ImagePlayground framework). Because `ImageCreator` requires a foreground macOS app launched via Launch Services, the tool has a two-process architecture.

## Architecture

```
CreateImage (CLI, AsyncParsableCommand)
  → Builds a temp .app bundle in FileManager.default.temporaryDirectory
  → Copies CreateImageRunner binary into the bundle
  → Launches via NSWorkspace.openApplication (requires NSApplication.shared init on MainActor first)
  → Connects via TCP (Network framework, NWConnection) on fixed port 51573
  → Sends ImageRequest, receives ImageResponse (length-prefixed JSON)
  → Cleans up: terminates runner via NSRunningApplication + removes temp bundle (defer)

CreateImageRunner (SwiftUI App, TCP server)
  → Launched by CreateImage as a .app bundle via Launch Services
  → Starts NWListener on the port passed via --port argument
  → Receives ImageRequest, runs ImageCreator, sends ImageResponse
  → Window is hidden immediately (orderOut), but activation policy must stay .regular
  → Terminates itself after handling one request

CreateImageLogics (shared library)
  → ImageRequest / ImageResponse (Codable)
  → sendMessage / receiveMessage (length-prefixed TCP helpers)
```

## Critical constraints discovered during development

### ImageCreator requires .app bundle + Launch Services
- A bare executable (even with NSApp.setActivationPolicy(.regular)) triggers `backgroundCreationForbidden`
- `ImageCreator()` init succeeds without a bundle, but `images(for:style:limit:)` fails
- The .app must be launched via `open` command or `NSWorkspace.openApplication`, not by running the binary directly
- SwiftPM Command Plugin sandbox blocks app launching from child processes entirely

### NSWorkspace.openApplication needs NSApplication.shared
- Without `await MainActor.run { _ = NSApplication.shared }` before the call, it fails silently or with backgroundCreationForbidden
- This was a non-obvious requirement

### Activation policy must stay .regular
- Switching to .accessory after launch causes backgroundCreationForbidden
- The Dock icon appearing briefly is an unavoidable trade-off
- Windows can be hidden with orderOut(nil)

### Temp bundle location matters
- FileManager.default.temporaryDirectory (/var/folders/.../T/) works
- itemReplacementDirectory (/var/folders/.../T/TemporaryItems/) causes creationFailed
- /tmp also works

### NWConnection .waiting state must be handled
- Without handling .waiting as a failure in the stateUpdateHandler, the connection hangs forever instead of retrying

### NWListener does not support Unix domain sockets
- NWEndpoint.unix(path:) works for NWConnection (client) only
- NWListener can only listen on TCP/UDP ports

## Build and test

```bash
swift build
swift run create-image "a cat sitting on a rainbow" --output cat.png
swift run create-image "a person walking" --output person.png --source-image face.jpg
```

## Known ImageCreator behaviors

### creationFailed is prompt-dependent
- `ImageCreator.Error.creationFailed` occurs when the prompt is difficult for the model to generate
- The same prompt may succeed on retry due to randomness, but the root cause is the prompt content
- This is not a bug in this tool or a transient server error

### Person prompts require --source-image
- Prompts involving people throw `conceptsRequirePersonIdentity` without a source image
- The source image must contain a face large enough to be usable (`faceInImageTooSmall` otherwise)

## Style

- Logger subsystem: `create-image` (no reverse DNS)
- Default image style: `animation`
- Errors include type name + localizedDescription for diagnostics
- No external command dependencies (FileManager.copyItem, NSWorkspace.openApplication)
- Only exception: /usr/bin/open is NOT used (replaced by NSWorkspace)
