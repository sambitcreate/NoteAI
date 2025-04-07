# Noteai

Noteai is an iOS app for note-taking with AI capabilities using the on-device Gemma model.

## Features

- Create and manage different types of notes (text, audio, image, PDF)
- AI-powered summarization
- Chat with note content
- Flashcard generation and review
- Quiz generation and taking
- Audio recording and transcription

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.5+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/sambitcreate/NoteAI.git
cd NoteAI
```

2. Download the Gemma model:
   - Visit [Hugging Face](https://huggingface.co/google/gemma-3b-4b-it)
   - Download the model and convert it to TensorFlow Lite format
   - Place the `.tflite` file in the `Noteai/Noteai` directory

3. Open the project in Xcode:
```bash
open Noteai/Noteai.xcodeproj
```

4. Build and run the app on a simulator or device.

## Model Setup

To use the Gemma model in the app, you need to:

1. Download the Gemma 3B-4B model from Hugging Face
2. Convert it to TensorFlow Lite format using the TensorFlow Lite converter:
```bash
python -m tensorflow.lite.python.tflite_convert \
  --saved_model_dir=gemma_saved_model \
  --output_file=gemma-3b-4b-it.tflite \
  --quantize_weights=true
```
3. Add the `.tflite` file to your Xcode project

## Architecture

The app is built with:
- SwiftUI for the UI
- SwiftData for data persistence
- TensorFlow Lite for on-device AI inference

## License

This project is licensed under the MIT License - see the LICENSE file for details.
