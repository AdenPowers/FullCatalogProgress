import Foundation

/// Generic pagination wrapper for endpoints returning `{ data: [...], meta: { ... } }`
private struct PaginatedResponse<T: Codable>: Codable {
    let data: [T]
}

/// Error envelope returned by Printify API when requests fail.
private struct APIErrorResponse: Codable {
    let status: String
    let code: Int
    let message: String
    struct ErrorDetail: Codable {
        let reason: String?
        let code: Int?
    }
    let errors: ErrorDetail?
}


/// Wrapper for shipping response from Printify
private struct BlueprintShippingResponse: Codable {
    let handlingTime: ShippingHandlingTime
    let profiles: [ShippingProfile]
}

/// Wrapper for provider-level variants response
private struct VariantListResponse: Codable {
    let variants: [Variant]
}

struct ShippingHandlingTime: Codable {
    let value: Int
    let unit: String
}

private struct ShippingProfile: Codable {
    let variantIds: [Int]
    let firstItem: ShippingRate
    let additionalItems: ShippingRate
    let countries: [String]
}

struct ShippingRate: Codable {
    let cost: Int
    let currency: String
}

/// Detailed shipping option for a single variant
struct ShippingOption: Codable {
    let variantId: Int
    let handlingTime: ShippingHandlingTime
    let firstItemCost: ShippingRate
    let additionalItemCost: ShippingRate
    let countries: [String]
}


// MARK: - New Data Models

/// Represents a design file for a variant, containing its URLs.
struct File: Codable {
    let id: Int
    let printAreaId: Int
    let url: String
    let thumbnailUrl: String
}

/// Expanded location schema returned by the provider‑detail endpoint
struct Location: Codable {
    let address1: String?
    let address2: String?
    let city: String?
    let region: String?
    let country: String?
    let zip: String?
}

/// Slim payload returned by the print‑provider detail endpoint.
/// We only care about the structured address that is missing from the global list.
struct ProviderDetail: Codable {
    let id: Int
    let address: Location?

    private enum CodingKeys: String, CodingKey {
        case id
        case address = "location"
    }
}



struct PrintProvider: Codable, Identifiable {
    let id: Int
    let title: String?
    let location: String?      // Country code (from global list)
    var address: Location?     // Full structured address (added later)

    private enum CodingKeys: String, CodingKey { case id, title, location }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        id    = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)

        // Optional "location" can be either a country string or an object — or absent.
        let locationString   = try? container.decodeIfPresent(String.self, forKey: .location)
        let locationObject   = try? container.decodeIfPresent(Location.self, forKey: .location)

        address  = locationObject
        location = locationString ?? locationObject?.country
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        if let address = address {
            try container.encode(address, forKey: .location)
        } else {
            try container.encodeIfPresent(location, forKey: .location)
        }
    }
}



// MARK: - Original Data Models

struct Blueprint: Codable, Identifiable {
    let id: Int
    let title: String?
    let description: String?
    let brand: String?
    let model: String?
    let images: [String]?
}

/// Option matrix for a product (e.g. colour, size)
struct ProductOptionValue: Codable {
    let id: Int?
    let title: String?
    let colors: [String]?
}

struct ProductOption: Codable {
    let id: Int?
    let name: String?
    let type: String?
    let values: [ProductOptionValue]?
}

/// Raw print‑area geometry returned by the product‑detail endpoint
struct PrintArea: Codable {
    let position: String?
    let width: Int?
    let height: Int?
}

/// Extended product detail including all reliable and optional fields.
struct ProductDetail: Codable, Identifiable {
    let id: Int
    let title: String?
    let description: String?
    let brand: String?
    let model: String?
    let images: [String]?
    
    // Newly captured data
    let tags: [String]?
    let options: [ProductOption]?
    let printAreas: [PrintArea]?
    let createdAt: String?
    let updatedAt: String?
    let visible: Bool?
    
