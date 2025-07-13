import SwiftUI

struct ContentView: View {
    @StateObject var loader = CatalogLoader()
    
    // For navigation in a NavigationStack
    @State private var navigationPath: [CombinedProductData] = []
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 10) {
                
                // Top Status & Control Section
                CatalogStatusView(loader: loader)
                
                Divider()
                
                // Main List of Products
                ProductListView(loader: loader, navigationPath: $navigationPath)
            }
            .navigationTitle("Import")
            .toolbar {
                // A toolbar button to start loading data
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Start Catalog Pull") {
                        Task {
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
        }
    }
}

// MARK: - Catalog Status View

struct CatalogStatusView: View {
    @ObservedObject var loader: CatalogLoader
    
    var body: some View {
        VStack(spacing: 10) {
            // Catalog pull status
            HStack {
                Text("Catalog: \(loader.catalogStatus)")
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
            
            Text("Print Areas: \(product.productDetail.printAreas ?? "N/A")")
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
        let providerLocation = provider.location ?? "N/A"
        
        return VStack(alignment: .leading, spacing: 4) {
            Text("Provider: \(providerTitle)")
            Text("Location: \(providerLocation)")
            
            // Provider-level variants
            if let providerVariants = product.variantImagesAvailability?[provider.id] {
                Text("Provider-Level Variants:")
                    .font(.subheadline)
                
                ForEach(providerVariants) { variant in
                    SingleVariantView(variant: variant)
                }
            }
            
            // Shipping info
            if let shipping = product.shippingInfoPerProvider?[provider.id] {
                Text("Shipping Info:")
                    .font(.subheadline)
                
                let shippingTitle = shipping.title ?? "N/A"
                let shippingHandling = shipping.handlingTime ?? "N/A"
                let shippingRates = shipping.shippingRates?.description ?? "N/A"
                let shippingRegions = shipping.availableRegions?.joined(separator: ", ") ?? "N/A"
                
                Text("Title: \(shippingTitle)")
                Text("Handling Time: \(shippingHandling)")
                Text("Shipping Rates: \(shippingRates)")
                Text("Available Regions: \(shippingRegions)")
            }
            
            Divider()
        }
    }
}
