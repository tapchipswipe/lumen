import OSLog

enum Log {
    static let subsystem = "com.lumen.app"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let collectors = Logger(subsystem: subsystem, category: "collectors")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let store = Logger(subsystem: subsystem, category: "store")
}
