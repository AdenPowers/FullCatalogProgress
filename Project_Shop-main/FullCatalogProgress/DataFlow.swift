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

// MARK: - New Data Models

struct PrintProvider: Codable, Identifiable {
    let id: Int
    let title: String?
    let location: String?         // Country-level location only
    let averageProductionTime: Int?
    let rating: Double?
    let basePrices: [String: Double]?  // Mapping of variant IDs to base prices

    // Custom decoding to accept either a string or an object for "location"
    private enum CodingKeys: String, CodingKey {
        case id, title, location, averageProductionTime, rating, basePrices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        averageProductionTime = try container.decodeIfPresent(Int.self, forKey: .averageProductionTime)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        basePrices = try container.decodeIfPresent([String: Double].self, forKey: .basePrices)
        // Attempt to decode location as a string first; if that fails, decode as dict
        if let locStr = try? container.decodeIfPresent(String.self, forKey: .location) {
            location = locStr
        } else if let locDict = try? container.decodeIfPresent([String: String].self, forKey: .location) {
            location = locDict["country"]
        } else {
            location = nil
        }
    }
}

struct ShippingInfo: Codable {
    let shippingProfileID: Int?
    let title: String?
    let handlingTime: String?
    let shippingRates: [String: Double]?
    let availableRegions: [String]?
}

// MARK: - Original Data Models

struct Blueprint: Codable, Identifiable {
    let id: Int
    // Additional properties can be added as needed.
}

/// Extended product detail including key fields.
struct ProductDetail: Codable, Identifiable {
    let id: Int
    let title: String?
    let description: String?
    let primaryImage: String?    // URL string for the primary image
    let printAreas: String?      // String representing print area info
    let availability: String?    // Stock status
}

/// Extended variant model including pricing, image, and option info.
struct Variant: Codable, Identifiable {
    let id: Int
    let title: String?
    let price: Double?           // Base price for the variant
    let imageURL: String?        // URL for variant image (if available)
    // You can add properties like "size" and "color" if returned by the API.
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
    var shippingInfoPerProvider: [Int: ShippingInfo]? = nil
    
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
    return try decoder.decode([PrintProvider].self, from: data)
}

/// 5. Print Provider Details
func fetchPrintProviderDetail(for printProviderID: Int) async throws -> PrintProvider {
    guard let url = URL(string: "\(baseURL)/catalog/print_providers/\(printProviderID).json") else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    commonHeaders().forEach { key, value in request.addValue(value, forHTTPHeaderField: key) }
    let (data, _) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    return try decoder.decode(PrintProvider.self, from: data)
}

/// 6. Provider-Level Variant Data
func fetchVariantImagesAvailability(for blueprintID: Int, printProviderID: Int) async throws -> [Variant] {
    guard let url = URL(string: "\(baseURL)/catalog/blueprints/\(blueprintID)/print_providers/\(printProviderID)/variants.json") else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    commonHeaders().forEach { key, value in request.addValue(value, forHTTPHeaderField: key) }
    let (data, response) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    // Handle non-2xx HTTP status codes by decoding the error envelope.
    if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
        if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
            throw NSError(domain: "PrintifyAPI", code: apiError.code, userInfo: [NSLocalizedDescriptionKey: apiError.message])
        } else {
            throw URLError(.badServerResponse)
        }
    }
    // Try to decode a paginated envelope.
    if let paginated = try? decoder.decode(PaginatedResponse<Variant>.self, from: data) {
        return paginated.data
    }
    // Try to decode a raw array of variants.
    if let rawList = try? decoder.decode([Variant].self, from: data) {
        return rawList
    }
    // Finally, try decoding an error envelope in case of unexpected format.
    if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
        throw NSError(domain: "PrintifyAPI", code: apiError.code, userInfo: [NSLocalizedDescriptionKey: apiError.message])
    }
    throw URLError(.cannotParseResponse)
}

/// 7. Shipping Info (Per Provider)
func fetchShippingInfo(for blueprintID: Int, printProviderID: Int) async throws -> ShippingInfo {
    guard let url = URL(string: "\(baseURL)/catalog/blueprints/\(blueprintID)/print_providers/\(printProviderID)/shipping.json") else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    commonHeaders().forEach { key, value in request.addValue(value, forHTTPHeaderField: key) }
    let (data, _) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    return try decoder.decode(ShippingInfo.self, from: data)
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
                try await Task.sleep(nanoseconds: 111_000_000)
            } catch {
                result[provider.id] = []
            }
        }
        return result
    }

    /// Helper: Fetches shipping info for all print providers of a blueprint.
    private func fetchAllShipping(for blueprintID: Int) async throws -> [Int: ShippingInfo] {
        var result: [Int: ShippingInfo] = [:]
        // Retrieve providers for this blueprint
        let providers = try await fetchPrintProviders(for: blueprintID)
        // Fetch shipping info for each provider
        for provider in providers {
            do {
                let shipping = try await fetchShippingInfo(for: blueprintID, printProviderID: provider.id)
                result[provider.id] = shipping
                try await Task.sleep(nanoseconds: 111_000_000)
            } catch {
                // On failure, record empty/default shipping
                result[provider.id] = ShippingInfo(shippingProfileID: nil, title: nil, handlingTime: nil, shippingRates: nil, availableRegions: nil)
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

            // Sequential processing: one blueprint at a time
            for blueprint in blueprints {
                // Clear failure buffer for this blueprint
                DispatchQueue.main.async {
                    self.failureBuffer = []
                }

                // (a) Fetch Product Details
                var productDetail: ProductDetail
                do {
                    productDetail = try await fetchProductDetail(for: blueprint.id)
                    try await Task.sleep(nanoseconds: 111_000_000)
                } catch {
                    self.recordFailure(blueprintID: blueprint.id, endpoint: "fetchProductDetail", error: error)
                    print("Error fetching detail for blueprint ID \(blueprint.id): \(error)")
                    productDetail = ProductDetail(id: blueprint.id, title: "Partial Product", description: "Data missing", primaryImage: nil, printAreas: nil, availability: nil)
                }

                // (c) Fetch Print Providers for this blueprint.
                var printProviders: [PrintProvider] = []
                do {
                    printProviders = try await fetchPrintProviders(for: blueprint.id)
                    try await Task.sleep(nanoseconds: 111_000_000)
                } catch {
                    self.recordFailure(blueprintID: blueprint.id, endpoint: "fetchPrintProviders", error: error)
                    print("Error fetching print providers for blueprint ID \(blueprint.id): \(error)")
                }

                // Fetch variants for all providers of this blueprint
                let providerVariantData = try await fetchAllVariants(for: blueprint.id)
                // Fetch shipping info for all providers of this blueprint
                let providerShippingData = try await fetchAllShipping(for: blueprint.id)

                // Aggregate all data into CombinedProductData.
                let combined = CombinedProductData(
                    id: blueprint.id,
                    productDetail: productDetail,
                    variants: [],
                    printProviders: printProviders,
                    variantImagesAvailability: providerVariantData,
                    shippingInfoPerProvider: providerShippingData
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
