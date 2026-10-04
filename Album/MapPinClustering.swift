import CoreGraphics
import Foundation

struct MapPinProjection: Identifiable, Equatable {
    let id: String
    let point: CGPoint
}

struct MapPinCluster: Identifiable, Equatable {
    let memberIDs: [String]
    let center: CGPoint

    var id: String { memberIDs.joined(separator: "|") }
}

enum MapPinClustering {
    /// Groups connected annotation frames in screen space, so the result follows the current zoom and orientation.
    static func clusters(from points: [MapPinProjection], collisionDistance: CGFloat) -> [MapPinCluster] {
        let sorted = points.sorted { $0.id < $1.id }
        guard collisionDistance > 0 else {
            return sorted.map { MapPinCluster(memberIDs: [$0.id], center: $0.point) }
        }

        var remaining = Set(sorted.map(\.id))
        var result: [MapPinCluster] = []

        for seed in sorted where remaining.remove(seed.id) != nil {
            var component = [seed]
            var frontier = [seed]

            while let current = frontier.popLast() {
                for candidate in sorted where remaining.contains(candidate.id) && distance(current.point, candidate.point) <= collisionDistance {
                    remaining.remove(candidate.id)
                    component.append(candidate)
                    frontier.append(candidate)
                }
            }

            let count = CGFloat(component.count)
            let center = CGPoint(
                x: component.reduce(0) { $0 + $1.point.x } / count,
                y: component.reduce(0) { $0 + $1.point.y } / count
            )
            result.append(MapPinCluster(memberIDs: component.map(\.id).sorted(), center: center))
        }

        return result.sorted { $0.id < $1.id }
    }

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
