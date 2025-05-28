
//
//  RouteOptimizerView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import MapKit

/// A view that displays optimized driving route for today's appointments.
struct RouteOptimizerView: View {
    @StateObject private var viewModel = RouteOptimizerViewModel()

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Calculating Route…")
                } else if let route = viewModel.route {
                    MapView(route: route, annotations: viewModel.annotations)
                        .edgesIgnoringSafeArea(.all)
                } else if let error = viewModel.error {
                    VStack {
                        Text("Failed to calculate route")
                            .font(.headline)
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            viewModel.loadRoute()
                        }
                        .padding(.top)
                    }
                    .padding()
                } else {
                    Text("No appointments to optimize.")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Route Optimizer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.loadRoute) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                viewModel.loadRoute()
            }
        }
    }
}

struct MapView: UIViewRepresentable {
    let route: MKRoute
    let annotations: [MKPointAnnotation]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        annotations.forEach { map.addAnnotation($0) }
        map.addOverlay(route.polyline)
        map.setVisibleMapRect(
            route.polyline.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
            animated: false
        )
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let poly = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: poly)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

final class RouteOptimizerViewModel: ObservableObject {
    @Published var route: MKRoute?
    @Published var annotations: [MKPointAnnotation] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let locationManager = CLLocationManager()

    /// Loads today's appointments, geocodes addresses, and requests optimized route.
    func loadRoute() {
        isLoading = true
        error = nil

        Task {
            do {
                // 1. Fetch appointments with addresses
                let addresses = try await AppointmentService.shared.addressesForToday()
                // 2. Geocode each address
                let locations = try await withThrowingTaskGroup(of: CLLocationCoordinate2D.self) { group -> [CLLocationCoordinate2D] in
                    for address in addresses {
                        group.addTask {
                            try await CLGeocoder().geocodeAddressString(address)
                                .first?
                                .location?
                                .coordinate
                                ?? { throw NSError(domain: "GeocodeError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No location for \(address)"]) }()
                        }
                    }
                    var results: [CLLocationCoordinate2D] = []
                    for try await coord in group {
                        results.append(coord)
                    }
                    return results
                }
                // 3. Create annotations
                let pins = locations.map { coord -> MKPointAnnotation in
                    let pin = MKPointAnnotation()
                    pin.coordinate = coord
                    return pin
                }
                await MainActor.run {
                    self.annotations = pins
                }
                // 4. Request directions
                let request = MKDirections.Request()
                request.transportType = .automobile
                request.requestsAlternateRoutes = false
                if let first = locations.first {
                    request.source = MKMapItem(placemark: MKPlacemark(coordinate: first))
                    if let last = locations.last {
                        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: last))
                    }
                }
                if locations.count > 2 {
                    request.waypoints = locations.dropFirst().dropLast().map { MKMapItem(placemark: MKPlacemark(coordinate: $0)) }
                }
                let directions = MKDirections(request: request)
                let response = try await directions.calculate()
                guard let best = response.routes.first else {
                    throw NSError(domain: "RouteError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No routes found"])
                }
                await MainActor.run {
                    self.route = best
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}
