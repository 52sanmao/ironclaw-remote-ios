import Foundation
import SwiftUI

@Observable
final class ActivityViewModel {
    var jobs: [JobSummary] = []
    var routines: [RoutineSummary] = []
    var missions: [MissionSummary] = []
    var errorMessage: String?
    var missionsErrorMessage: String?
    var isLoading = false

    func load(using configuration: GatewayConfiguration) async {
        isLoading = true
        errorMessage = nil
        missionsErrorMessage = nil
        defer { isLoading = false }

        if configuration.isDemoMode {
            jobs = DemoContent.jobs
            routines = DemoContent.routines
            missions = DemoContent.missions
            return
        }

        do {
            let client = GatewayClient(configuration: configuration)
            async let jobsRequest = client.jobs()
            async let routinesRequest = client.routines()
            async let missionsRequest = client.missions()

            jobs = try await jobsRequest
            routines = try await routinesRequest

            do {
                missions = try await missionsRequest
            } catch {
                missions = []
                missionsErrorMessage = error.localizedDescription
            }
        } catch {
            jobs = []
            routines = []
            missions = []
            errorMessage = error.localizedDescription
        }
    }
}
