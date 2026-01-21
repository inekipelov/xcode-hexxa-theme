import Foundation

struct Options {
    var destination: URL
    var dryRun: Bool
}

enum InstallerError: Error, CustomStringConvertible {
    case missingResourceBundle
    case missingThemesDirectory(URL)
    case invalidArgument(String)
    case fontDownloadFailed(URL)
    case fontExtractionFailed(Int32)
    case missingFontFiles(URL)
    case unzipToolUnavailable

    var description: String {
        switch self {
        case .missingResourceBundle:
            return "Unable to locate bundled themes."
        case .missingThemesDirectory(let url):
            return "Themes directory not found at \(url.path)."
        case .invalidArgument(let argument):
            return "Invalid argument: \(argument)."
        case .fontDownloadFailed(let url):
            return "Failed to download font archive from \(url.absoluteString)."
        case .fontExtractionFailed(let status):
            return "Unzip process failed with exit code \(status)."
        case .missingFontFiles(let url):
            return "Unable to locate Fira Code .ttf files in extracted archive at \(url.path)."
        case .unzipToolUnavailable:
            return "Unable to run /usr/bin/unzip. Ensure the unzip tool is available."
        }
    }
}

@discardableResult
func parseOptions() throws -> Options {
    let defaultDestination = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Developer/Xcode/UserData/FontAndColorThemes")

    var destination = defaultDestination
    var dryRun = false

    var arguments = CommandLine.arguments.dropFirst()
    while let argument = arguments.first {
        arguments = arguments.dropFirst()
        switch argument {
        case "--destination":
            guard let value = arguments.first else {
                throw InstallerError.invalidArgument("--destination requires a path")
            }
            arguments = arguments.dropFirst()
            destination = URL(fileURLWithPath: value).standardizedFileURL
        case "--dry-run":
            dryRun = true
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            throw InstallerError.invalidArgument(argument)
        }
    }

    return Options(destination: destination, dryRun: dryRun)
}

func printUsage() {
    let executable = URL(fileURLWithPath: CommandLine.arguments.first ?? "installer")
        .lastPathComponent
    print("Usage: \(executable) [--destination <path>] [--dry-run]")
    print("\nInstalls the bundled Hexxa Xcode color theme.")
    print("\nOptions:")
    print("  --destination <path>  Override the destination directory")
    print("  --dry-run             Preview actions without copying files")
    print("  -h, --help            Show this message")
}

func locateThemesDirectory() throws -> URL {
    guard let resourceURL = Bundle.module.resourceURL else {
        throw InstallerError.missingResourceBundle
    }

    let themesURL = resourceURL.appendingPathComponent("Themes", isDirectory: true)
    guard FileManager.default.fileExists(atPath: themesURL.path) else {
        throw InstallerError.missingThemesDirectory(themesURL)
    }
    return themesURL
}

func ensureFiraCodeInstalled(dryRun: Bool) throws {
    let fm = FileManager.default
    let fontsDirectory = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Fonts", isDirectory: true)
    let referenceFont = fontsDirectory.appendingPathComponent("FiraCode-Regular.ttf")

    if fm.fileExists(atPath: referenceFont.path) {
        return
    }

    if dryRun {
        print("Would ensure Fira Code fonts are installed at \(fontsDirectory.path)")
        return
    }

    print("Downloading Fira Code font...")
    try fm.createDirectory(at: fontsDirectory, withIntermediateDirectories: true)

    let downloadURL = URL(string: "https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip")!
    let fontArchive: Data
    do {
        fontArchive = try Data(contentsOf: downloadURL)
    } catch {
        throw InstallerError.fontDownloadFailed(downloadURL)
    }

    let tempDirectory = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: tempDirectory) }

    let archiveURL = tempDirectory.appendingPathComponent("FiraCode.zip")
    try fontArchive.write(to: archiveURL)

    let extractionDirectory = tempDirectory.appendingPathComponent("Extracted", isDirectory: true)
    try fm.createDirectory(at: extractionDirectory, withIntermediateDirectories: true)

    let unzipProcess = Process()
    unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    unzipProcess.arguments = ["-o", archiveURL.path, "-d", extractionDirectory.path]

    do {
        try unzipProcess.run()
        unzipProcess.waitUntilExit()
    } catch {
        throw InstallerError.unzipToolUnavailable
    }

    guard unzipProcess.terminationStatus == 0 else {
        throw InstallerError.fontExtractionFailed(unzipProcess.terminationStatus)
    }

    let potentialTTFDirectories: [URL]
    if fm.fileExists(atPath: extractionDirectory.appendingPathComponent("ttf", isDirectory: true).path) {
        potentialTTFDirectories = [extractionDirectory.appendingPathComponent("ttf", isDirectory: true)]
    } else {
        let subfolders = try fm.contentsOfDirectory(
            at: extractionDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        potentialTTFDirectories = subfolders.compactMap { folder in
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return nil
            }
            let nested = folder.appendingPathComponent("ttf", isDirectory: true)
            if fm.fileExists(atPath: nested.path) {
                return nested
            }
            return nil
        }
    }

    guard let ttfDirectory = potentialTTFDirectories.first else {
        throw InstallerError.missingFontFiles(extractionDirectory)
    }

    let fontFiles = try fm.contentsOfDirectory(
        at: ttfDirectory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ).filter { $0.pathExtension.lowercased() == "ttf" }

    guard !fontFiles.isEmpty else {
        throw InstallerError.missingFontFiles(ttfDirectory)
    }

    for font in fontFiles {
        let destination = fontsDirectory.appendingPathComponent(font.lastPathComponent)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: font, to: destination)
    }

    print("Installed Fira Code fonts in \(fontsDirectory.path)")
}

func installThemes(from sourceDirectory: URL, options: Options) throws {
    let fm = FileManager.default

    if !options.dryRun {
        try fm.createDirectory(at: options.destination, withIntermediateDirectories: true)
    }

    let themes = try fm.contentsOfDirectory(
        at: sourceDirectory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ).filter { $0.pathExtension == "xccolortheme" }

    if themes.isEmpty {
        print("No themes found to install at \(sourceDirectory.path)")
        return
    }

    for theme in themes {
        let destination = options.destination.appendingPathComponent(theme.lastPathComponent)
        if options.dryRun {
            print("Would copy \(theme.lastPathComponent) to \(destination.path)")
            continue
        }

        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }

        try fm.copyItem(at: theme, to: destination)
        print("Installed \(theme.lastPathComponent)")
    }
}

func runInstaller() {
    do {
        let options = try parseOptions()
        try ensureFiraCodeInstalled(dryRun: options.dryRun)
        let themesDirectory = try locateThemesDirectory()
        try installThemes(from: themesDirectory, options: options)
        if options.dryRun {
            print("Dry run completed. No files were written.")
        } else {
            print("All themes installed to \(options.destination.path)")
        }
    } catch {
        fputs("Error: \(error)\n", stderr)
        printUsage()
        exit(1)
    }
}

runInstaller()
