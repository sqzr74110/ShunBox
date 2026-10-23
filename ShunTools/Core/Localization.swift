import Foundation

enum AppLanguage {
    static let supported = ["zh-Hans", "zh-Hant", "en", "ja", "ko", "fr", "de", "es", "pt-BR"]
    static var resolved: String {
        let selected = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        if supported.contains(selected) { return selected }
        return Bundle.preferredLocalizations(from: ["en"] + supported.filter { $0 != "en" }, forPreferences: Locale.preferredLanguages).first ?? "en"
    }
    static func nativeName(_ code: String) -> String {
        switch code { case "zh-Hans": "简体中文"; case "zh-Hant": "繁體中文"; case "ja": "日本語"; case "ko": "한국어"; case "fr": "Français"; case "de": "Deutsch"; case "es": "Español"; case "pt-BR": "Português (Brasil)"; default: "English" }
    }
}
/// Resolve dynamic titles, alerts and processor errors through the same language bundle.
func L(_ key: String, _ arguments: String...) -> String {
    let bundle = Bundle.main.path(forResource: AppLanguage.resolved, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    var result = bundle.localizedString(forKey: key, value: key, table: "Localizable")
    let expression = try! NSRegularExpression(pattern: #"\{(\d+)\}"#)
    for match in expression.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
        guard let numberRange = Range(match.range(at: 1), in: result), let number = Int(result[numberRange]), arguments.indices.contains(number), let range = Range(match.range, in: result) else { continue }
        result.replaceSubrange(range, with: arguments[number])
    }
    return result
}
