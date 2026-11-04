import Foundation

struct PasswordGenerator {
    struct Options {
        var length:           Int  = 20
        var uppercase:        Bool = true
        var lowercase:        Bool = true
        var digits:           Bool = true
        var symbols:          Bool = true
        var excludeAmbiguous: Bool = true
    }

    func generate(options: Options = Options()) -> String {
        var pool = ""
        if options.uppercase { pool += "ABCDEFGHJKLMNPQRSTUVWXYZ" }
        if options.lowercase { pool += "abcdefghjkmnpqrstuvwxyz"  }
        if options.digits    { pool += "23456789"                  }
        if options.symbols   { pool += "!@#$%^&*-_=+?"            }

        if !options.excludeAmbiguous {
            if options.uppercase { pool += "IO" }
            if options.lowercase { pool += "il" }
            if options.digits    { pool += "01" }
        }

        guard !pool.isEmpty, options.length > 0 else { return "" }
        return String((0..<options.length).map { _ in pool.randomElement()! })
    }
}
