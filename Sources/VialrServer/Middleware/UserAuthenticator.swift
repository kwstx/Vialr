import Vapor
import JWT

public struct UserAuthenticator: AsyncJWTAuthenticator {
    public typealias Payload = UserPayload

    public init() {}

    public func authenticate(jwt: UserPayload, for request: Request) async throws {
        request.auth.login(jwt)
    }
}
