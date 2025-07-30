import SwiftUI

struct ContentView: View {
    @StateObject var loader = CatalogLoader()
    @StateObject var providerLoader = PrintProviderLoader()
    
    // For navigation in a NavigationStack
    @State private var navigationPath: [CombinedProductData] = []
    // Overlay toggle for provider list
    @State private var showProvidersOverlay: Bool = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 10) {
                
                // Top Status & Control Section
                CatalogStatusView(providerLoader: providerLoader, loader: loader)
                
                Divider()
                
                // Main List of Products
                ProductListView(loader: loader, navigationPath: $navigationPath)
            }
            .navigationTitle("Import")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Providers") {
                        showProvidersOverlay = true
                    }
                    .disabled(providerLoader.providers.isEmpty)
                }
                // A toolbar button to start loading data
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Start Catalog Pull") {
                        Task {
                            await providerLoader.loadProviders()
                            await loader.loadProductData()
                        }
                    }
                    .disabled(loader.loading)
                }
            }
            // The detail destination(s) for navigation
            .navigationDestination(for: CombinedProductData.self) { product in
                ProductDetailScreen(product: product)
            }
            // Overlay sheet to display global + detailed providers
            .sheet(isPresented: $showProvidersOverlay) {
                ProviderListOverlayView(providers: providerLoader.providers)
            }
        }
    }
}

// MARK: - Catalog Status View

struct CatalogStatusView: View {
    @ObservedObject var providerLoader: PrintProviderLoader
    @ObservedObject var loader: CatalogLoader
    
    var body: some View {
        VStack(spacing: 10) {
            // Catalog pull status
            HStack {
                Text("Catalog: \(loader.catalogStatus)")
            }
            
            // Print providers progress
            HStack {
                Text("Print Providers: \(providerLoader.loadedProviders)/\(providerLoader.totalProviders)")
                ProgressView(value: providerLoader.totalProviders == 0
                             ? 0.0
                             : Double(providerLoader.loadedProviders) / Double(providerLoader.totalProviders))
            }
            
            // Aggregated products progress
            HStack {
                Text("Aggregated Products: \(loader.aggregatedCount)/\(loader.totalProducts)")
                ProgressView(value: loader.totalProducts == 0
                             ? 0.0
                             : Double(loader.aggregatedCount) / Double(loader.totalProducts))
            }
            
            // Elapsed time
            HStack {
                let minutes = Int(loader.runTime) / 60
                let seconds = Int(loader.runTime) % 60
                Text("Elapsed time: \(minutes) m \(seconds) s")
            }
        }
        .padding(.top, 10)
    }
}

// MARK: - Product List View

struct ProductListView: View {
    @ObservedObject var loader: CatalogLoader
    @Binding var navigationPath: [CombinedProductData]
    
    var body: some View {
        List(loader.combinedProducts) { product in
            Button {
                // Navigate to detail view
                navigationPath.append(product)
            } label: {
                HStack {
                    Image(systemName: "photo")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .padding(.trailing, 10)
                    
                    VStack(alignment: .leading) {
                        Text(product.productDetail.title ?? "Untitled")
                            .font(.headline)
                        Text("ID: \(product.productDetail.id)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

// MARK: - Product Detail Screen

struct ProductDetailScreen: View {
    let product: CombinedProductData
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Product Detail JSON:")
                    .font(.subheadline).bold()
                ScrollView(.horizontal) {
                    Text(product.productDetailJSON)
                        .font(.caption)
                        .lineLimit(nil)
                }
                Divider()

                Text("Print Providers JSON:")
                    .font(.subheadline).bold()
                ScrollView(.horizontal) {
                    Text(product.printProvidersJSON)
                        .font(.caption)
                        .lineLimit(nil)
                }
                Divider()

                Text("Variants per Provider JSON:")
                    .font(.subheadline).bold()
                ScrollView(.horizontal) {
                    Text(product.variantsPerProviderJSON)
                        .font(.caption)
                        .lineLimit(nil)
                }
                Divider()

                Text("Shipping Info per Provider JSON:")
                    .font(.subheadline).bold()
                ScrollView(.horizontal) {
                    Text(product.shippingPerProviderJSON)
                        .font(.caption)
                        .lineLimit(nil)
                }
                Divider()
                // Provider‑labeled variants
                PrintProvidersSection(product: product)
                Divider()
            }
            .padding()
        }
        .navigationTitle("Product \(product.productDetail.id)")
    }
}

// MARK: - Subview: Basic Info

struct BasicInfoSection: View {
    let product: CombinedProductData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title: \(product.productDetail.title ?? "Untitled")")
                .font(.subheadline)
            
            Text("Primary Image: \(product.productDetail.primaryImage ?? "No Image")")
                .font(.subheadline)
            
            Text("Description: \(product.productDetail.description ?? "No Description")")
                .font(.subheadline)
            
            // Render print‑areas JSON or “N/A”
            let printAreasDisplay: String = {
                if let areas = product.productDetail.printAreas,
                   let data = try? JSONEncoder().encode(areas),
                   let json = String(data: data, encoding: .utf8) {
                    return json
                } else {
                    return "N/A"
                }
            }()

            Text("Print Areas: \(printAreasDisplay)")
                .font(.subheadline)
            
            Text("Availability: \(product.productDetail.availability ?? "N/A")")
                .font(.subheadline)
        }
    }
}

// MARK: - Subview: Blueprint Variants

struct BlueprintVariantsSection: View {
    let product: CombinedProductData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Blueprint-Level Variants (Basic):")
                .font(.headline)
            
            ForEach(product.variants) { variant in
                SingleVariantView(variant: variant)
            }
        }
    }
}

