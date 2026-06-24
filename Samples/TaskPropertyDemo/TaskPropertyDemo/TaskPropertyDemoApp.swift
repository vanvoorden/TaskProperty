//
//  TaskPropertyDemoApp.swift
//  TaskPropertyDemo
//
//  Created by Rick Van Voorden on 6/24/26.
//

import AsyncAlgorithms
import SwiftUI
import TaskProperty

@Observable
@MainActor
final class TimerPropertyStorage {
  private(set) var date = Date.now
  
  func update(date: Date) {
    self.date = date
  }
}

@MainActor
@propertyWrapper struct TimerProperty: @MainActor DynamicProperty {
  @State private var storage = TimerPropertyStorage()
  
  private var task = TaskProperty()
  
  var wrappedValue: Date {
    self.storage.date
  }
  
  func update() {
    self.task.update { @MainActor [weak storage = self.storage] in
      let taskID = UUID()
      print("Task \(taskID) has started.")
      defer {
        print("Task \(taskID) has been cancelled.")
      }
      storage?.update(date: Date.now)
      for await _ in AsyncTimerSequence.repeating(every: .seconds(1.0)) {
        let now = Date.now
        storage?.update(date: now)
        print("Task \(taskID) : \(now.formatted(date: .omitted, time: .standard))")
      }
    }
  }
}

@MainActor
struct TimerDetailView: View {
  @TimerProperty var date: Date
  
  var body: some View {
    Text(
      self.date,
      format: Date.FormatStyle(time: .standard)
    )
  }
}

@MainActor
struct TimerView: View {
  @State var isPresented = false
  @State var id = UUID()
  
  var body: some View {
    VStack {
      Button(self.isPresented ? "Hide Timer" : "Show Timer") {
        self.isPresented.toggle()
      }
      if self.isPresented {
        TimerDetailView().id(self.id)
        Button("Reset Timer") {
          self.id = UUID()
        }
      }
    }
  }
}

@main
@MainActor
struct TaskPropertyDemoApp: App {
  var body: some Scene {
    WindowGroup {
      TabView {
        TimerView()
        TimerView()
      }
    }
  }
}
