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
            async let jobs = client.jobs()
            async let routines = client.routines()
            async let missions = client.missions()
            self.jobs = try await jobs
            self.routines = try await routines
            self.missions = try await missions
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
