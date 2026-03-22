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
| `--output`, `-o` | Output file path | `output.png` |
| `--style`, `-s` | Image style: `animation`, `illustration`, or `sketch` | `animation` |
| `--limit`, `-l` | Number of images to generate | `1` |
| `--source-image` | Path to a source image (e.g. a face photo for person prompts) | — |
| `--retry` | Max retries on image generation failure | `3` |
| `--format`, `-f` | Output format: `png` or `jpg` | `png` |
| `--quality` | JPEG quality (0.0-1.0, only used with `--format jpg`) | — |

## Examples

```bash
# Specify output path
swift run create-image -o dog.png "a dog playing in snow"

# Use sketch style
swift run create-image --style sketch "a mountain landscape"

# Generate multiple images
swift run create-image --limit 3 -o sunset.png "a sunset"
# Produces: sunset-1.png, sunset-2.png, sunset-3.png

# Output as JPEG with quality setting
swift run create-image --format jpg --quality 0.8 -o cat.jpg "a cat"

# Generate a person using a source face image
swift run create-image --source-image face.jpg "a person walking in the park"
```

## Test resources

`Tests/CreateImageCoreTests/Resources/HumanFace.jpg` is an AI-generated image and does not depict any real person.
