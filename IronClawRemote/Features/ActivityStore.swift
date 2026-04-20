import Foundation
import Observation

@MainActor
@Observable
final class ActivityStore {
    var jobs: [JobSummary] = []
    var routines: [RoutineSummary] = []
    var missions: [MissionSummary] = []
    var isLoading = false
    var lastErrorMessage: String?

    @MainActor
    func load(using client: GatewayClient) async {
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }
        do {
            async let jobsRequest = client.jobs()
            async let routinesRequest = client.routines()
            async let missionsRequest = client.missions()

            jobs = try await jobsRequest
            routines = try await routinesRequest

            do {
                missions = try await missionsRequest
            } catch {
                missions = []
                lastErrorMessage = error.localizedDescription
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
