//
//  ZestyBanner.swift
//  AdsSDKSwift
//
//  Created by Daniel Adams on 11/25/24.
//

import Foundation

let DB_ENDPOINT = "https://api.zesty.market/api"
let BEACON_ENDPOINT = "https://beacon2.zesty.market/zgraphql"

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
    
    public func sendOnLoadMetric(adUnitId: String) async throws {
        guard var url = URL(string: BEACON_ENDPOINT) else {
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
    }
}

public struct AdResponse: Codable, Sendable {
    let ads: [Ad]
    let campaignId: String
    
    enum CodingKeys: String, CodingKey {
        case ads = "Ads"
        case campaignId = "CampaignId"
    }
    
    // Nested Ad struct to represent individual ad details
    public struct Ad: Codable, Sendable {
        let assetURL: String
        let ctaURL: String
        
        enum CodingKeys: String, CodingKey {
            case assetURL = "asset_url"
            case ctaURL = "cta_url"
        }
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
