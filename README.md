# CreateImage

A command-line tool that generates images using Apple's [ImageCreator](https://developer.apple.com/documentation/imageplayground/imagecreator) (Image Playground framework).

## Requirements

- macOS 15.4+
- Apple Silicon Mac with Apple Intelligence enabled
- Swift 6.2+

## Usage

```bash
swift run create-image "a cat sitting on a rainbow"
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `<prompt>` | Text description of the image to generate (required) | — |
| `--output`, `-o` | Output file path (PNG) | `output.png` |
| `--style`, `-s` | Image style: `animation`, `illustration`, or `sketch` | `animation` |
| `--limit`, `-l` | Number of images to generate | `1` |
| `--source-image` | Path to a source image (e.g. a face photo for person prompts) | — |
| `--retry` | Max retries on image generation failure | `3` |
| `--port`, `-p` | TCP port for runner communication | `51573` |
| `--timeout` | Max seconds to wait for the entire operation | `120` |
| `--keep-app` | Keep the temporary .app bundle for debugging | off |

## Examples

```bash
# Specify output path
swift run create-image -o dog.png "a dog playing in snow"

# Use sketch style
swift run create-image --style sketch "a mountain landscape"

# Generate multiple images
swift run create-image --limit 3 -o sunset.png "a sunset"
# Produces: sunset-1.png, sunset-2.png, sunset-3.png

# Generate a person using a source face image
swift run create-image --source-image face.jpg "a person walking in the park"

# Debug mode (keep temp bundle, view logs with: log show --predicate 'subsystem == "create-image"' --last 1m)
swift run create-image --keep-app "a cat"
```

## How it works

`ImageCreator` requires a foreground macOS app launched via Launch Services. A bare executable or `swift run` alone triggers `backgroundCreationForbidden`.

This tool works around that constraint with a two-component architecture:

1. **CreateImage** (CLI launcher) -- parses arguments, builds a temporary `.app` bundle containing the GUI app, launches it via `NSWorkspace.openApplication`, and communicates over TCP to send the request and receive the result.
2. **CreateImageRunner** (GUI app) -- a minimal SwiftUI app that starts a TCP server, receives the image generation request, runs `ImageCreator`, saves the output PNG, sends the result back, and terminates. The window is hidden immediately on launch.

The temporary `.app` bundle is created in the system temporary directory and removed automatically after each run (unless `--keep-app` is specified). The runner process is also terminated via `NSRunningApplication` on cleanup.

## Test resources

`Tests/CreateImageLauncherTests/Resources/HumanFace.jpg` is an AI-generated image and does not depict any real person.
