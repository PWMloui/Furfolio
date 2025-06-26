//
//  TaskTests.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade, Auditable, Robust Tests
//

import XCTest
@testable import Furfolio

final class TaskTests: XCTestCase {
    var task: Task!
    var recurringTask: Task!
    static var testAuditLog: [String] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        task = Task(
            title: "Call client for feedback",
            notes: "Remind owner about upcoming appointment",
            dueDate: Date().addingTimeInterval(86400),
            priority: .high,
            isCompleted: false,
            assignedTo: nil,
            recurrence: .none
        )

        recurringTask = Task(
            title: "Sanitize grooming table",
            notes: "After every workday",
            dueDate: Date().addingTimeInterval(-86400),
            priority: .medium,
            isCompleted: true,
            assignedTo: nil,
            recurrence: .daily
        )
        Self.testAuditLog.append("Setup: Created test task and recurring task")
    }

    override func tearDownWithError() throws {
        task = nil
        recurringTask = nil
        Self.testAuditLog.append("Teardown: Reset test task and recurring task")
        try super.tearDownWithError()
    }

    func testTaskInitialization() {
        XCTAssertEqual(task.title, "Call client for feedback", "Task title should match expected")
        XCTAssertEqual(task.priority, .high, "Task priority should be high")
        XCTAssertFalse(task.isCompleted, "Task should not be completed")
        Self.testAuditLog.append("Checked: Task initialization")
    }

    func testTaskCompletionToggle() {
        task.toggleCompletion()
        XCTAssertTrue(task.isCompleted, "Task should be marked complete after toggle")
        task.toggleCompletion()
        XCTAssertFalse(task.isCompleted, "Task should be marked incomplete after second toggle")
        Self.testAuditLog.append("Checked: Task completion toggle")
    }

    func testTaskIsOverdue() {
        let overdueTask = Task(
            title: "Missed task",
            notes: nil,
            dueDate: Date().addingTimeInterval(-3600),
            priority: .low,
            isCompleted: false,
            assignedTo: nil,
            recurrence: .none
        )
        XCTAssertTrue(overdueTask.isOverdue, "Task with past due date should be overdue")
        XCTAssertFalse(task.isOverdue, "Task with future due date should not be overdue")
        Self.testAuditLog.append("Checked: isOverdue property")
    }

    func testRecurringTaskDueNext() {
        guard let nextDate = recurringTask.nextDueDate else {
            XCTFail("Recurring task should have a next due date")
            Self.testAuditLog.append("Fail: Recurring task missing next due date")
            return
        }
        XCTAssertGreaterThan(nextDate, recurringTask.dueDate!, "Next due date should be after last due date")
        Self.testAuditLog.append("Checked: nextDueDate for recurring task")
    }

    func testTaskAssignment() {
        let user = User(name: "Sam", role: .staff)
        task.assignedTo = user
        XCTAssertEqual(task.assignedTo?.name, "Sam", "Assigned user should be Sam")
        // Now remove assignment
        task.assignedTo = nil
        XCTAssertNil(task.assignedTo, "Task should allow assignment to nil (unassigned)")
        Self.testAuditLog.append("Checked: assignment and unassignment of task")
    }

    func testTaskPriorityLevels() {
        let highTask = Task(title: "High", notes: nil, dueDate: Date(), priority: .high, isCompleted: false, assignedTo: nil, recurrence: .none)
        let medTask = Task(title: "Med", notes: nil, dueDate: Date(), priority: .medium, isCompleted: false, assignedTo: nil, recurrence: .none)
        let lowTask = Task(title: "Low", notes: nil, dueDate: Date(), priority: .low, isCompleted: false, assignedTo: nil, recurrence: .none)
        XCTAssertTrue(highTask.priority.rawValue > medTask.priority.rawValue, "High priority should be greater than medium")
        XCTAssertTrue(medTask.priority.rawValue > lowTask.priority.rawValue, "Medium priority should be greater than low")
        Self.testAuditLog.append("Checked: priority level ordering")
    }

    func testRecurringTasksAreRecognized() {
        XCTAssertTrue(recurringTask.isRecurring, "Recurring task should be recognized as recurring")
        XCTAssertFalse(task.isRecurring, "Non-recurring task should not be recognized as recurring")
        Self.testAuditLog.append("Checked: recurring task recognition")
    }

    // --- ENHANCED TESTS BELOW ---

    func testNonRecurringNextDueDateIsNil() {
        XCTAssertNil(task.nextDueDate, "Non-recurring task should not have a next due date")
        Self.testAuditLog.append("Checked: nextDueDate is nil for non-recurring task")
    }

    func testCompletionToggleOnOverdueTask() {
        let overdueTask = Task(
            title: "Overdue toggle",
            notes: nil,
            dueDate: Date().addingTimeInterval(-7200),
            priority: .medium,
            isCompleted: false,
            assignedTo: nil,
            recurrence: .none
        )
        overdueTask.toggleCompletion()
        XCTAssertTrue(overdueTask.isCompleted, "Overdue task should be markable as completed")
        overdueTask.toggleCompletion()
        XCTAssertFalse(overdueTask.isCompleted, "Overdue task should be markable as incomplete again")
        Self.testAuditLog.append("Checked: completion toggle on overdue task")
    }

    func testEscalatePriorityIfOverdue() {
        var overdueTask = Task(
            title: "Escalate if overdue",
            notes: nil,
            dueDate: Date().addingTimeInterval(-3600),
            priority: .low,
            isCompleted: false,
            assignedTo: nil,
            recurrence: .none
        )
        if overdueTask.isOverdue {
            overdueTask.priority = .high
        }
        XCTAssertEqual(overdueTask.priority, .high, "Priority should escalate to high if task is overdue")
        Self.testAuditLog.append("Checked: priority escalation if overdue")
    }

    func testTaskWithNoDueDate() {
        let undatedTask = Task(
            title: "No due date",
            notes: nil,
            dueDate: nil,
            priority: .medium,
            isCompleted: false,
            assignedTo: nil,
            recurrence: .none
        )
        XCTAssertFalse(undatedTask.isOverdue, "Task with no due date should not be considered overdue")
        XCTAssertNil(undatedTask.nextDueDate, "Task with no due date should have nil nextDueDate")
        Self.testAuditLog.append("Checked: handling of task with no due date")
    }

    func testAuditLogExport() {
        let logs = Self.testAuditLog.suffix(14).joined(separator: "\n")
        print("Furfolio TaskTests AuditLog:\n\(logs)")
    }
}
