//
//  ZestyBannerView.swift
//  visionos-test
//
//  Created by Daniel Adams on 11/22/24.
//

import SwiftUI
import Kingfisher

public struct ZestyBannerView: View {
    let adUnitId: String
    private let defaultImageURL = "https://cdn.zesty.xyz/images/zesty/zesty-default-medium-rectangle.png"
    private let defaultCtaURL = "https://www.zesty.xyz"
    
    @State private var imageURL: String = ""
    @State private var ctaURL: String = ""
    @State private var isLoading = false
    @State private var error: Error?
    
    // Initialize with just adUnitId
    public init(adUnitId: String) {
        self.adUnitId = adUnitId
        self._imageURL = State(initialValue: defaultImageURL)
        self._ctaURL = State(initialValue: defaultCtaURL)
    }
    
    public var body: some View {
        Link(destination: URL(string: ctaURL)!) {
            KFImage(URL(string: imageURL))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay(
                    isLoading ? ProgressView() : nil
                )
        }
        .task {
            await loadAd()
        }
    }
    
    private func loadAd() async {
        // Reset state
        isLoading = true
        error = nil
        
        do {
            // Use the async network client with the specific adUnitId
            let response = try await ZestyNetworkClient.shared.fetchCampaignAd(adUnitId: adUnitId)
            
            // Update UI on main thread
            await MainActor.run {
                // Use convenience methods to get first ad details
                self.imageURL = response.getFirstAdAssetURL() ?? defaultImageURL
                self.ctaURL = response.getFirstAdCtaURL() ?? defaultCtaURL
                self.isLoading = false
            }
        } catch {
            // Fall back to default image and CTA
            await MainActor.run {
                self.imageURL = defaultImageURL
                self.ctaURL = defaultCtaURL
                self.error = error
                self.isLoading = false
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ZestyBannerView(adUnitId: "c001c7bb-e9f8-4245-8607-e20c99ff0d08")
}