    // Convenience
    let primaryImage: String?    // URL for the primary image
    let availability: String?    // Stock status
}

/// Geometry of a printable placeholder on the product
struct Placeholder: Codable {
    let position: String?
    let width: Int?
    let height: Int?
}

/// Extended variant model including pricing, image, and option info.
struct Variant: Codable, Identifiable {
    let id: Int
    let title: String?
    let price: Double?           // Base price for the variant
    let currency: String?
    
    // Newly captured metadata
    let sku: String?
    let grams: Int?
    let optionIds: [Int]?        // Links back to ProductOption values
    let isAvailable: Bool?
    
    // Existing fields
    let files: [File]?
    let imageURL: String?
    let options: [String: String]?
    let placeholders: [Placeholder]?
    let isEnabled: Bool?
    let inStock: Bool?
    let isDefault: Bool?
    let weight: Double?
    let length: Double?
    let width: Double?
    let height: Double?
}

/// Combined data for a product (its detail and all associated data)
struct CombinedProductData: Identifiable, Hashable {
    let id: Int
    let productDetail: ProductDetail
    let variants: [Variant]
    var printProviders: [PrintProvider]? = nil
    // Maps each print provider's ID to its variant images & availability details.
    var variantImagesAvailability: [Int: [Variant]]? = nil
    // Maps each print provider's ID to its shipping info.
    var shippingInfoPerProvider: [Int: [ShippingOption]]? = nil
    
    let productDetailJSON: String
    let printProvidersJSON: String
    let variantsPerProviderJSON: String
    let shippingPerProviderJSON: String
    
