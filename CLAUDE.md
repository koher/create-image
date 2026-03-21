# CLAUDE.md

## What this project does

A CLI tool (`swift run create-image`) that generates images using Apple's `ImageCreator` (ImagePlayground framework).

## Architecture

```
CreateImage (CLI, AsyncParsableCommand)
  → Thin wrapper: parses arguments, delegates to ImageLauncher

CreateImageLauncher (library)
  → Calls ImageCreator directly to generate images
  → Saves output as PNG

CreateImageLogics (shared library)
  → ImageRequest / ImageResponse (Codable)
```

## Critical constraints discovered during development

### ImageCreator must be called from a library target, not an executable target
- Calling ImageCreator directly from an executable target triggers `backgroundCreationForbidden`
- The same code works when placed in a library target and called from the executable
- `NSApp.setActivationPolicy(.regular)` does not resolve this — the module boundary itself matters
- No .app bundle or separate runner process is required
- SwiftPM Command Plugin sandbox blocks ImageCreator entirely

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
- Logger category: `launcher` (CreateImageLauncher)
- Default image style: `animation`
- Errors include type name + localizedDescription for diagnostics
