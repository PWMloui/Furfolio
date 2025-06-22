//
//  UserFeedback.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import Foundation
import UIKit

/// A model representing user-submitted feedback for the Furfolio app.
struct UserFeedback: Identifiable, Equatable, Hashable {
    /// Unique identifier for this feedback instance.
    let id: UUID

    /// Timestamp of when the feedback was created.
    let date: Date

    /// Rating from 1 to 5 indicating user sentiment.
    let rating: Int

    /// Optional user comment or suggestion.
    let comment: String?

    /// Optional screenshot or photo attached to the feedback.
    let screenshot: UIImage?

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        rating: Int,
        comment: String? = nil,
        screenshot: UIImage? = nil
    ) {
        self.id = id
        self.date = date
        self.rating = rating
        self.comment = comment
        self.screenshot = screenshot
    }

    // MARK: - Sample Data for Preview & Testing

    static let sample: UserFeedback = UserFeedback(
        rating: 4,
        comment: "Great app! I'd love to see dark mode support.",
        screenshot: nil
    )
}
