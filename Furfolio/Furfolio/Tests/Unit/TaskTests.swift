//
//  TaskTests.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import XCTest
@testable import Furfolio

final class TaskTests: XCTestCase {
    var task: Task!
    var recurringTask: Task!

    override func setUpWithError() throws {
        try super.setUpWithError()
        task = Task(
            title: "Call client for feedback",
            notes: "Remind owner about upcoming appointment",
            dueDate: Date().addingTimeInterval(86400), // 1 day from now
            priority: .high,
            isCompleted: false,
            assignedTo: nil,
            recurrence: .none
        )

        recurringTask = Task(
            title: "Sanitize grooming table",
            notes: "After every workday",
            dueDate: Date().addingTimeInterval(-86400), // 1 day ago
            priority: .medium,
            isCompleted: true,
            assignedTo: nil,
            recurrence: .daily
        )
    }

    override func tearDownWithError() throws {
        task = nil
        recurringTask = nil
        try super.tearDownWithError()
    }

    func testTaskInitialization() {
        XCTAssertEqual(task.title, "Call client for feedback")
        XCTAssertEqual(task.priority, .high)
        XCTAssertFalse(task.isCompleted)
    }

    func testTaskCompletionToggle() {
        task.toggleCompletion()
        XCTAssertTrue(task.isCompleted, "Task should be marked complete after toggle")
        task.toggleCompletion()
        XCTAssertFalse(task.isCompleted, "Task should be marked incomplete after second toggle")
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
    }

    func testRecurringTaskDueNext() {
        guard let nextDate = recurringTask.nextDueDate else {
            XCTFail("Recurring task should have a next due date")
            return
        }
        XCTAssertGreaterThan(nextDate, recurringTask.dueDate!, "Next due date should be after last due date")
    }

    func testTaskAssignment() {
        let user = User(name: "Sam", role: .staff)
        task.assignedTo = user
        XCTAssertEqual(task.assignedTo?.name, "Sam")
    }

    func testTaskPriorityLevels() {
        let highTask = Task(title: "High", notes: nil, dueDate: Date(), priority: .high, isCompleted: false, assignedTo: nil, recurrence: .none)
        let medTask = Task(title: "Med", notes: nil, dueDate: Date(), priority: .medium, isCompleted: false, assignedTo: nil, recurrence: .none)
        let lowTask = Task(title: "Low", notes: nil, dueDate: Date(), priority: .low, isCompleted: false, assignedTo: nil, recurrence: .none)
        XCTAssertTrue(highTask.priority.rawValue > medTask.priority.rawValue)
        XCTAssertTrue(medTask.priority.rawValue > lowTask.priority.rawValue)
    }

    func testRecurringTasksAreRecognized() {
        XCTAssertTrue(recurringTask.isRecurring)
        XCTAssertFalse(task.isRecurring)
    }
}
