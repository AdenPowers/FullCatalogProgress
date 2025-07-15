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

/// Wrapper for blueprint variants response
private struct BlueprintVariantsResponse: Codable {
    let id: Int
    let title: String
    let variants: [Variant]
}

/// Wrapper for shipping response from Printify
private struct BlueprintShippingResponse: Codable {
    let handling_time: ShippingHandlingTime
    let profiles: [ShippingProfile]
}

struct ShippingHandlingTime: Codable {
    let value: Int
    let unit: String
}

private struct ShippingProfile: Codable {
    let variant_ids: [Int]
    let first_item: ShippingRate
    let additional_items: ShippingRate
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
    let brand: String?
    let model: String?
    let images: [String]?
    let primaryImage: String?    // URL string for the primary image
    let printAreas: String?      // String representing print area info
    let availability: String?    // Stock status
}

/// Extended variant model including pricing, image, and option info.
struct Variant: Codable, Identifiable {
    let id: Int
    let title: String?
    let price: Double?           // Base price for the variant
    let currency: String?
    let files: [File]?
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

/// 5. Print Provider Details
func fetchPrintProviderDetail(for printProviderID: Int) async throws -> PrintProvider {
    guard let url = URL(string: "\(baseURL)/catalog/print_providers/\(printProviderID).json") else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    commonHeaders().forEach { key, value in request.addValue(value, forHTTPHeaderField: key) }
    let (data, _) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
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
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
        if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
            throw NSError(domain: "PrintifyAPI", code: apiError.code, userInfo: [NSLocalizedDescriptionKey: apiError.message])
        } else {
            throw URLError(.badServerResponse)
        }
    }
    let wrapper = try decoder.decode(BlueprintVariantsResponse.self, from: data)
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
        for variantId in profile.variant_ids {
            options.append(
                ShippingOption(
                    variantId: variantId,
                    handlingTime: wrapper.handling_time,
                    firstItemCost: profile.first_item,
                    additionalItemCost: profile.additional_items,
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
                        primaryImage: nil,
                        printAreas: nil,
                        availability: nil
                    )
                }

                var printProviders: [PrintProvider]
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
                    variants: [],
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
