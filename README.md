# Lumen

A Lightroom-style photo organizer and editor for iPad and iPhone, built with SwiftUI, PhotoKit, Core Image and SwiftData.

Lumen is an **App Playground** (`Lumen.swiftpm`). You don't need Xcode to run it.

## Run it

**On iPad**
1. Install [Swift Playgrounds](https://apps.apple.com/app/swift-playgrounds/id908519492) (free) from the App Store.
2. Copy the `Lumen.swiftpm` folder to the iPad, e.g. via iCloud Drive or AirDrop.
3. In the Files app, tap `Lumen.swiftpm`. It opens in Swift Playgrounds. Tap **▶︎ Run**.
4. Allow photo library access when asked.

**On a Mac**
1. Install Swift Playgrounds from the Mac App Store.
2. Double-click `Lumen.swiftpm` and press **Run**.

Running the app on an iPhone requires uploading it to TestFlight from Swift Playgrounds (*App Settings → Upload to App Store Connect*), which needs a paid Apple Developer account.

## Features

**Library**
- Browse all photos, smart albums (Favorites, Recents, Selfies, Portrait, Panoramas, RAW, Screenshots) and your albums
- Filter bar: flag (picks, rejects, unflagged, hide rejects), minimum star rating, color label, and edited only
- Sort newest or oldest first, with three thumbnail sizes
- Multi-select with batch rating, flagging, labeling, paste settings, apply preset, reset and save
- Context menu on every photo: copy and paste develop settings between photos

**Loupe (culling)**
- Full-screen swipe-through viewer with pinch and double-tap zoom
- 1–5 star ratings, pick/reject flags and color labels
- An info panel shows the file name, dimensions, camera, lens, focal length, aperture, shutter speed and ISO

**Develop**
- Light: Exposure, Contrast, Highlights, Shadows, Whites, Blacks, plus **Auto**
- Color: Temperature, Tint, Vibrance, Saturation, Black & White
- Effects: Clarity, Vignette, Grain
- Detail: Sharpening, Noise Reduction
- Crop: aspect presets, a draggable crop with a rule-of-thirds grid, straighten with auto-fill, rotate and flip
- 10 built-in presets with live thumbnails, and your own saved presets
- Live RGB histogram. Press and hold the photo to compare with the original
- Full undo/redo. Double-tap a slider label to reset it

**Non-destructive by design**
- Ratings, flags, labels and edits live in Lumen's catalog (SwiftData). The Photos library isn't touched until you choose to save.
- **Save to Photos** writes the edit as a Photos adjustment. The original is kept, and you can revert it in the Photos app at any time. Batch saves ask for permission only once.
- **Save as Copy** adds a new photo instead. **Share** exports a full-resolution JPEG with the original metadata.
- Edits always apply to the unadjusted original. Saving from Lumen replaces edits made to that photo in other apps.

## Code layout

```
Lumen.swiftpm/
├── Package.swift            App Playground manifest (bundle ID, icon, photo permissions)
├── App/                     App entry point, root navigation, onboarding
├── Models/                  EditSettings, slider definitions, presets, SwiftData catalog
├── Services/
│   ├── ImageProcessor.swift Core Image develop pipeline, histogram, JPEG export
│   ├── PhotoLibrary.swift   PhotoKit access, albums, thumbnails, original loading
│   └── PhotoExporter.swift  Saving edits to Photos, copies, share sheet export
└── Views/                   Library grid, loupe, editor, shared controls
```
