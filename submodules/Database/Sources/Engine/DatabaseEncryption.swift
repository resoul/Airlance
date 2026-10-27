import Foundation

enum DatabaseEncryption: Sendable {
    case none
    case key(Data)
}
