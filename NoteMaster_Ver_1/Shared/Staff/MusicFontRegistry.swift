//
//  MusicFontRegistry.swift
//  NoteMaster_Ver_1
//
//  Created by Cursor on 2026/3/24.
//

import Foundation
import CoreGraphics
import CoreText

enum MusicFontRegistry {
    private enum BootstrapState: Equatable {
        case idle
        case ready
        case failed(String)
    }

    private enum RegistryError: Error, CustomStringConvertible {
        case resourceNotFound(String)
        case registrationFailed(String)

        var description: String {
            switch self {
            case let .resourceNotFound(fileName):
                return "Music font resource not found: \(fileName)"
            case let .registrationFailed(message):
                return "Music font registration failed: \(message)"
            }
        }
    }

    private static let lock = NSLock()
    private static var bootstrapState: BootstrapState = .idle
    private static var registeredPostScriptNames: [MusicFontFace: String] = [:]

    static func bootstrapIfNeeded(bundle: Bundle = .main) {
        lock.lock()
        defer { lock.unlock() }

        guard bootstrapState == .idle else {
            return
        }

        do {
            try MusicFontFace.allCases.forEach { fontFace in
                try register(fontFace: fontFace, bundle: bundle)
            }
            bootstrapState = .ready
        } catch {
            let message = String(describing: error)
            bootstrapState = .failed(message)
            #if DEBUG
            print(message)
            #endif
        }
    }

    static func font(
        for fontFace: MusicFontFace,
        size: CGFloat,
        bundle: Bundle = .main
    ) -> CTFont? {
        bootstrapIfNeeded(bundle: bundle)

        lock.lock()
        let state = bootstrapState
        let postScriptName = registeredPostScriptNames[fontFace]
        lock.unlock()

        guard case .ready = state, let postScriptName else {
            return nil
        }

        return CTFontCreateWithName(
            postScriptName as CFString,
            max(size, 1),
            nil
        )
    }

    static func registeredPostScriptName(
        for fontFace: MusicFontFace,
        bundle: Bundle = .main
    ) -> String? {
        bootstrapIfNeeded(bundle: bundle)

        lock.lock()
        defer { lock.unlock() }
        return registeredPostScriptNames[fontFace]
    }

    private static func register(
        fontFace: MusicFontFace,
        bundle: Bundle
    ) throws {
        let url = try locateFontURL(for: fontFace, bundle: bundle)
        let postScriptName = resolvedPostScriptName(
            from: url,
            fallback: fontFace.fallbackPostScriptName
        )

        var registrationError: Unmanaged<CFError>?
        let didRegister = CTFontManagerRegisterFontsForURL(
            url as CFURL,
            .process,
            &registrationError
        )

        guard didRegister || canResolveRegisteredFont(named: postScriptName) else {
            let errorDescription = (registrationError?.takeRetainedValue() as Error?)?
                .localizedDescription
                ?? "Unknown error"
            throw RegistryError.registrationFailed(errorDescription)
        }

        registeredPostScriptNames[fontFace] = postScriptName
    }

    private static func locateFontURL(
        for fontFace: MusicFontFace,
        bundle: Bundle
    ) throws -> URL {
        let searchSubdirectories: [String?] = [
            "Shared/Fonts",
            "Fonts",
            nil
        ]

        for subdirectory in searchSubdirectories {
            if let url = bundle.url(
                forResource: fontFace.resourceName,
                withExtension: fontFace.fileExtension,
                subdirectory: subdirectory
            ) {
                return url
            }
        }

        for subdirectory in searchSubdirectories {
            let urls = bundle.urls(
                forResourcesWithExtension: fontFace.fileExtension,
                subdirectory: subdirectory
            ) ?? []
            if let url = urls.first(where: {
                $0.lastPathComponent.caseInsensitiveCompare(fontFace.fileName) == .orderedSame
            }) {
                return url
            }
        }

        throw RegistryError.resourceNotFound(fontFace.fileName)
    }

    private static func resolvedPostScriptName(
        from url: URL,
        fallback: String
    ) -> String {
        guard
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
            let descriptor = descriptors.first,
            let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String,
            !name.isEmpty
        else {
            return fallback
        }

        return name
    }

    private static func canResolveRegisteredFont(named postScriptName: String) -> Bool {
        let font = CTFontCreateWithName(postScriptName as CFString, 12, nil)
        let resolvedName = CTFontCopyPostScriptName(font) as String
        return resolvedName.caseInsensitiveCompare(postScriptName) == .orderedSame
    }
}