    static func == (lhs: CombinedProductData, rhs: CombinedProductData) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - API Configuration

let apiKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIzN2Q0YmQzMDM1ZmUxMWU5YTgwM2FiN2VlYjNjY2M5NyIsImp0aSI6ImJjZmRlMjg2MDUwNGY3ZGU1MzZkYTdhODQ0OTVmYWRjYjA2YjU0ODkzYjExZTBlNTZjZGY0NjBlYTkwZTE0ZmZkNGY2YmYwMGQwZGJhNzQ0IiwiaWF0IjoxNzM4ODc0MzM0LjIwNTY2NSwibmJmIjoxNzM4ODc0MzM0LjIwNTY2OCwiZXhwIjoxNzcwNDEwMzM0LjE4OTM5Mywic3ViIjoiMTA3NjIxMzUiLCJzY29wZXMiOlsic2hvcHMubWFuYWdlIiwic2hvcHMucmVhZCIsImNhdGFsb2cucmVhZCIsIm9yZGVycy5yZWFkIiwib3JkZXJzLndyaXRlIiwicHJvZHVjdHMucmVhZCIsInByb2R1Y3RzLndyaXRlIiwid2ViaG9va3MucmVhZCIsIndlYmhvb2tzLndyaXRlIiwidXBsb2Fkcy5yZWFkIiwidXBsb2Fkcy53cml0ZSIsInByaW50X3Byb3ZpZGVycy5yZWFkIiwidXNlci5pbmZvIl19.AQCs2xphqhXj9eNZTYvjHEkZYjEASlWuMHdjqRtb31Xk40TqyO5OyBSzeW7SNPq0-ly0OUKh7FmtGInQ4lA"
let baseURL = "https://api.printify.com/v1"

func commonHeaders() -> [String: String] {
    return [
        "Authorization": "Bearer \(apiKey)",
        "Content-Type": "application/json",
        "Accept-Encoding": "identity",
        "Accept": "application/json",
        "X-PF-API-VERSION": "v1"
    ]
}

// MARK: - API Calls

/// 1. Catalog Pull: Blueprint IDs
func fetchCatalog() async throws -> [Blueprint] {
    guard let url = URL(string: "\(baseURL)/catalog/blueprints.json") else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    commonHeaders().forEach { key, value in request.addValue(value, forHTTPHeaderField: key) }
    let (data, _) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode([Blueprint].self, from: data)
}

/// 2. Product Details
func fetchProductDetail(for blueprintID: Int) async throws -> ProductDetail {
    guard let url = URL(string: "\(baseURL)/catalog/blueprints/\(blueprintID).json") else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    commonHeaders().forEach { key, value in request.addValue(value, forHTTPHeaderField: key) }
    let (data, _) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(ProductDetail.self, from: data)
}


/// 4. Print Providers
func fetchPrintProviders(for blueprintID: Int) async throws -> [PrintProvider] {
    guard let url = URL(string: "\(baseURL)/catalog/blueprints/\(blueprintID)/print_providers.json") else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    commonHeaders().forEach { key, value in request.addValue(value, forHTTPHeaderField: key) }
    let (data, _) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode([PrintProvider].self, from: data)
}


/// Fetches the “slim” provider‑detail payload (id + location).
/// The endpoint no longer returns ratings or prices in production,
/// so we decode only the fields we need.
func fetchPrintProviderDetail(for printProviderID: Int) async throws -> ProviderDetail {
    guard let url = URL(string: "\(baseURL)/catalog/print_providers/\(printProviderID).json") else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    commonHeaders().forEach { key, value in request.addValue(value, forHTTPHeaderField: key) }
    let (data, _) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(ProviderDetail.self, from: data)
}

/// Global Pull: All Print Providers (rich metadata)
func fetchAllPrintProviders() async throws -> [PrintProvider] {
    guard let url = URL(string: "\(baseURL)/catalog/print_providers.json") else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    commonHeaders().forEach { key, value in request.addValue(value, forHTTPHeaderField: key) }
    let (data, _) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let providers = try decoder.decode([PrintProvider].self, from: data)
    return providers
}

/// 6. Provider-Level Variant Data
func fetchVariantImagesAvailability(for blueprintID: Int, printProviderID: Int) async throws -> [Variant] {
    // Provider-level variants endpoint
    guard let url = URL(string: "\(baseURL)/catalog/blueprints/\(blueprintID)/print_providers/\(printProviderID)/variants.json") else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    commonHeaders().forEach { key, value in request.addValue(value, forHTTPHeaderField: key) }
    let (data, response) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
        if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
            throw NSError(domain: "PrintifyAPI", code: apiError.code, userInfo: [NSLocalizedDescriptionKey: apiError.message])
        }
        throw URLError(.badServerResponse)
    }
    // Decode the provider-specific variants list
    let wrapper = try decoder.decode(VariantListResponse.self, from: data)
    return wrapper.variants
}

/// 7. Shipping Info (Per Provider)
func fetchShippingInfo(for blueprintID: Int, printProviderID: Int) async throws -> [ShippingOption] {
    guard let url = URL(string: "\(baseURL)/catalog/blueprints/\(blueprintID)/print_providers/\(printProviderID)/shipping.json") else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    commonHeaders().forEach { key, value in request.addValue(value, forHTTPHeaderField: key) }
    let (data, response) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
        if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
            throw NSError(domain: "PrintifyAPI", code: apiError.code, userInfo: [NSLocalizedDescriptionKey: apiError.message])
        } else {
            throw URLError(.badServerResponse)
        }
    }
    let wrapper = try decoder.decode(BlueprintShippingResponse.self, from: data)
    // Flatten profiles into individual options per variant
    var options: [ShippingOption] = []
    for profile in wrapper.profiles {
        for variantId in profile.variantIds {
            options.append(
                ShippingOption(
                    variantId: variantId,
                    handlingTime: wrapper.handlingTime,
                    firstItemCost: profile.firstItem,
                    additionalItemCost: profile.additionalItems,
                    countries: profile.countries
                )
            )
        }
    }
    return options
}

// MARK: - View Model

class CatalogLoader: ObservableObject {
    @Published var catalog: [Blueprint] = []
    @Published var combinedProducts: [CombinedProductData] = []
    
