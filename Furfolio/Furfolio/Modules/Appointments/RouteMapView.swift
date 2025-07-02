//
//  RouteMapView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI
import MapKit

// MARK: - RoutePoint Model

struct RoutePoint: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let isHomeBase: Bool
    let isCurrent: Bool
}

// MARK: - RouteMapView

struct RouteMapView: View {
    var routePoints: [RoutePoint]
    var routePolyline: [CLLocationCoordinate2D]?
    var currentLocation: CLLocationCoordinate2D?
    var onSelectPoint: ((RoutePoint) -> Void)?

    @State private var region: MKCoordinateRegion
    @State private var selectedPoint: RoutePoint?

    // Initializer to auto-fit all points on map
    init(routePoints: [RoutePoint],
         routePolyline: [CLLocationCoordinate2D]? = nil,
         currentLocation: CLLocationCoordinate2D? = nil,
         onSelectPoint: ((RoutePoint) -> Void)? = nil) {
        self.routePoints = routePoints
        self.routePolyline = routePolyline
        self.currentLocation = currentLocation
        self.onSelectPoint = onSelectPoint

        if let first = routePoints.first {
            _region = State(initialValue: MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090), // Apple Park as fallback
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            ))
        }
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: routePoints) { point in
            MapAnnotation(coordinate: point.coordinate) {
                VStack(spacing: 2) {
                    Image(systemName: point.isHomeBase ? "house.fill" : (point.isCurrent ? "location.fill" : "mappin.circle.fill"))
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(point.isHomeBase ? .blue : (point.isCurrent ? .green : .accentColor))
                        .background(
                            Circle().fill(selectedPoint?.id == point.id ? Color.yellow.opacity(0.6) : Color.clear)
                        )
                        .onTapGesture {
                            selectedPoint = point
                            onSelectPoint?(point)
                        }
                        .accessibilityLabel("\(point.name) at \(point.address)")
                    Text(point.name)
                        .font(.caption2)
                        .padding(2)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                }
            }
        }
        .overlay(
            Group {
                if let routePolyline {
                    RoutePolylineShape(coordinates: routePolyline)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, dash: [8, 8]))
                        .opacity(0.55)
                }
            }
        )
        .edgesIgnoringSafeArea(.all)
        .overlay(
            VStack(alignment: .leading, spacing: 8) {
                if let selected = selectedPoint {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.name).font(.headline)
                        Text(selected.address).font(.caption)
                        Button("Dismiss") { selectedPoint = nil }
                            .font(.caption)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground).opacity(0.9)))
                    .shadow(radius: 2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                Spacer()
            }
            .padding()
            , alignment: .bottomLeading
        )
    }
}

// MARK: - Route Polyline Shape

struct RoutePolylineShape: Shape {
    var coordinates: [CLLocationCoordinate2D]

    func path(in rect: CGRect) -> Path {
        guard coordinates.count > 1 else { return Path() }
        var path = Path()
        let points = coordinates.map { CLLocationCoordinate2D in
            CGPoint(
                x: CGFloat(CLLocationCoordinate2D.longitude),
                y: CGFloat(CLLocationCoordinate2D.latitude)
            )
        }
        // This is a placeholder – you may want to project the coordinates to map points.
        // For demo, it simply connects lat/lon as if they were points in the rect.
        if let first = points.first {
            path.move(to: first)
            for pt in points.dropFirst() {
                path.addLine(to: pt)
            }
        }
        return path
    }
}

// MARK: - Preview

#if DEBUG
import CoreLocation

struct RouteMapView_Previews: PreviewProvider {
    static var previews: some View {
        let base = RoutePoint(name: "Home Base", address: "123 Main St", coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090), isHomeBase: true, isCurrent: false)
        let stop1 = RoutePoint(name: "Bella", address: "456 Oak Ave", coordinate: CLLocationCoordinate2D(latitude: 37.3317, longitude: -122.0307), isHomeBase: false, isCurrent: false)
        let stop2 = RoutePoint(name: "Max", address: "789 Maple Dr", coordinate: CLLocationCoordinate2D(latitude: 37.3397, longitude: -122.0412), isHomeBase: false, isCurrent: true)

        let route = [base, stop1, stop2]
        let poly = route.map { $0.coordinate }
        RouteMapView(routePoints: route, routePolyline: poly)
            .frame(height: 360)
            .previewLayout(.sizeThatFits)
    }
}
#endif
