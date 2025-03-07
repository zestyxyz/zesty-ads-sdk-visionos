//
//  ZestyBannerView.swift
//  AdsSDKSwift
//
//  Created by Daniel Adams on 11/22/24.
//

import SwiftUI
import Kingfisher
import WebKit

public struct ZestyBannerView: View {
    let adUnitId: String
    let format: Formats
    private let defaultImageURL = "https://cdn.zesty.xyz/images/zesty/zesty-default-medium-rectangle.png"
    private let defaultCtaURL = "https://relay.zesty.xyz"
    
    @State private var imageURL: String = ""
    @State private var ctaURL: String = ""
    @State private var isLoading = false
    @State private var error: Error?
    @State private var campaignId: String = "None"
    
    public init(adUnitId: String, format: Formats) {
        self.adUnitId = adUnitId
        self.format = format
        self._imageURL = State(initialValue: defaultImageURL)
        self._ctaURL = State(initialValue: defaultCtaURL)
    }
    
    public var body: some View {
        VStack {
            if !self.isLoading && self.campaignId != "None" {
                Link(destination: URL(string: ctaURL)!) {
                    KFImage.url(URL(string: imageURL))
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            isLoading ? ProgressView() : nil
                        )
                }
                .simultaneousGesture(TapGesture().onEnded {
                    Task {
                        try? await ZestyNetworkClient.shared.sendOnClickMetric(
                            adUnitId: self.adUnitId,
                            campaignId: self.campaignId
                        )
                    }
                })
                .task {
                    await loadAd()
                }
            } else {
                WebViewContentView(format: self.format, adUnitId: self.adUnitId)
            }
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
                self.campaignId = response.campaignId
            }

            try await ZestyNetworkClient.shared.sendOnLoadMetric(adUnitId: self.adUnitId, campaignId: self.campaignId)
        } catch {
            // Fall back to default image and CTA
            let defaultRes = ZestyNetworkClient.shared.getDefaultResponse(format: self.format)
            await MainActor.run {
                self.imageURL = defaultRes.getFirstAdAssetURL() ?? defaultImageURL
                self.ctaURL = defaultRes.getFirstAdCtaURL() ?? defaultCtaURL
                self.error = error
                self.isLoading = false
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ZestyBannerView(adUnitId: "c001c7bb-e9f8-4245-8607-e20c99ff0d08", format: Formats.Billboard)
}