    // Status indicators
    @Published var catalogStatus: String = "pending"  // "pending", "success", "fail"
    @Published var aggregatedCount: Int = 0
    @Published var totalProducts: Int = 0
    
    // Stopwatch for elapsed time
    @Published var runTime: TimeInterval = 0.0
    private var stopwatchTimer: Timer?
    
    @Published var loading: Bool = false
    
    // Failure buffer to record API call errors.
    // Each tuple contains (blueprintID, endpoint name, error)
    @Published var failureBuffer: [(blueprintID: Int, endpoint: String, error: Error)] = []
    
    // MARK: - Helpers
    
    /// Record a failure in the buffer.
    private func recordFailure(blueprintID: Int, endpoint: String, error: Error) {
        DispatchQueue.main.async {
            self.failureBuffer.append((blueprintID: blueprintID, endpoint: endpoint, error: error))
        }
    }

    /// Helper: Fetches variant data for all print providers of a blueprint.
    private func fetchAllVariants(for blueprintID: Int) async throws -> [Int: [Variant]] {
        var result: [Int: [Variant]] = [:]
        let providers = try await fetchPrintProviders(for: blueprintID)
        for provider in providers {
            do {
                let variants = try await fetchVariantImagesAvailability(for: blueprintID, printProviderID: provider.id)
                result[provider.id] = variants
            } catch {
                result[provider.id] = []
            }
        }
        return result
    }

    /// Helper: Fetches shipping info for all print providers of a blueprint.
    private func fetchAllShipping(for blueprintID: Int) async throws -> [Int: [ShippingOption]] {
        var result: [Int: [ShippingOption]] = [:]
        let providers = try await fetchPrintProviders(for: blueprintID)
        for provider in providers {
            do {
                let shipping = try await fetchShippingInfo(for: blueprintID, printProviderID: provider.id)
                result[provider.id] = shipping
            } catch {
                result[provider.id] = []
            }
        }
        return result
    }

