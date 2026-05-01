import SwiftUI
import Infrastructure

// MARK: - Theme Registry

/// Manages available themes in the application.
/// Follows the same pattern as `AIProviders` for provider registration.
///
/// ## Usage
/// ```swift
/// // Get a theme by ID
/// let theme = ThemeRegistry.shared.theme(for: "dark")
///
/// // Register a custom theme
/// ThemeRegistry.shared.register(MyCustomTheme())
///
/// // Get all available themes
/// let allThemes = ThemeRegistry.shared.allThemes
/// ```
@MainActor
public final class ThemeRegistry {
    /// Shared singleton instance
    public static let shared = ThemeRegistry()

    /// Registered themes keyed by ID
    private var themes: [String: any AppThemeProvider] = [:]

    /// Order of theme IDs for consistent display
    private var themeOrder: [String] = []

    private let importedThemeStore = ImportedThemeStore()

    /// Initialize with built-in themes
    private init() {
        registerBuiltInThemes()
        loadImportedThemes()
    }

    /// Register all built-in themes
    private func registerBuiltInThemes() {
        register(CLITheme())
    }

    // MARK: - Public API

    /// Register a theme. If a theme with the same ID exists, it will be replaced.
    /// - Parameter theme: The theme to register
    public func register(_ theme: any AppThemeProvider) {
        let isNew = themes[theme.id] == nil
        themes[theme.id] = theme
        if isNew {
            themeOrder.append(theme.id)
        }
    }

    /// Get a theme by its ID
    /// - Parameter id: The theme ID
    /// - Returns: The theme if found, nil otherwise
    public func theme(for id: String) -> (any AppThemeProvider)? {
        themes[id]
    }

    /// All registered themes in registration order
    public var allThemes: [any AppThemeProvider] {
        themeOrder.compactMap { themes[$0] }
    }

    /// All theme IDs in registration order
    public var allThemeIds: [String] {
        themeOrder
    }

    /// The default theme (CLI)
    public var defaultTheme: any AppThemeProvider {
        themes["cli"] ?? CLITheme()
    }

    /// Resolve a theme ID to a concrete theme
    /// - Parameters:
    ///   - id: The theme ID
    ///   - systemColorScheme: The current system color scheme (unused, kept for API compatibility)
    /// - Returns: The resolved theme
    public func resolveTheme(for id: String, systemColorScheme: ColorScheme) -> any AppThemeProvider {
        themes[id] ?? defaultTheme
    }

    // MARK: - Imported Themes

    /// Load imported themes from ~/.claude4usages/themes/
    private func loadImportedThemes() {
        for (scheme, _) in importedThemeStore.loadAll() {
            let props = TerminalThemeGenerator.generate(from: scheme)
            let theme = ImportedTerminalTheme(props: props, scheme: scheme)
            register(theme)
        }
    }

    /// Import a `.itermcolors` file, persist the color scheme, and register the generated theme.
    /// - Parameter url: Path to the `.itermcolors` file.
    /// - Returns: The generated ``AppThemeProvider`` theme.
    /// - Throws: ``ITermColorsParserError`` if the file cannot be parsed.
    @discardableResult
    public func importItermcolors(from url: URL) throws -> any AppThemeProvider {
        let scheme = try ITermColorsParser.parse(from: url)
        try importedThemeStore.save(scheme)
        let props = TerminalThemeGenerator.generate(from: scheme)
        let theme = ImportedTerminalTheme(props: props, scheme: scheme)
        register(theme)
        return theme
    }

    /// Remove an imported theme by its ID. Built-in themes are not affected.
    /// - Parameter id: The theme ID (e.g., `"imported-dracula"`).
    public func removeImportedTheme(id: String) {
        guard let theme = themes[id], theme is ImportedTerminalTheme else { return }
        let displayName = theme.displayName
        themes.removeValue(forKey: id)
        themeOrder.removeAll { $0 == id }
        try? importedThemeStore.delete(name: displayName)
    }

    /// Whether a theme is imported (vs built-in).
    public func isImported(id: String) -> Bool {
        themes[id] is ImportedTerminalTheme
    }
}

