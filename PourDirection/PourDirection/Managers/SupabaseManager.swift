//
//  SupabaseManager.swift
//  PourDirection
//
//  Singleton wrapper around the Supabase Swift client.
//  Responsibilities:
//    - Initialize the SupabaseClient once using Config constants
//    - Expose a generic invokeFunction() for calling Edge Functions
//    - Provide a testConnection() stub for verifying client setup
//
//  Usage:
//    let result: MyResponse = try await SupabaseManager.shared.invokeFunction(
//        name: "my-function",
//        body: MyRequest(foo: "bar")
//    )
//

import Foundation
import Supabase

// MARK: - SupabaseManager

final class SupabaseManager {

    // MARK: Singleton

    static let shared = SupabaseManager()

    // MARK: Client

    let client: SupabaseClient

    private init() {
        guard let url = URL(string: Config.supabaseURL) else {
            fatalError("SupabaseManager: invalid supabaseURL in Config.swift — check your project URL.")
        }
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Config.supabaseAnonKey
        )
    }

    // MARK: - Edge Function Invocation

    /// Calls a Supabase Edge Function by name, encoding `body` as JSON and decoding the
    /// response into `T`. Throws on network failure, non-2xx status, or decode errors.
    ///
    /// - Parameters:
    ///   - name: The deployed Edge Function name (e.g. `"suggest-places"`).
    ///   - body: An `Encodable` payload sent as the JSON request body.
    /// - Returns: A `Decodable` value of type `T` decoded from the function response.
    func invokeFunction<T: Decodable>(
        name: String,
        body: some Encodable
    ) async throws -> T {
        let data: Data = try await client.functions.invoke(
            name,
            options: FunctionInvokeOptions(body: body)
        )
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SupabaseManagerError.decodingFailed(
                function: name,
                underlying: error,
                rawResponse: String(data: data, encoding: .utf8)
            )
        }
    }

    // MARK: - Connection Test

    /// Temporary test stub — calls a "health-check" Edge Function that does not yet exist.
    /// Expected output:  a FunctionsError (404 / not found) confirming the client is wired
    /// up correctly and can reach Supabase. Remove or replace once real functions are deployed.
    func testConnection() async {
        struct HealthPayload: Encodable { let ping = "test" }
        struct HealthResponse: Decodable { let status: String }

        do {
            let response: HealthResponse = try await invokeFunction(
                name: "health-check",
                body: HealthPayload()
            )
            print("[SupabaseManager] ✅ health-check OK — status: \(response.status)")
        } catch {
            print("[SupabaseManager] ⚠️  health-check error (expected — function not deployed yet): \(error)")
        }
    }
}

// MARK: - Errors

enum SupabaseManagerError: LocalizedError {
    case decodingFailed(function: String, underlying: Error, rawResponse: String?)

    var errorDescription: String? {
        switch self {
        case let .decodingFailed(function, underlying, raw):
            let preview = raw.map { "Raw response: \($0)" } ?? "No response body"
            return "SupabaseManager: failed to decode response from '\(function)'. \(underlying.localizedDescription). \(preview)"
        }
    }
}