// MARK: - Subview: Single Variant

struct SingleVariantView: View {
    let variant: Variant
    
    var body: some View {
        // Convert optionals to local constants to avoid "ambiguous use of 'init'"
        let variantTitle = variant.title ?? "Unknown"
        let variantPrice = variant.price?.description ?? "N/A"
        let variantImage = variant.imageURL ?? "N/A"
        
        return VStack(alignment: .leading, spacing: 4) {
            Text("Variant: \(variantTitle)")
            Text("Price: \(variantPrice)")
            Text("Image URL: \(variantImage)")
            Divider()
        }
    }
}

// MARK: - Subview: Print Providers

struct PrintProvidersSection: View {
    let product: CombinedProductData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Print Providers & Detailed Variants:")
                .font(.headline)
            
            if let providers = product.printProviders {
                ForEach(providers) { provider in
                    ProviderDetailSection(
                        product: product,
                        provider: provider
                    )
                }
            }
        }
    }
}

// MARK: - Subview: Single Provider Detail

struct ProviderDetailSection: View {
    let product: CombinedProductData
    let provider: PrintProvider
    
    var body: some View {
        // Flatten optional strings to local constants
        let providerTitle = provider.title ?? "Unknown"
        
        return VStack(alignment: .leading, spacing: 4) {
            Text("Provider: \(providerTitle)")
            if let location = provider.location, !location.isEmpty {
                Text("Location: \(location)")
            }
            
            // Provider-level variants (raw JSON)
            if let providerVariants = product.variantImagesAvailability?[provider.id] {
                Text("Provider-Level Variants JSON:")
                    .font(.subheadline)
                
                ScrollView(.horizontal) {
                    if let jsonData = try? JSONEncoder().encode(providerVariants),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        Text(jsonString)
                            .font(.caption)
                            .lineLimit(nil)
                    } else {
                        Text("Unable to encode variants to JSON")
                            .font(.caption)
                    }
                }
            }
            
            // Shipping info
            if let providerVariants = product.variantImagesAvailability?[provider.id],
               let shippingOptions = product.shippingInfoPerProvider?[provider.id] {
                Text("Shipping Options by Variant:")
                    .font(.subheadline)

                // Group shipping array by variant ID
                let groupedByVariant = Dictionary(grouping: shippingOptions, by: \.variantId)

                ForEach(groupedByVariant.keys.sorted(), id: \.self) { vid in
                    Text("Variant ID: \(vid)")
                        .font(.caption).bold()

                    if let optionsForVariant = groupedByVariant[vid] {
                        ScrollView(.horizontal) {
                            if let jsonData = try? JSONEncoder().encode(optionsForVariant),
                               let jsonString = String(data: jsonData, encoding: .utf8) {
                                Text(jsonString)
                                    .font(.caption)
                                    .lineLimit(nil)
                            }
                        }
                    }
                }
            }
            
            Divider()
        }
    }
}

// MARK: - Provider Overlay View

import SwiftUI

struct ProviderListOverlayView: View {
    let providers: [PrintProvider]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(providers) { provider in
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.title ?? "Untitled")
                        .font(.headline)
                    if let location = provider.location, !location.isEmpty {
                        Text("Location: \(location)")
                            .font(.subheadline)
                    }
                    if let addr = provider.address {
                        VStack(alignment: .leading, spacing: 2) {
                            if let line1 = addr.address1 { Text(line1) }
                            if let city = addr.city, let region = addr.region {
                                Text("\(city), \(region)")
                            } else if let city = addr.city {
                                Text(city)
                            }
                            if let country = addr.country { Text(country) }
                            if let zip = addr.zip { Text(zip) }
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Print Providers (\(providers.count))")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - PrintProviderLoader

import Foundation

@MainActor
class PrintProviderLoader: ObservableObject {
    // Published progress counters
    @Published var loadedProviders: Int = 0
    @Published var totalProviders: Int = 0
    
    // Cached enriched providers (optional for later use)
    @Published var providers: [PrintProvider] = []
    
    // Simple loading flag to disable duplicate runs
    @Published var loading: Bool = false
    
    /// One‑shot task:
    /// 1) Fetch the global list of print providers (lightweight, ID + title).
    /// 2) Loop through the IDs once to fetch their detail payloads (address, offerings, etc.).
    /// 3) Update `loadedProviders / totalProviders` so the UI `ProgressView` reflects progress.
    func loadProviders() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        
        do {
            // Step 1: Global list (basic metadata)
            let baseProviders: [PrintProvider] = try await fetchAllPrintProviders()
            await MainActor.run {
                self.totalProviders = baseProviders.count
            }
            
            // Step 2: Enrich each provider with its detail payload
            var enriched: [PrintProvider] = []
            for var provider in baseProviders {
                if let detail = try? await fetchPrintProviderDetail(for: provider.id) {
                    provider.address = detail.address
                }
                
                enriched.append(provider)
                
                await MainActor.run {
                    self.loadedProviders += 1
                }
            }
            
            await MainActor.run {
                self.providers = enriched
            }
            
        } catch {
            print("⚙️ PrintProviderLoader error:", error)
        }
    }
}
