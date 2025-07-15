import SwiftUI

struct SimulatedView: View {
    let combinedData: CombinedProductData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Parsed:")
                .font(.subheadline)
                .bold()
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: 16) {
                   ForEach(combinedData.variants, id: \.id) { variant in
                      VariantCardView(productDetail: combinedData.productDetail, variant: variant)
                    }
                }
                .padding()
            }
        }
    }
}

struct VariantCardView: View {
    let productDetail: ProductDetail
    let variant: Variant
    @State private var showOverlay = false

    var body: some View {
        ZStack {
            VStack {
                Text(variant.title ?? "Untitled Variant")
                    .font(.headline)
                if let urlString = productDetail.images?.first,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                             .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 120, height: 120)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
            .shadow(radius: 2)
            .onTapGesture {
                showOverlay.toggle()
            }

            if showOverlay {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Display images
                        let blueprintURLs = productDetail.images?.compactMap { URL(string: $0) } ?? []
                        let variantURLs = variant.imageURL.flatMap { URL(string: $0) }.map { [$0] } ?? []
                        let allURLs = blueprintURLs + variantURLs
                        ForEach(allURLs, id: \.self) { url in
                            AsyncImage(url: url) { image in
                                image.resizable()
                                     .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        Divider()
                        // Display variant data
                        Group {
                            Text("Variant Details")
                                .font(.headline)
                            HStack { Text("ID"); Spacer(); Text("\(variant.id)") }
                            HStack { Text("Title"); Spacer(); Text(variant.title ?? "N/A") }
                            HStack { Text("Price"); Spacer(); Text(variant.price != nil ? "\(variant.price!)" : "N/A") }
                            HStack { Text("Currency"); Spacer(); Text(variant.currency ?? "N/A") }
                            HStack { Text("Image URL"); Spacer(); Text(variant.imageURL ?? "N/A") }
                        }
                        Divider()
                        // Display product detail data
                        Group {
                            Text("Product Details")
                                .font(.headline)
                            HStack { Text("ID"); Spacer(); Text("\(productDetail.id)") }
                            HStack { Text("Title"); Spacer(); Text(productDetail.title ?? "Untitled") }
                            HStack { Text("Description"); Spacer(); Text(productDetail.description ?? "N/A") }
                            HStack { Text("Brand"); Spacer(); Text(productDetail.brand ?? "N/A") }
                            HStack { Text("Model"); Spacer(); Text(productDetail.model ?? "N/A") }
                            HStack { Text("Primary Image"); Spacer(); Text(productDetail.primaryImage ?? "N/A") }
                            HStack { Text("Print Areas"); Spacer(); Text(productDetail.printAreas ?? "N/A") }
                            HStack { Text("Availability"); Spacer(); Text(productDetail.availability ?? "N/A") }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                }
                .padding()
            }
        }
    }
}
