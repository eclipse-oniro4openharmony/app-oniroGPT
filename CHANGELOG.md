# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### Added
- Multi-platform support (Mobile, Wearable, Shared Library)
- Voice input with automatic speech detection (VAD)
- Audio transcription to text using OpenAI API
- Text translation to English
- GPT-4O chat capabilities
- Wearable app with optimized UI for smartwatch
- Image handling in messages
- Microphone permission management

### Fixed
- Fixed inconsistent dependency names in oh-package.json5 files
- Fixed circular dependency between data and shared_library modules
- Fixed wearable chat response delay issue (off-by-one message display)

### Changed
- Updated wearable message handling to display current response immediately

## [1.0.0] - 2025-12-12

### Added
- Initial project setup for OpenHarmony GPT application
- Mobile application module with chat interface
- Wearable application module for smartwatch
- Data module for API interactions
- Shared library module with common utilities
- Audio capture and voice processing
- OpenAI API integration for chat, transcription, and translation
- VAD (Voice Activity Detection) for automatic recording stop
- Message history management with support for images and text

### Features
- Real-time chat with GPT-4o Mini model
- Voice-to-text transcription
- Automatic silence detection after speech
- Multi-platform UI (Mobile and Wearable)
- Local dependency management with ohpm
