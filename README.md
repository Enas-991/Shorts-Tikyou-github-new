# DataCharge — All-in-One Offline Shorts/Reels Hub

A TikTok-style Flutter app that streams and caches YouTube Shorts and TikTok videos for seamless offline playback, powered by a Python FastAPI + yt-dlp backend.

---

## Project Structure

```
datacharge/
├── backend/
│   ├── main.py              ← FastAPI server (Python)
│   └── requirements.txt
└── flutter_app/
    ├── pubspec.yaml
    ├── android/
    │   └── app/src/main/
    │       └── AndroidManifest.xml
    └── lib/
        ├── main.dart                        ← Entry point
        ├── models/
        │   ├── video_model.dart             ← Hive entity
        │   └── video_model.g.dart           ← Generated adapter
        ├── services/
        │   ├── hive_service.dart            ← Local DB wrapper
        │   ├── api_service.dart             ← Backend HTTP client
        │   ├── cache_engine.dart            ← LRU background cacher (2 GB)
        │   ├── connectivity_service.dart    ← Online/offline watcher
        │   └── feed_provider.dart           ← State management
        ├── screens/
        │   ├── feed_screen.dart             ← TikTok-style vertical PageView
        │   └── settings_screen.dart         ← Backend URL + cache controls
        ├── widgets/
        │   ├── video_player_widget.dart     ← Full-screen player
        │   ├── video_meta_overlay.dart      ← Caption / platform badge
        │   ├── side_actions_widget.dart     ← Like / save / share / delete
        │   └── add_video_sheet.dart         ← URL input bottom sheet
        └── utils/
            └── app_theme.dart              ← Dark theme + brand colors
```

---

## 1 — Backend Setup

```bash
cd backend
pip install -r requirements.txt
python main.py
# Server starts on http://0.0.0.0:8000
```

### Test it

```bash
curl -X POST http://localhost:8000/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.youtube.com/shorts/XXXXXXXXX"}'
```

Returns:
```json
{
  "id": "XXXXXXXXX",
  "title": "Video title",
  "platform": "youtube",
  "duration": 58.0,
  "thumbnail": "https://...",
  "direct_url": "https://...mp4...",
  "width": 1080,
  "height": 1920,
  "filesize": 12345678
}
```

---

## 2 — Flutter Setup (Project IDX / VS Code)

### Install dependencies

```bash
cd flutter_app
flutter pub get
```

> **Note:** `video_model.g.dart` is already provided pre-generated.  
> If you change `video_model.dart`, regenerate with:
> ```bash
> flutter pub run build_runner build --delete-conflicting-outputs
> ```

### Configure backend URL

Open `lib/services/api_service.dart` and set `baseUrl`:

| Environment | URL |
|---|---|
| Android Emulator | `http://10.0.2.2:8000` |
| Physical device (same LAN) | `http://192.168.x.x:8000` |
| Production | `https://your-server.com` |

You can also change this at runtime in the app's **Settings** screen.

### Run

```bash
flutter run
```

---

## 3 — Fonts (Optional)

`pubspec.yaml` references **Gilroy** fonts. If you don't have the `.ttf` files:

1. Remove the `fonts:` block from `pubspec.yaml`, OR
2. Replace with a Google Font — add `google_fonts: ^6.2.1` to `pubspec.yaml` and update `app_theme.dart`:

```dart
import 'package:google_fonts/google_fonts.dart';

// In AppTheme.dark:
textTheme: GoogleFonts.soraTextTheme(ThemeData.dark().textTheme),
```

---

## 4 — Asset Placeholders

Create these directories (they're referenced in `pubspec.yaml`):

```bash
mkdir -p flutter_app/assets/images
mkdir -p flutter_app/assets/animations
mkdir -p flutter_app/assets/fonts
```

Add any placeholder `.png` or `.json` (Lottie) files you wish, or remove the `assets:` block from `pubspec.yaml`.

---

## 5 — How It Works

### Online mode
1. User pastes a TikTok/YouTube Shorts URL into the **Add Video** sheet.
2. App calls `POST /extract` on the Python backend.
3. yt-dlp resolves a direct, no-watermark MP4 URL.
4. The URL is stored in **Hive** as a `VideoModel`.
5. The `video_player` package streams directly from the URL.

### Offline mode
1. While online, `CacheEngine` downloads the **next 3 videos** to local storage.
2. When the device goes offline, `ConnectivityService` notifies the feed.
3. The player reads `video.localFilePath` instead of `remoteUrl`.
4. The **offline banner** appears at the top of the feed.

### LRU 2 GB Cache
- `CacheEngine._enforceLimit()` is called before and after every download.
- It sorts cached videos by `lastAccessedMs` ascending (oldest first).
- It deletes files + resets Hive records until total bytes ≤ 2 GB.
- `VideoModel.touch()` updates `lastAccessedMs` on every play.

---

## 6 — Supported Platforms

| Platform | Supported |
|---|---|
| YouTube Shorts | ✅ |
| TikTok | ✅ |
| Instagram Reels | ❌ (not in scope) |
| Facebook Reels | ❌ (not in scope) |

---

## 7 — Production Checklist

- [ ] Deploy the Python backend to a VPS / cloud instance (e.g. Railway, Render, Fly.io).
- [ ] Set `baseUrl` to your production HTTPS URL.
- [ ] Remove `android:usesCleartextTraffic="true"` from `AndroidManifest.xml` once on HTTPS.
- [ ] Add rate limiting + auth token to the FastAPI server.
- [ ] Set up a CI/CD pipeline (GitHub Actions + Fastlane).
- [ ] Enable ProGuard/R8 in `android/app/build.gradle` for release builds.
- [ ] Test on a physical Android & iOS device.
