//
//  SiriIntentHandler.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced by ChatGPT on 6/23/25: modular, audit/analytics-ready, DI, localized, secure.
//

import Intents
import Foundation
import OSLog

// MARK: - Audit/Analytics Helpers

fileprivate func auditLog(_ event: String, _ context: [String: String]) {
    // TODO: Plug into Trust Center/business compliance or analytics
    #if DEBUG
    print("AUDIT [\(event)]: \(context)")
    #endif
}

fileprivate func analyticsTrack(_ event: String, _ context: [String: String]) {
    // TODO: Plug into Analytics/BI pipeline
    #if DEBUG
    print("ANALYTICS [\(event)]: \(context)")
    #endif
}

// MARK: - Siri Entry Point

final class SiriIntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        switch intent {
        case is AddAppointmentIntent:
            return AddAppointmentIntentHandler()
        case is AddQuickNoteIntent:
            return AddQuickNoteIntentHandler()
        case is OpenOwnerProfileIntent:
            return OpenOwnerProfileIntentHandler()
        default:
            return self
        }
    }
}

// MARK: - Add Appointment Intent Handler

final class AddAppointmentIntentHandler: NSObject, AddAppointmentIntentHandling {
    func handle(intent: AddAppointmentIntent, completion: @escaping (AddAppointmentIntentResponse) -> Void) {
        let dogName = intent.dogName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? NSLocalizedString("Dog", comment: "Default dog name fallback")
        let service = intent.serviceType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? NSLocalizedString("Full Groom", comment: "Default service type fallback")
        let date = intent.date ?? Date()

        // Try to get the service via DI container
        if let appointmentService = DependencyContainer.shared.appointmentService {
            // Use the real service
            appointmentService.createAppointment(dogName: dogName, serviceType: service, date: date) { result in
                switch result {
                case .success(let appointment):
                    auditLog("appointment_created", [
                        "dog": dogName, "service": service, "date": "\(date)", "id": appointment.id.uuidString
                    ])
                    analyticsTrack("appointment_created", [
                        "dog": dogName, "service": service
                    ])
                    let response = AddAppointmentIntentResponse.success(dogName: dogName, serviceType: service, date: date)
                    completion(response)
                case .failure(let error):
                    auditLog("appointment_create_failed", [
                        "dog": dogName, "service": service, "date": "\(date)", "reason": error.localizedDescription
                    ])
                    let failMsg = NSLocalizedString("Unable to create the appointment. Please try again.", comment: "Siri failure message for appointment")
                    let response = AddAppointmentIntentResponse.failure(error: failMsg)
                    completion(response)
                }
            }
        } else {
            // Service unavailable, fail gracefully
            auditLog("appointment_service_unavailable", [
                "dog": dogName, "service": service, "date": "\(date)"
            ])
            let failMsg = NSLocalizedString("Appointment service is currently unavailable. Please try again later.", comment: "Siri failure fallback for appointment")
            let response = AddAppointmentIntentResponse.failure(error: failMsg)
            completion(response)
        }
        // TODO: If this ever affects UI, apply AppColors/AppFonts tokens for all text/visual elements.
    }

    func resolveDogName(for intent: AddAppointmentIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let name = intent.dogName, !name.isEmpty {
            completion(.success(with: name))
        } else {
            completion(.needsValue())
        }
    }

    func resolveDate(for intent: AddAppointmentIntent, with completion: @escaping (INDateComponentsResolutionResult) -> Void) {
        if let date = intent.date {
            completion(.success(with: date))
        } else {
            completion(.needsValue())
        }
    }
}

// MARK: - Add Quick Note Intent Handler

