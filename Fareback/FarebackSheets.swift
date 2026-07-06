import SwiftUI

enum FarebackSheet: Identifiable {
    case addRoute
    case editRoute(CommuteRoute)
    case paywall

    var id: String {
        switch self {
        case .addRoute: return "addRoute"
        case .editRoute(let r): return "edit-\(r.id)"
        case .paywall: return "paywall"
        }
    }
}

struct RouteFormView: View {
    @EnvironmentObject private var store: FarebackStore
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    let existing: CommuteRoute?

    @State private var name: String
    @State private var mode: CommuteMode
    @State private var milesText: String
    @State private var fareText: String
    @State private var daysPerWeek: Int

    init(existing: CommuteRoute?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _mode = State(initialValue: existing?.mode ?? .drive)
        _milesText = State(initialValue: existing.map { String($0.roundTripMiles) } ?? "20")
        _fareText = State(initialValue: existing.map { String($0.transitFare) } ?? "5")
        _daysPerWeek = State(initialValue: existing?.daysPerWeek ?? 5)
    }

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Route") {
                    TextField("Name (e.g. Office)", text: $name)
                        .accessibilityIdentifier("routeNameField")

                    Picker("Mode", selection: $mode) {
                        ForEach(CommuteMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .accessibilityIdentifier("routeModePicker")

                    if mode == .drive {
                        TextField("Round-trip miles", text: $milesText)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("routeMilesField")
                    } else if mode == .transit {
                        TextField("Round-trip fare ($)", text: $fareText)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("routeFareField")
                    }

                    HStack {
                        Text("Days per week: \(daysPerWeek)")
                        Spacer()
                        Button {
                            if daysPerWeek > 1 { daysPerWeek -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("routeDaysDecrementButton")

                        Button {
                            if daysPerWeek < 7 { daysPerWeek += 1 }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("routeDaysIncrementButton")
                    }
                }

                if isEditing {
                    Section {
                        Button("Delete Route", role: .destructive) {
                            if let existing {
                                store.deleteRoute(existing.id)
                            }
                            dismiss()
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("deleteRouteButton")
                    }
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle(isEditing ? "Edit Route" : "New Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.plain)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        let miles = Double(milesText) ?? 0
                        let fare = Double(fareText) ?? 0
                        if isEditing, let existing {
                            store.updateRoute(existing.id, name: name, mode: mode, roundTripMiles: miles, transitFare: fare, daysPerWeek: daysPerWeek)
                        } else {
                            store.addRoute(name: name, mode: mode, roundTripMiles: miles, transitFare: fare, daysPerWeek: daysPerWeek, isPro: purchases.isPro)
                        }
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("saveRouteButton")
                }
            }
        }
    }
}
