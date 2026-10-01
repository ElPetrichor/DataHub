import Photos
import SwiftUI

enum PhotoSource: Hashable {
    case allPhotos
    case collection(String)
}

struct AlbumInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let count: Int
    let systemImage: String
}

enum LumenError: LocalizedError {
    case imageUnavailable
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .imageUnavailable: "The photo couldn't be loaded."
        case .renderFailed: "The photo couldn't be rendered."
        }
    }
}

/// Access to the Photos library: authorization, albums, asset fetches and display images.
@MainActor
@Observable
final class PhotoLibrary: NSObject, PHPhotoLibraryChangeObserver {
    private(set) var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    private(set) var smartAlbums: [AlbumInfo] = []
    private(set) var albums: [AlbumInfo] = []
    /// Bumped whenever the Photos library changes so views can refetch.
    private(set) var revision = 0

    @ObservationIgnored private let imageManager = PHCachingImageManager()
    @ObservationIgnored private let renderCache = NSCache<NSString, CGImage>()
    @ObservationIgnored private let originalCache = NSCache<NSString, CGImage>()
    @ObservationIgnored private var isObserving = false

    var isAuthorized: Bool { status == .authorized || status == .limited }

    override init() {
        super.init()
        renderCache.countLimit = 400
        originalCache.countLimit = 200
        startIfAuthorized()
    }

    func requestAccess() async {
        status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        startIfAuthorized()
    }

    /// Re-reads the authorization status, e.g. after returning from Settings.
    func refreshStatus() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        startIfAuthorized()
    }

    private func startIfAuthorized() {
        guard isAuthorized else { return }
        if !isObserving {
            PHPhotoLibrary.shared().register(self)
            isObserving = true
        }
        loadAlbums()
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            self.revision += 1
            self.loadAlbums()
        }
    }

    // MARK: Albums

    private func loadAlbums() {
        let smartTypes: [(PHAssetCollectionSubtype, String)] = [
            (.smartAlbumFavorites, "heart"),
            (.smartAlbumRecentlyAdded, "clock"),
            (.smartAlbumSelfPortraits, "person.crop.square"),
            (.smartAlbumDepthEffect, "cube"),
            (.smartAlbumPanoramas, "pano"),
            (.smartAlbumRAW, "r.square"),
            (.smartAlbumScreenshots, "camera.viewfinder"),
        ]
        smartAlbums = smartTypes.compactMap { subtype, symbol in
            guard let collection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil).firstObject else { return nil }
            let count = Self.imageCount(in: collection)
            guard count > 0 || subtype == .smartAlbumFavorites else { return nil }
            return AlbumInfo(id: collection.localIdentifier, title: collection.localizedTitle ?? "Album", count: count, systemImage: symbol)
        }

        var userAlbums: [AlbumInfo] = []
        PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil).enumerateObjects { collection, _, _ in
            let count = Self.imageCount(in: collection)
            guard count > 0 else { return }
            userAlbums.append(AlbumInfo(id: collection.localIdentifier, title: collection.localizedTitle ?? "Album", count: count, systemImage: "rectangle.stack"))
        }
        albums = userAlbums.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func title(for source: PhotoSource) -> String {
        switch source {
        case .allPhotos:
            return "All Photos"
        case .collection(let id):
            return (smartAlbums + albums).first { $0.id == id }?.title ?? "Album"
        }
    }

    // MARK: Fetching

    nonisolated static func imageFetchOptions(newestFirst: Bool = true) -> PHFetchOptions {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: !newestFirst)]
        return options
    }

    nonisolated static func imageCount(in collection: PHAssetCollection) -> Int {
        PHAsset.fetchAssets(in: collection, options: imageFetchOptions()).count
    }

    nonisolated static func fetchAssets(in source: PhotoSource, newestFirst: Bool) -> [PHAsset] {
        let options = imageFetchOptions(newestFirst: newestFirst)
        let result: PHFetchResult<PHAsset>
        switch source {
        case .allPhotos:
            result = PHAsset.fetchAssets(with: options)
        case .collection(let id):
            guard let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject else { return [] }
            result = PHAsset.fetchAssets(in: collection, options: options)
        }
        return result.objects(at: IndexSet(integersIn: 0..<result.count))
    }

    // MARK: Images

    /// A display image for `asset`: the Photos thumbnail when Lumen has no edits for it,
    /// otherwise the unadjusted original rendered through `settings`.
    func image(for asset: PHAsset, settings: EditSettings?, pixelSize: CGFloat) async -> Image? {
        guard let settings, !settings.isIdentity else {
            guard let thumbnail = await thumbnail(for: asset, pixelSize: pixelSize) else { return nil }
            return Image(platformImage: thumbnail)
        }

        let key = "\(asset.localIdentifier)|\(Int(pixelSize))|\(settings.hashValue)" as NSString
        if let cached = renderCache.object(forKey: key) {
            return Image(decorative: cached, scale: 1)
        }
        guard let original = await original(for: asset, pixelSize: pixelSize) else { return nil }
        let rendered = await Task.detached(priority: .userInitiated) {
            let processor = ImageProcessor.shared
            return processor.render(processor.apply(settings, to: CIImage(cgImage: original)))
        }.value
        guard let rendered else { return nil }
        renderCache.setObject(rendered, forKey: key)
        return Image(decorative: rendered, scale: 1)
    }

    private func thumbnail(for asset: PHAsset, pixelSize: CGFloat) async -> PlatformImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let size = CGSize(width: pixelSize, height: pixelSize)
        return await withCheckedContinuation { continuation in
            // With .highQualityFormat the handler is called exactly once.
            imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private func original(for asset: PHAsset, pixelSize: CGFloat) async -> CGImage? {
        let key = "\(asset.localIdentifier)|\(Int(pixelSize))" as NSString
        if let cached = originalCache.object(forKey: key) { return cached }
        guard let data = try? await ImageSource.originalData(for: asset) else { return nil }
        let image = await Task.detached(priority: .userInitiated) {
            ImageSource.downsample(data, maxPixelSize: Int(pixelSize))
        }.value
        if let image { originalCache.setObject(image, forKey: key) }
        return image
    }
}

/// Loading the unadjusted original, which is what Lumen's edits apply to.
enum ImageSource {
    static func originalData(for asset: PHAsset) async throws -> Data {
        let options = PHImageRequestOptions()
        options.version = .unadjusted
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: (info?[PHImageErrorKey] as? Error) ?? LumenError.imageUnavailable)
                }
            }
        }
    }

    /// Decodes an upright image whose longest edge is at most `maxPixelSize`. ImageIO only decodes what it needs.
    static func downsample(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// The full-resolution, upright original.
    static func fullImage(_ data: Data) -> CIImage? {
        CIImage(data: data, options: [.applyOrientationProperty: true])
    }
}