final class AddQuickNoteIntentHandler: NSObject, AddQuickNoteIntentHandling {
    func handle(intent: AddQuickNoteIntent, completion: @escaping (AddQuickNoteIntentResponse) -> Void) {
        let content = intent.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? NSLocalizedString("Note", comment: "Default note content fallback")
        let owner = intent.ownerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? NSLocalizedString("Business", comment: "Default owner name fallback")

        // Try to get the note manager service via DI
        if let noteManager = DependencyContainer.shared.noteManager {
            noteManager.createQuickNote(content: content, ownerName: owner) { result in
                switch result {
                case .success(let note):
                    auditLog("quick_note_created", [
                        "owner": owner, "content": content, "id": note.id.uuidString
                    ])
                    analyticsTrack("quick_note_created", [
                        "owner": owner
                    ])
                    let response = AddQuickNoteIntentResponse.success(noteContent: content, ownerName: owner)
                    completion(response)
                case .failure(let error):
                    auditLog("quick_note_create_failed", [
                        "owner": owner, "content": content, "reason": error.localizedDescription
                    ])
                    let failMsg = NSLocalizedString("Unable to save your note. Please try again.", comment: "Siri failure message for note")
                    let response = AddQuickNoteIntentResponse.failure(error: failMsg)
                    completion(response)
                }
            }
        } else {
            // Service unavailable
            auditLog("note_manager_unavailable", [
                "owner": owner, "content": content
            ])
            let failMsg = NSLocalizedString("Note service is currently unavailable. Please try again later.", comment: "Siri failure fallback for note")
            let response = AddQuickNoteIntentResponse.failure(error: failMsg)
            completion(response)
        }
        // TODO: If response affects UI colors or text styling, apply AppColors/AppFonts tokens.
    }
}

// MARK: - Open Owner Profile Intent Handler

final class OpenOwnerProfileIntentHandler: NSObject, OpenOwnerProfileIntentHandling {
    func handle(intent: OpenOwnerProfileIntent, completion: @escaping (OpenOwnerProfileIntentResponse) -> Void) {
        let name = intent.ownerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? NSLocalizedString("Owner", comment: "Default owner name fallback")

        if let navigationService = DependencyContainer.shared.navigationService {
            navigationService.openOwnerProfile(ownerName: name) { success in
                if success {
                    auditLog("owner_profile_opened", ["owner": name])
                    analyticsTrack("owner_profile_opened", ["owner": name])
                    let response = OpenOwnerProfileIntentResponse.success(ownerName: name)
                    completion(response)
                } else {
                    auditLog("owner_profile_open_failed", ["owner": name])
                    let failMsg = NSLocalizedString("Unable to open profile. Please try again.", comment: "Siri failure message for profile open")
                    let response = OpenOwnerProfileIntentResponse.failure(error: failMsg)
                    completion(response)
                }
            }
        } else {
            auditLog("navigation_service_unavailable", ["owner": name])
            let failMsg = NSLocalizedString("Navigation service is currently unavailable. Please try again later.", comment: "Siri failure fallback for profile open")
            let response = OpenOwnerProfileIntentResponse.failure(error: failMsg)
            completion(response)
        }
        // TODO: Apply AppColors/AppFonts tokens for visual SiriKit feedback if ever needed.
    }
}

// MARK: - AppIntents (Modern Swift, Example)

struct OpenDogProfileIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Dog Profile"
    static var description = IntentDescription("Open a specific dog's profile in Furfolio.")

    @Parameter(title: "Dog Name") var dogName: String

    func perform() async throws -> some ProvidesDialog {
        // Try to use DependencyContainer for navigation and audit
        auditLog("dog_profile_opened", ["dog": dogName])
        analyticsTrack("dog_profile_opened", ["dog": dogName])

        let dialogText = NSLocalizedString("Opening profile for \(dogName).", comment: "Dialog shown when opening a dog's profile")
        return .result(dialog: dialogText)
    }
}

// MARK: - FUTURE INTENT EXPANSION

/*
final class OptimizeRouteIntentHandler: NSObject, OptimizeRouteIntentHandling {
    func handle(intent: OptimizeRouteIntent, completion: @escaping (OptimizeRouteIntentResponse) -> Void) {
        // TODO: RouteOptimizer.solve() for TSP-based route planning
    }
}
*/

// MARK: - SECURITY & EXTENSION NOTES

/*
- All intent data must be validated and sanitized.
- Never expose private info in Siri responses.
- Add multi-user/role-based logic for business accounts as needed.
- All error/fallbacks are localized and safe.
- Offline-first design is preserved.
*/