    /// Starts the stopwatch timer.
    private func startStopwatch() {
        runTime = 0.0
        stopwatchTimer?.invalidate()
        stopwatchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.runTime += 1.0
            }
        }
    }

    /// Stops the stopwatch timer.
    private func stopStopwatch() {
        stopwatchTimer?.invalidate()
        stopwatchTimer = nil
    }

    /// Load product data using the full workflow for one product at a time.
    /// Sequentially processes blueprints and fetches all associated data.
    func loadProductData() async {
        do {
            DispatchQueue.main.async {
                self.loading = true
                self.catalogStatus = "pending"
                self.aggregatedCount = 0
                self.totalProducts = 0
                self.failureBuffer = []
                self.startStopwatch()
            }

            // 1. Central Pull: Catalog (Blueprint IDs) - Called once.
            let blueprints = try await fetchCatalog()
            DispatchQueue.main.async {
                self.catalog = blueprints
                self.catalogStatus = "success"
                self.totalProducts = blueprints.count
            }

            // 1b. Global Pull: All Print Providers (rich metadata)
            do {
                let globalProviders = try await fetchAllPrintProviders()
                var providersWithAddress: [PrintProvider] = []
                for var provider in globalProviders {
                    if let detail = try? await fetchPrintProviderDetail(for: provider.id) {
                        provider.address = detail.address
                    }
                    providersWithAddress.append(provider)
                }
                print("⚙️ Global providers + address:", providersWithAddress)
            } catch {
                print("⚙️ Error fetching global print providers:", error)
            }

            // Sequential processing: one blueprint at a time
            for blueprint in blueprints {
                // Clear failure buffer for this blueprint
                DispatchQueue.main.async {
                    self.failureBuffer = []
                }

                // Parallelize the four top-level API calls for this blueprint
                async let detailCall    = fetchProductDetail(for: blueprint.id)
                async let providersCall = fetchPrintProviders(for: blueprint.id)
                async let variantsCall  = fetchAllVariants(for: blueprint.id)
                async let shippingCall  = fetchAllShipping(for: blueprint.id)

                // Await each call with original error handling
                var productDetail: ProductDetail
                do {
                    productDetail = try await detailCall
                } catch {
                    self.recordFailure(blueprintID: blueprint.id, endpoint: "fetchProductDetail", error: error)
                    print("Error fetching detail for blueprint ID \(blueprint.id): \(error)")
                    productDetail = ProductDetail(
                        id: blueprint.id,
                        title: "Partial Product",
                        description: "Data missing",
                        brand: nil,
                        model: nil,
                        images: nil,
                        tags: nil,
                        options: nil,
                        printAreas: nil,
                        createdAt: nil,
                        updatedAt: nil,
                        visible: nil,
                        primaryImage: nil,
                        availability: nil
                    )
                }

                var printProviders: [PrintProvider] = []
                do {
                    printProviders = try await providersCall
                } catch {
                    self.recordFailure(blueprintID: blueprint.id, endpoint: "fetchPrintProviders", error: error)
                    print("Error fetching print providers for blueprint ID \(blueprint.id): \(error)")
                    printProviders = []
                }

                let providerVariantData: [Int: [Variant]]
                do {
                    providerVariantData = try await variantsCall
                } catch {
                    providerVariantData = [:]
                }

                let aggregatedVariants = providerVariantData.values.flatMap { $0 }

                let providerShippingData: [Int: [ShippingOption]]
                do {
                    providerShippingData = try await shippingCall
                } catch {
                    providerShippingData = [:]
                }

                // Raw JSON payloads for front-end debugging
                let productDetailJSON = String(data: try JSONEncoder().encode(productDetail), encoding: .utf8) ?? "—"
                let printProvidersJSON = String(data: try JSONEncoder().encode(printProviders), encoding: .utf8) ?? "—"
                let variantsPerProviderJSON = String(data: try JSONEncoder().encode(providerVariantData), encoding: .utf8) ?? "—"
                // Build raw JSON string for shipping per provider
                var rawShippingResponses: [String] = []
                for provider in printProviders {
                    // Fetch raw JSON directly
                    let shipURL = URL(string: "\(baseURL)/catalog/blueprints/\(blueprint.id)/print_providers/\(provider.id)/shipping.json")!
                    var shipRequest = URLRequest(url: shipURL)
                    commonHeaders().forEach { key, value in shipRequest.addValue(value, forHTTPHeaderField: key) }
                    let (shipData, _) = try await URLSession.shared.data(for: shipRequest)
                    let jsonStr = String(decoding: shipData, as: UTF8.self)
                    rawShippingResponses.append("\"\(provider.id)\":\(jsonStr)")
                }
                let shippingPerProviderJSON = "{\(rawShippingResponses.joined(separator: ","))}"

                // Aggregate all data into CombinedProductData.
                let combined = CombinedProductData(
                    id: blueprint.id,
                    productDetail: productDetail,
                    variants: aggregatedVariants,
                    printProviders: printProviders,
                    variantImagesAvailability: providerVariantData,
                    shippingInfoPerProvider: providerShippingData,
                    productDetailJSON: productDetailJSON,
                    printProvidersJSON: printProvidersJSON,
                    variantsPerProviderJSON: variantsPerProviderJSON,
                    shippingPerProviderJSON: shippingPerProviderJSON
                )

                // Append result
                DispatchQueue.main.async {
                    self.combinedProducts.append(combined)
                    self.aggregatedCount = self.combinedProducts.count
                }
            }

            DispatchQueue.main.async {
                self.loading = false
                self.stopStopwatch()
            }
        } catch {
            print("Error loading catalog: \(error)")
            DispatchQueue.main.async {
                self.loading = false
                self.stopStopwatch()
            }
        }
    }
}
