# TextCast iOS App

A minimal, simple iOS client for
[Audiobookshelf](https://www.audiobookshelf.org/) servers, designed to play
audiobooks and podcasts with a clean, focused interface.

## Vision

This app aims to be the simplest possible Audiobookshelf client - focusing on
core functionality without overcomplicating the user experience. The initial
version features only two tabs:

- **Latest**: Your listening queue with recently added items and playback controls
- **Settings**: Server configuration and basic preferences

## Requirements

## Getting Started

### 1. Create GitHub Repository (First Time Setup)

Create a private GitHub repository for the project:

```bash
# Navigate to project directory
cd /Users/ivan/Sources/github.com/ivankovnatsky/textcast-ios-app

# Initialize git if not already done
git init

# Create private GitHub repository
gh repo create ivankovnatsky/textcast-ios-app --private --source=. --remote=origin
```

### 2. Open the Project

Open the existing Xcode project:

```bash
cd /Users/ivan/Sources/github.com/ivankovnatsky/textcast-ios-app
open TextCastApp.xcodeproj
```

### 3. Build and Run

#### Using Makefile (Recommended)

The project includes a Makefile for common development tasks:

```bash
# Show available commands
make help

# Build the app
make build

# Install to simulator
make install

# Launch on simulator
make launch

# Build, install, and launch in one command
make run
```

#### Using Xcode GUI

1. Open `TextCastApp.xcodeproj` in Xcode
2. Select an iOS simulator (iOS 18+) from the device dropdown
3. Press `Cmd+R` to build and run

#### Using Command Line (Manual)

```bash
# Build for iOS Simulator
xcodebuild -scheme TextCastApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Install to simulator
xcrun simctl install <SIMULATOR_ID> <APP_PATH>

# Launch on simulator
xcrun simctl launch <SIMULATOR_ID> ivankovnatsky.TextCastApp
```

#### Running on Physical Device

**Prerequisites:**
1. **Enable Developer Mode on iPhone**:
   - Go to **Settings → Privacy & Security → Developer Mode**
   - Toggle **Developer Mode** ON
   - Restart your iPhone when prompted
   - Confirm activation after restart

2. **Select Your Device in Xcode**:
   - Connect iPhone via USB
   - Select your iPhone from the device dropdown in Xcode
   - Xcode will automatically handle code signing with your Apple ID

3. **Build and Install**:
   - Press `Cmd+R` in Xcode
   - Xcode will build and install the app on your device

4. **Trust Developer App Certificate on iPhone** (First time only):
   - After installation, the app icon will appear on your home screen
   - Tapping it will show an **"Untrusted Developer"** alert
   - Open **Settings** on the device
   - Navigate to **General → VPN & Device Management**
   - Select your **Developer App certificate** to trust it
   - Tap **Trust** in the confirmation dialog
   - Return to home screen and launch the app

**Note**: Free Apple IDs can install apps on devices for 7 days before needing to rebuild. Apple Developer Program members ($99/year) get 1-year certificates.

### 4. Configure Audiobookshelf Server

On first launch, you'll see the login screen. Enter your Audiobookshelf server details:

- **Server URL**: Can be entered with or without `http://` or `https://` scheme
  - App will try HTTPS first, then fallback to HTTP if HTTPS fails
  - Examples: `192.168.1.100:13378`, `audiobookshelf.local`, `https://abs.example.com`
- **Username**: Your Audiobookshelf username
- **Password**: Your Audiobookshelf password

The app will automatically save your credentials for future launches.

## Features

### Latest Tab
- Display recent podcast episodes from your Audiobookshelf server
- Shows cover art, title, author/podcast name, and progress
- **Tap episode** to open full-screen player and start playback
- **Swipe left to delete** item from queue (local only)
- **Long-press context menu** with options:
  - Play - Opens player
  - Mark as Finished - Completes and removes from queue (TODO: sync to server)
  - Restart - Resets progress to 0% (TODO: sync to server)
  - Remove from Queue - Deletes item (local only)
- **Pull to refresh** to reload latest episodes
- Empty state with helpful message

### Player View
- Full-screen player with cover art and episode info
- **Auto-play** on open (starts playback automatically after 1 second)
- Play/pause button
- Skip forward/backward (15 seconds)
- Seek bar with drag-to-seek functionality
- Current time and total duration display
- **Progress syncing** to server:
  - Syncs every 30 seconds during playback
  - Syncs on pause
  - Final sync when closing player
- Loads last playback position from server

### Settings Tab
- Server connection info (URL and username)
- **Logout** - Clears credentials and returns to login
- **About** section with:
  - App version
  - Debug logs toggle (enables Logs tab)
  - Link to GitHub source code

### Logs Tab (Debug)
- Enable via Settings → About → Logs toggle
- View detailed app logs with timestamps, levels, and source locations
- **Copy All** - Copy entire log to clipboard for debugging
- **Clear** - Remove all logs
- Shows API calls, playback events, errors, and progress syncs

## Technology Stack

- **Language**: Swift 6
- **UI Framework**: SwiftUI
- **Minimum iOS**: 18.0
- **Architecture**: MVVM (Model-View-ViewModel)
- **Networking**: URLSession with async/await
- **Audio Playback**: AVFoundation (AVPlayer)
- **Concurrency**: Swift Structured Concurrency (async/await, actors, @MainActor)
- **Logging**: Custom AppLogger service with @Published logs
- **State Management**: Combine (@Published, ObservableObject)

## API Integration

This app uses the [Audiobookshelf API](https://api.audiobookshelf.org/). Currently implemented endpoints:

### Authentication
- `POST /login` - Login and get auth token ✅

### Library & Episodes
- `GET /api/libraries` - Get all libraries ✅
- `GET /api/libraries/{libraryId}/episodes?limit=25` - Get recent podcast episodes ✅

### Playback
- `POST /api/items/{libraryItemId}/play/{episodeId}` - Create playback session and get stream URL ✅
  - Sends device info, returns playback session with audioTracks
  - For podcast episodes, uses composite ID format: "libraryItemId/episodeId"
- `POST /api/session/{sessionId}/sync` - Sync playback progress ✅
  - Sends currentTime, duration, timeListened
  - Called every 30s during playback + on pause + on close

### Progress Data
- Episode progress loaded from `mediaProgress` field in episode responses ✅
- Shows current position on queue items

## Development Philosophy

**Keep it simple.** This app intentionally:

- Starts with minimal features
- Focuses on core use case (playing from queue)
- Avoids feature creep
- Maintains clean, readable code
- Uses native iOS patterns and conventions

## Current Status & Roadmap

### ✅ Completed (MVP - Working App)
- [x] Project structure with Xcode project
- [x] Authentication flow with server login
- [x] HTTP/HTTPS auto-detection with fallback
- [x] Queue view showing recent podcast episodes
- [x] Queue item management (swipe-to-delete, context menu)
- [x] Full-screen player with audio streaming
- [x] Auto-play when tapping episodes
- [x] Play/pause, skip forward/backward (15s)
- [x] Seek bar with current time display
- [x] Progress syncing to Audiobookshelf server (every 30s + on pause/close)
- [x] Progress loading from server (resume playback position)
- [x] Settings screen with logout
- [x] Debug logging system with toggle and log viewer
- [x] Makefile for build/install/launch
- [x] Cover art loading from server

### 🐛 Known Issues & Limitations
- Queue management (delete, mark finished, restart) only works locally - not synced to server
- Only shows podcast episodes (not audiobooks yet)
- No background playback support yet
- No lock screen controls
- No offline caching
- No chapters support
- No playback speed control
- Cancellation errors when pull-to-refresh interrupts loading (harmless, now ignored)

### 📋 Planned Next (Phase 2 - Polish)
- [ ] Implement server-side queue management (mark finished, restart progress)
- [ ] Add audiobook support (not just podcasts)
- [ ] Background playback with AVAudioSession
- [ ] Lock screen controls (MPNowPlayingInfoCenter)
- [ ] Better error messages and retry logic
- [ ] Loading states and skeleton views
- [ ] Cover art caching

### 🔮 Future Enhancements (Phase 3+)
- [ ] Offline downloads
- [ ] Search functionality
- [ ] Library browsing
- [ ] Chapters support
- [ ] Sleep timer
- [ ] Playback speed control (0.5x - 2.0x)
- [ ] CarPlay support
- [ ] Home screen widgets
- [ ] Siri shortcuts

## Architecture Notes

### Key Design Decisions

- **Composite Episode IDs**: Podcast episodes use format `"libraryItemId/episodeId"` to support the playback endpoint structure
- **Playback Sessions**: Audio streaming requires creating a playback session (POST to `/play`) which returns stream URLs and session IDs
- **Progress Syncing**: Periodic sync (30s) + event-based sync (pause, close) for reliable progress tracking
- **Actor Isolation**: API client uses `actor` for thread-safe networking state
- **@MainActor**: ViewModels and UI-related services use `@MainActor` for safe UI updates
- **Optional Progress**: MediaProgress fields are optional to support episodes without playback history
- **Error Handling**: NSURLErrorCancelled ignored as expected behavior when refreshing

### File Structure

```
TextCastApp/
├── App/
│   └── TextCastApp.swift              # Main app, AuthenticationState, login flow
├── Views/
│   ├── ContentView.swift              # Root view with tabs
│   ├── Queue/
│   │   ├── QueueView.swift            # Latest episodes list
│   │   ├── QueueItemRow.swift         # Queue item cell
│   │   └── PlayerView.swift           # Full-screen player
│   └── Settings/
│       ├── SettingsView.swift         # Settings tab
│       └── LogsView.swift             # Debug logs viewer
├── ViewModels/
│   └── QueueViewModel.swift           # Queue state, API calls
├── Models/
│   ├── QueueItem.swift                # Queue item model
│   └── AudiobookshelfModels.swift     # API response models
├── Services/
│   ├── AudiobookshelfAPI.swift        # API client (actor)
│   ├── AudioPlayerService.swift       # AVPlayer wrapper
│   ├── PlaybackSessionManager.swift   # Session state tracking
│   └── Logger.swift                   # AppLogger service
└── Resources/
    └── Assets.xcassets                # Images, icons
```

## Debugging

### Using Debug Logs

1. Enable logs in Settings → About → Logs toggle
2. Open Logs tab from bottom navigation
3. Watch logs in real-time while using the app
4. Use "Copy All" to export logs for analysis
5. Look for these log levels:
   - `DEBUG`: Detailed info (API calls, ID parsing)
   - `INFO`: Normal events (loaded episodes, sync)
   - `WARNING`: Recoverable issues (missing fields)
   - `ERROR`: Failures (API errors, network issues)

## Inspiration

Inspired by other Audiobookshelf clients but intentionally simpler:
- [Plappa](https://github.com/LeoKlaus/plappa) - Feature-rich client
- [ShelfPlayer](https://github.com/rasmuslos/ShelfPlayer) - Swift 6, iOS 18+ native
- [Official Audiobookshelf App](https://github.com/advplyr/audiobookshelf-app) - Reference implementation

## Related Projects

- [textcast](../textcast) - CLI tool for converting text to audio using AI TTS
- [textcast-service](../textcast-service) - Service backend for textcast
- [Audiobookshelf](https://github.com/advplyr/audiobookshelf) - Self-hosted audiobook and podcast server
