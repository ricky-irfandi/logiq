## 1.0.0-beta.3

* Added category tabs for debug UI - organize logs into custom tabs by category
* New `DebugTab` class for configuring tabs with name, categories, and optional icon
* `DebugViewerConfig` now accepts a `tabs` parameter for tab configuration
* Backwards compatible - empty tabs shows current single-view behavior

## 1.0.0-beta.2

* Fixed deprecated `withOpacity` warning with compatibility extension for Flutter 3.24+
* Updated `share_plus` integration to v11.x API (`SharePlus.instance.share()`)
* Improved code quality and analysis compliance
* Minor performance improvements in log viewer

## 1.0.0-beta.1

* Debug UI redesign
* Added Light/Dark theme toggle and smooth transitions
* Enhanced Debug UI with improved filtering, glassmorphism, and search

## 1.0.0-alpha

* Initial release
* Zero-impact logging with isolate-based file I/O
* Multiple format support (PlainText, JSON, Compact JSON, CSV)
* File rotation strategies (multi-file and single-file)
* AES-256-GCM encryption
* PII redaction with built-in patterns
* Log export with GZip compression
* Debug UI with log viewer and floating button
* Session tracking and statistics
* Auto-cleanup and retention policies
* Sensitive mode for pausing logs
* Context injection and custom sinks
