# CLAUDE.md

## What this project does

A CLI tool (`swift run create-image`) that generates images using Apple's `ImageCreator` (ImagePlayground framework). Because `ImageCreator` requires a foreground macOS app with `NSApp.setActivationPolicy(.regular)`, the tool has a two-process architecture.

## Architecture

```
CreateImage (CLI, AsyncParsableCommand)
  → Thin wrapper: parses arguments, delegates to ImageLauncher

CreateImageLauncher (library)
  → Launches CreateImageRunner binary via Process
  → Connects via TCP (Network framework, NWConnection) on fixed port 51573
  → Sends ImageRequest, receives ImageResponse (length-prefixed JSON)
  → Terminates runner process on completion (defer)

CreateImageRunner (SwiftUI App, TCP server)
  → Launched by CreateImageLauncher as a child process
  → Sets activation policy to .regular and activates (required for ImageCreator)
  → Starts NWListener on the port passed via --port argument
  → Receives ImageRequest, runs ImageCreator, sends ImageResponse
  → Window is hidden immediately (orderOut), but activation policy must stay .regular
  → Terminates itself after handling one request

CreateImageLogics (shared library)
  → ImageRequest / ImageResponse (Codable)
  → sendMessage / receiveMessage (length-prefixed TCP helpers)
```

## Critical constraints discovered during development

### ImageCreator requires foreground activation policy
- The runner process must call `NSApp.setActivationPolicy(.regular)` and `NSApp.activate()` before using ImageCreator
- Without this, `images(for:style:limit:)` fails with `backgroundCreationForbidden`
- A .app bundle is NOT required — a bare executable works as long as the activation policy is set correctly
- SwiftPM Command Plugin sandbox blocks app launching from child processes entirely

### Activation policy must stay .regular
- Switching to .accessory after launch causes backgroundCreationForbidden
- The Dock icon appearing briefly is an unavoidable trade-off
- Windows can be hidden with orderOut(nil)

### NWConnection .waiting state must be handled
- Without handling .waiting as a failure in the stateUpdateHandler, the connection hangs forever instead of retrying

### NWListener does not support Unix domain sockets
- NWEndpoint.unix(path:) works for NWConnection (client) only
- NWListener can only listen on TCP/UDP ports

## Build and test

```bash
swift build
swift test
swift run create-image "a cat sitting on a rainbow"
swift run create-image --source-image face.jpg "a person walking"
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
- Logger categories: `launcher` (CreateImageLauncher), `runner` (CreateImageRunner)
- Default image style: `animation`
- Errors include type name + localizedDescription for diagnostics
