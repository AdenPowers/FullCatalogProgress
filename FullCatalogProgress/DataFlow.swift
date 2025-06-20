import Foundation

// MARK: - New Data Models

struct PrintProvider: Codable, Identifiable {
    let id: Int
    let title: String?
    let location: String?         // Country-level location only
    let averageProductionTime: Int?
    let rating: Double?
    let basePrices: [String: Double]?  // Mapping of variant IDs to base prices
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
        "Content-Type": "application/json"
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

/// 3. Blueprint-Level Variants
func fetchVariants(for blueprintID: Int) async throws -> [Variant] {
    guard let url = URL(string: "\(baseURL)/catalog/blueprints/\(blueprintID)/variants.json") else {
        throw URLError(.badURL)
    }
    var request = URLRequest(url: url)
    commonHeaders().forEach { key, value in request.addValue(value, forHTTPHeaderField: key) }
    let (data, _) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    return try decoder.decode([Variant].self, from: data)
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
    let (data, _) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    return try decoder.decode([Variant].self, from: data)
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
    /// Implements batch-level logic:
    /// - Each batch waits for all products to finish.
    /// - If any API calls fail (i.e. errors, not just empty responses), record them.
    /// - If a batch has failures, allow one extra sequential batch and then stop loading.
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
            
            let totalProducts = blueprints.count
            let batchSize = 9 // maintain max 9 requests per second
            let totalBatches = Int(ceil(Double(totalProducts) / Double(batchSize)))
            
            // Variables to control extra batch logic.
            var extraBatchAllowed = false
            var extraBatchProcessed = false
            
            // Process each blueprint (one product) in batches.
            batchLoop: for batchIndex in 0..<totalBatches {
                // If an extra batch was already processed due to failures, then stop further loading.
                if extraBatchAllowed && extraBatchProcessed {
                    print("Extra batch processed with failures. Halting further loading.")
                    break batchLoop
                }
                
                let startIndex = batchIndex * batchSize
                let endIndex = min(startIndex + batchSize, totalProducts)
                let batch = blueprints[startIndex..<endIndex]
                
                // Clear failure buffer for this batch.
                self.failureBuffer = []
                
                await withTaskGroup(of: CombinedProductData?.self) { group in
                    for blueprint in batch {
                        group.addTask {
                            var productDetail: ProductDetail
                            var blueprintVariants: [Variant] = []
                            var printProviders: [PrintProvider] = []
                            var providerVariantData: [Int: [Variant]] = [:]
                            var providerShippingData: [Int: ShippingInfo] = [:]
                            
                            // (a) Fetch Product Details
                            do {
                                productDetail = try await fetchProductDetail(for: blueprint.id)
                                try await Task.sleep(nanoseconds: 111_000_000)
                            } catch {
                                self.recordFailure(blueprintID: blueprint.id, endpoint: "fetchProductDetail", error: error)
                                print("Error fetching detail for blueprint ID \(blueprint.id): \(error)")
                                productDetail = ProductDetail(id: blueprint.id, title: "Partial Product", description: "Data missing", primaryImage: nil, printAreas: nil, availability: nil)
                            }
                            
                            // (b) Fetch Blueprint-Level Variants
                            do {
                                blueprintVariants = try await fetchVariants(for: blueprint.id)
                                try await Task.sleep(nanoseconds: 111_000_000)
                            } catch {
                                self.recordFailure(blueprintID: blueprint.id, endpoint: "fetchVariants", error: error)
                                print("Error fetching blueprint-level variants for blueprint ID \(blueprint.id): \(error)")
                                blueprintVariants = []
                            }
                            
                            // (c) Fetch Print Providers for this blueprint.
                            do {
                                printProviders = try await fetchPrintProviders(for: blueprint.id)
                                try await Task.sleep(nanoseconds: 111_000_000)
                            } catch {
                                self.recordFailure(blueprintID: blueprint.id, endpoint: "fetchPrintProviders", error: error)
                                print("Error fetching print providers for blueprint ID \(blueprint.id): \(error)")
                                printProviders = []
                            }
                            
                            // (d) For each Print Provider (looped per product)
                            for (index, provider) in printProviders.enumerated() {
                                // i. Fetch detailed print provider info.
                                do {
                                    let detailedProvider = try await fetchPrintProviderDetail(for: provider.id)
                                    printProviders[index] = detailedProvider
                                    try await Task.sleep(nanoseconds: 111_000_000)
                                } catch {
                                    self.recordFailure(blueprintID: blueprint.id, endpoint: "fetchPrintProviderDetail for provider \(provider.id)", error: error)
                                    print("Error fetching provider detail for provider ID \(provider.id): \(error)")
                                }
                                
                                // ii. Fetch provider-level variant data.
                                do {
                                    let providerVariants = try await fetchVariantImagesAvailability(for: blueprint.id, printProviderID: provider.id)
                                    providerVariantData[provider.id] = providerVariants
                                    try await Task.sleep(nanoseconds: 111_000_000)
                                } catch {
                                    self.recordFailure(blueprintID: blueprint.id, endpoint: "fetchVariantImagesAvailability for provider \(provider.id)", error: error)
                                    print("Error fetching provider variants for blueprint ID \(blueprint.id), provider ID \(provider.id): \(error)")
                                    providerVariantData[provider.id] = []
                                }
                                
                                // iii. Fetch shipping info for this provider.
                                do {
                                    let shipping = try await fetchShippingInfo(for: blueprint.id, printProviderID: provider.id)
                                    providerShippingData[provider.id] = shipping
                                    try await Task.sleep(nanoseconds: 111_000_000)
                                } catch {
                                    self.recordFailure(blueprintID: blueprint.id, endpoint: "fetchShippingInfo for provider \(provider.id)", error: error)
                                    print("Error fetching shipping info for blueprint ID \(blueprint.id), provider ID \(provider.id): \(error)")
                                    providerShippingData[provider.id] = nil
                                }
                            }
                            
                            // Aggregate all data into CombinedProductData.
                            let combined = CombinedProductData(
                                id: blueprint.id,
                                productDetail: productDetail,
                                variants: blueprintVariants,
                                printProviders: printProviders,
                                variantImagesAvailability: providerVariantData,
                                shippingInfoPerProvider: providerShippingData
                            )
                            
                            return combined
                        }
                    }
                    
                    // Collect the aggregated products.
                    for await combinedData in group {
                        if let combined = combinedData {
                            DispatchQueue.main.async {
                                self.combinedProducts.append(combined)
                                self.aggregatedCount = self.combinedProducts.count
                            }
                        }
                    }
                } // End TaskGroup
                
                // Check failure buffer for this batch.
                if !self.failureBuffer.isEmpty {
                    print("Batch \(batchIndex + 1) had errors: \(self.failureBuffer)")
                    // If this is the first time errors are detected, allow one extra batch.
                    if !extraBatchAllowed {
                        extraBatchAllowed = true
                    } else {
                        // Already processed an extra batch, so break out.
                        extraBatchProcessed = true
                    }
                }
            } // End batch loop
            
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
