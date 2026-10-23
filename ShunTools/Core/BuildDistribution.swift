import Foundation

enum BuildDistribution {
    static var isSideload: Bool {
        #if SIDELOAD
        true
        #else
        false
        #endif
    }
    static let repository = URL(string: "https://github.com/sqzr74110/ShunBox")!
}
