import SwiftUI
import Manfred
import KeychainAccess

class OnboardingController: ObservableObject {
    static let redirectURI = "oliphaunt://oauth_callback"
    let keychain = Keychain(service: "com.ficklebits.oliphaunt")

    func selectServer(_ server: String) {
        guard let url = URL(string: "https://\(server)") else { return }

        let client = Client(
            baseURL: url,
            adapter: .live().logging(
                requests: .summary,
                responses: .full
            )
        )

        Task {
            let app = try? await findOrCreateAppCredentials(with: client)
            print(app!)
        }
    }

    private func findOrCreateAppCredentials(with client: Client) async throws -> AppCredentials {
        let appKeychainKey = "oliphaunt:app:\(client.baseURL.absoluteString.lowercased())"
        if let existingCredentials = keychain.decodeValue(AppCredentials.self, for: appKeychainKey) {
            return existingCredentials
        }

        let app = try await client.send(
            Apps.create(name: "Oliphaunt",
                        scopes: "read write follow push",
                        website: URL("https://github.com/subdigital/Oliphaunt"),
                        redirectURI: Self.redirectURI)
        )

        let credentials = AppCredentials(
            clientID: app.clientId,
            clientSecret: app.clientSecret,
            vapidKey: app.vapidKey
        )

        keychain.saveEncodedValue(credentials, for: appKeychainKey)

        return credentials
    }
}

extension Keychain {
    func saveEncodedValue<T: Encodable>(_ value: T, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }

        self[data: key] = data
    }

    func decodeValue<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        guard let data = self[data: key] else { return nil }

        return try? JSONDecoder().decode(T.self, from: data)
    }
}

struct AppCredentials: Codable {
    let clientID: String
    let clientSecret: String
    let vapidKey: String
}

struct OnboardingView: View {
    @ObservedObject var onboardingController = OnboardingController()
    @State var selectedServer: String? = nil

    var body: some View {
        InstanceSelectionView(selectedServer: $selectedServer)
            .onChange(of: selectedServer) { newValue in
                if let selectedServer = newValue {
                    onboardingController.selectServer(selectedServer)
                }
            }
    }
}
