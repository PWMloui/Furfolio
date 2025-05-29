//
//  RouteOptimizerView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import MapKit
import os

/// A view that displays optimized driving route for today's appointments.
struct RouteOptimizerView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "RouteOptimizerView")
    @StateObject private var viewModel = RouteOptimizerViewModel()

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Calculating Route…")
                        .font(AppTheme.body)
                        .onAppear {
                            logger.log("ProgressView shown: Calculating Route")
                        }
                } else if let route = viewModel.route {
                    MapView(route: route, annotations: viewModel.annotations)
                        .edgesIgnoringSafeArea(.all)
                } else if let error = viewModel.error {
                    VStack {
                        Text("Failed to calculate route")
                            .font(AppTheme.title)
                            .foregroundColor(AppTheme.warning)
                        Text(error.localizedDescription)
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            logger.log("Retry tapped")
                            viewModel.loadRoute()
                        }
                        .buttonStyle(FurfolioButtonStyle())
                        .padding(.top)
                    }
                    .padding()
                } else {
                    Text("No appointments to optimize.")
                        .font(AppTheme.body)
                        .foregroundColor(AppTheme.secondaryText)
                        .onAppear {
                            logger.log("No appointments to optimize shown")
                        }
                }
            }
            .navigationTitle("Route Optimizer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        logger.log("Refresh tapped")
                        viewModel.loadRoute()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(FurfolioButtonStyle())
                }
            }
            .onAppear {
                viewModel.loadRoute()
            }
        }
        .onAppear {
            logger.log("RouteOptimizerView appeared; isLoading=\(viewModel.isLoading)")
        }
    }
}

struct MapView: UIViewRepresentable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "MapView")
    let route: MKRoute
    let annotations: [MKPointAnnotation]

    func makeUIView(context: Context) -> MKMapView {
        logger.log("MapView.makeUIView: adding \(annotations.count) annotations, drawing route polyline")
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

    func updateUIView(_ uiView: MKMapView, context: Context) {
        logger.log("MapView.updateUIView called")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let poly = overlay as? MKPolyline {
                Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "MapView").log("Rendering overlay polyline with strokeColor .systemBlue and lineWidth 4")
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
