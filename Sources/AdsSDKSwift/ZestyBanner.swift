//
//  ZestyBanner.swift
//  AdsSDKSwift
//
//  Created by Daniel Adams on 11/25/24.
//

import Foundation
import SwiftUI
import WebKit

let DB_ENDPOINT = "https://api.zesty.market/api"
let BEACON_ENDPOINT = "https://beacon2.zesty.market/zgraphql"
let CDN_BASE = "https://cdn.zesty.xyz/sdk/assets/"
let RELAY_URL = "https://relay.zesty.xyz"

public enum Formats {
    case MediumRectangle
    case Billboard
    case MobilePhoneInterstitial
}

// Network client with async/await
public struct ZestyNetworkClient : Sendable {
    public static let shared = ZestyNetworkClient()
    
    private init() {}
    
    public func fetchCampaignAd(adUnitId: String) async throws -> AdResponse {
        guard var urlComponents = URLComponents(string: DB_ENDPOINT + "/ad") else {
            throw NetworkError.invalidURL
        }
        
        // Add adUnitId as a query parameter
        urlComponents.queryItems = [
            URLQueryItem(name: "ad_unit_id", value: adUnitId),
        ]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(AdResponse.self, from: data)
    }
    
    public func getDefaultResponse(format: Formats) -> AdResponse {
        switch format {
        case Formats.MediumRectangle:
            return AdResponse(ads: [Ad(assetURL: CDN_BASE + "zesty-default-medium-rectangle.png", ctaURL: RELAY_URL)], campaignId: "None")
        case Formats.Billboard:
            return AdResponse(ads: [Ad(assetURL: CDN_BASE + "zesty-default-billboard.png", ctaURL: RELAY_URL)], campaignId: "None")
        case Formats.MobilePhoneInterstitial:
            return AdResponse(ads: [Ad(assetURL: CDN_BASE + "zesty-default-mobile-phone-interstitial.png", ctaURL: RELAY_URL)], campaignId: "None")
        }
    }
    
    public func sendOnLoadMetric(adUnitId: String, campaignId: String) async throws {
        guard var url = URL(string: BEACON_ENDPOINT) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(BeaconMetric(query: """
            mutation { increment(eventType: visits, spaceId: "\(adUnitId)", campaignId: "\(campaignId)", platform: { name: visionOS, confidence: Full }) { message } }` }
        """))
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
    }
    
    public func sendOnClickMetric(adUnitId: String, campaignId: String) async throws {
        guard var url = URL(string: BEACON_ENDPOINT) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(BeaconMetric(query: """
            mutation { increment(eventType: clicks, spaceId: "\(adUnitId)", campaignId: "\(campaignId)", platform: { name: visionOS, confidence: Full }) { message } }` }
        """))
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
    }
}

public struct Ad: Codable, Sendable {
    let assetURL: String
    let ctaURL: String
    
    enum CodingKeys: String, CodingKey {
        case assetURL = "asset_url"
        case ctaURL = "cta_url"
    }
}

public struct AdResponse: Codable, Sendable {
    let ads: [Ad]
    let campaignId: String
    
    enum CodingKeys: String, CodingKey {
        case ads = "Ads"
        case campaignId = "CampaignId"
    }
    
    // Convenience method to get the first ad's asset URL or return nil
    public func getFirstAdAssetURL() -> String? {
        return ads.first?.assetURL
    }
    
    // Convenience method to get the first ad's CTA URL or return nil
    public func getFirstAdCtaURL() -> String? {
        return ads.first?.ctaURL
    }
}

// Custom network errors
public enum NetworkError: Error {
    case invalidURL
    case invalidResponse
}

public struct BeaconMetric: Codable, Sendable {
    let query: String
}

public struct WebView: UIViewRepresentable {
    let url: URL

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Assign stored coordinator reference as delegate
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView // Keep a reference to the WebView

        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        webView.load(request)
    }

    public class Coordinator: NSObject, WKNavigationDelegate, ObservableObject {
        weak var webView: WKWebView? // Keep reference to WebView
        
        
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                print("No URL, allowing")
                decisionHandler(.allow)
                return
            }
            
            switch navigationAction.navigationType {
            case .linkActivated:
                // Explicit click on an anchor tag or similar, open in Safari
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            case .other:
                // Get our main document URL to filter out iframe navigations
                guard let mainDoc = navigationAction.request.mainDocumentURL else {
                    decisionHandler(.allow)
                    return
                }
                // Anything being embedded on the prebid page should load in the webview
                if mainDoc.absoluteString.contains("zesty") {
                    decisionHandler(.allow)
                } else {
                    // This is most likely a navigation from interacting with the ad, open in Safari
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                }
            default:
                decisionHandler(.allow)
            }
        }
    }
}


struct WebViewContentView: View {
    var format: Formats
    var width: CGFloat
    var height: CGFloat
    var size: String
    var adUnitId: String
    
    init(format: Formats, adUnitId: String) {
        self.format = format
        self.adUnitId = adUnitId
        
        switch format {
        case Formats.MediumRectangle:
            self.width = 300
            self.height = 250
            self.size = "medium-retangle"
        case Formats.Billboard:
            self.width = 970
            self.height = 250
            self.size = "billboard"
        case Formats.MobilePhoneInterstitial:
            self.width = 640
            self.height = 1136
            self.size = "mobile-phone-interstitial"
        }
    }
    
    var body: some View {
        VStack {
            VStack {
                WebView(url: URL(string: "https://www.zesty.xyz/prebid/?size=\(self.size)&ad_unit_id=\(self.adUnitId)")!)
            }
            .frame(width: self.width, height: self.height)
            .aspectRatio(contentMode: .fit)
        }
    }
}
