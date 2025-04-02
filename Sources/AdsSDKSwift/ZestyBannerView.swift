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
    var width: CGFloat?
    var height: CGFloat?
    private var baseHeight: CGFloat
    private var baseWidth: CGFloat
    private let defaultImageURL = "https://cdn.zesty.xyz/images/zesty/zesty-default-medium-rectangle.png"
    private let defaultCtaURL = "https://relay.zesty.xyz"
    private var uuidValid: Bool = false
    
    @State private var imageURL: String = ""
    @State private var ctaURL: String = ""
    @State private var isLoading = false
    @State private var error: Error?
    @State private var campaignId: String = "None"
    
    public init(adUnitId: String, format: Formats, width: CGFloat? = nil, height: CGFloat? = nil) {
        // Initialization 
        self.adUnitId = adUnitId
        self.format = format
        switch format {
        case .MediumRectangle:
            baseWidth = 300
            baseHeight = 250
        case .Billboard:
            baseWidth = 970
            baseHeight = 250
        case .MobilePhoneInterstitial:
            baseWidth = 640
            baseHeight = 1136
        }
        self.width = width
        self.height = height
        self._imageURL = State(initialValue: defaultImageURL)
        self._ctaURL = State(initialValue: defaultCtaURL)
        self.uuidValid = UUID(uuidString: adUnitId) != nil
        
        // Validation
        if !self.uuidValid {
            print("[Warning] Ad Unit ID is not a valid UUID. Ad campaigns will not run until this is fixed.")
        }
        if width != nil && width! <= 0 {
            self.width = nil
            print("[Warning] Width must be a positive number! Value will be treated as nil.")
        }
        if height != nil && height! <= 0 {
            self.height = nil
            print("[Warning] Height must be a positive number! Value will be treated as nil.")
        }
    }
    
    public var body: some View {
        let scale = calculateScale()
        VStack {
            if !self.uuidValid || (!self.isLoading && self.campaignId != "None") {
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
        .scaleEffect(scale)
        .frame(width: scale.width * baseWidth, height: scale.height * baseHeight)
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
    
    private func calculateScale() -> CGSize {
        let baseAspectRatio = baseWidth / baseHeight
        
        if width == nil && height == nil {
            return CGSize(width: 1, height: 1)
        } else if width == nil {
            let calculatedWidth = height! * baseAspectRatio
            return CGSize(width: calculatedWidth / baseWidth, height: height! / baseHeight)
        } else if height == nil {
            let calculatedHeight = width! / baseAspectRatio
            return CGSize(width: width! / baseWidth, height: calculatedHeight / baseHeight)
        } else {
            // If both are given, use the larger value and calculate the other value from the aspect ratio
            if width! / baseWidth > height! / baseHeight {
                // Width is the limiting factor
                return CGSize(width: width! / baseWidth, height: (width! / baseAspectRatio) / baseHeight)
            } else {
                // Height is the limiting factor
                return CGSize(width: (height! * baseAspectRatio) / baseWidth, height: height! / baseHeight)
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ZestyBannerView(adUnitId: "c001c7bb-e9f8-4245-8607-e20c99ff0d08", format: Formats.Billboard)
}
