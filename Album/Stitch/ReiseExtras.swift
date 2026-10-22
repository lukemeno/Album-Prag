import Foundation

/// Dieselbe Reise hat drei Zustände: planen, unterwegs sein und erinnern. Quelle ist `TripCalendar.phase`.
enum TripPhase: Equatable {
    case before
    case during
    case after
}
