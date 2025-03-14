# Teams Meeting Assistant

A macOS application that automatically joins Microsoft Teams meetings, handles permissions, records audio, transcribes using Whisper AI, and forwards transcripts to N8N.io.

## Features

- Automatically joins Microsoft Teams meetings at scheduled times
- Handles permission dialogs (both app and system)
- Fills in user information when required
- Ensures camera and microphone are enabled
- Records meeting audio
- Transcribes audio using OpenAI's Whisper AI
- Forwards transcriptions to N8N.io via webhook
- Stays in meetings until everyone leaves or the meeting ends
- Supports one-time and recurring meetings

## Requirements

- macOS 12.0+ (Monterey or newer)
- Microsoft Teams for macOS installed
- OpenAI API key for Whisper AI transcription
- N8N.io webhook endpoint

## Installation

1. Download the latest release from the Releases page
2. Move TeamsAssistant.app to your Applications folder
3. Launch the application
4. Configure your settings on first launch

## Configuration

On first launch, you'll need to provide:

- Your first name (for meeting identification)
- Your OpenAI API key (for Whisper AI transcription)
- N8N.io webhook URL (pre-configured)

## Usage

### Adding a Meeting

1. Click the "Add Meeting" button
2. Paste your Microsoft Teams meeting link
3. Select if the meeting is one-time or recurring
4. Enter meeting details (title, notes)
5. Set the meeting time
6. Click "Save"

### Managing Meetings

- View upcoming meetings in the Meetings tab
- Edit or delete meetings as needed
- Monitor meeting statuses in real-time

## Permissions

The application requires the following permissions:

- Microphone access (for audio recording)
- Screen recording (for detecting meeting status)
- Automation (for handling permission dialogs)
- Accessibility (for UI automation)

## Privacy

- Audio recordings are processed locally and then sent to OpenAI for transcription
- Only transcriptions are forwarded to N8N.io
- No meeting video is ever recorded or transmitted
- Your OpenAI API key is stored securely in the system keychain

## Troubleshooting

If you encounter issues:

1. Ensure Microsoft Teams is installed and up to date
2. Verify your OpenAI API key is valid
3. Check that the application has the necessary permissions
4. Restart the application and try again

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- OpenAI for the Whisper AI API
- N8N.io for webhook functionality
- Microsoft Teams for enabling programmatic meeting access
