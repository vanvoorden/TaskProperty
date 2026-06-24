//
//  Copyright 2026 North Bronson Software
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if canImport(SwiftUI)

import SwiftUI

@MainActor
public struct TaskProperty: @MainActor DynamicProperty {
  @State private var storage = Storage()
  
  public init() {
    
  }
}

extension TaskProperty {
  @available(*, unavailable)
  public func update<T: Equatable>(
    id: T,
    name: String? = nil,
    executorPreference taskExecutor: any TaskExecutor,
    priority: TaskPriority = .userInitiated,
    file: String = #fileID,
    line: Int = #line,
    _ action: sending @escaping @isolated(any) () async -> Void
  ) {
    self.storage.update(
      id: id,
      name: name,
      executorPreference: taskExecutor,
      priority: priority,
      file: file,
      line: line,
      action
    )
  }
}

extension TaskProperty {
  @available(*, unavailable)
  public func update<T: Equatable>(
    id: T,
    name: String? = nil,
    priority: TaskPriority = .userInitiated,
    file: String = #fileID,
    line: Int = #line,
    _ action: sending @escaping @isolated(any) () async -> Void
  ) {
    self.storage.update(
      id: id,
      name: name,
      priority: priority,
      file: file,
      line: line,
      action
    )
  }
}

extension TaskProperty {
  public func update(
    name: String? = nil,
    executorPreference taskExecutor: any TaskExecutor,
    priority: TaskPriority = .userInitiated,
    file: String = #fileID,
    line: Int = #line,
    action: sending @escaping @isolated(any) () async -> Void
  ) {
    self.storage.update(
      name: name,
      executorPreference: taskExecutor,
      priority: priority,
      file: file,
      line: line,
      action
    )
  }
}

extension TaskProperty {
  public func update(
    name: String? = nil,
    priority: TaskPriority = .userInitiated,
    file: String = #fileID,
    line: Int = #line,
    _ action: sending @escaping @isolated(any) () async -> Void
  ) {
    self.storage.update(
      name: name,
      priority: priority,
      file: file,
      line: line,
      action
    )
  }
}

extension TaskProperty {
  package final class Storage {
    private var task: Task<Void, Never>?
    
    deinit {
      self.task?.cancel()
    }
  }
}

extension TaskProperty.Storage {
  package func update<T: Equatable>(
    id: T,
    name: String? = nil,
    executorPreference taskExecutor: any TaskExecutor,
    priority: TaskPriority = .userInitiated,
    file: String = #fileID,
    line: Int = #line,
    _ action: sending @escaping @isolated(any) () async -> Void
  ) {
    fatalError("unavailable")
  }
}

extension TaskProperty.Storage {
  package func update<T: Equatable>(
    id: T,
    name: String? = nil,
    priority: TaskPriority = .userInitiated,
    file: String = #fileID,
    line: Int = #line,
    _ action: sending @escaping @isolated(any) () async -> Void
  ) {
    fatalError("unavailable")
  }
}

extension TaskProperty.Storage {
  package func update(
    name: String? = nil,
    executorPreference taskExecutor: any TaskExecutor,
    priority: TaskPriority = .userInitiated,
    file: String = #fileID,
    line: Int = #line,
    _ action: sending @escaping @isolated(any) () async -> Void
  ) {
    if let _ = self.task {
      return
    }
    self.task = Task.immediate(
      name: name,
      priority: priority,
      executorPreference: taskExecutor,
      operation: action
    )
  }
}

extension TaskProperty.Storage {
  package func update(
    name: String? = nil,
    priority: TaskPriority = .userInitiated,
    file: String = #fileID,
    line: Int = #line,
    _ action: sending @escaping @isolated(any) () async -> Void
  ) {
    if let _ = self.task {
      return
    }
    self.task = Task.immediate(
      name: name,
      priority: priority,
      operation: action
    )
  }
}

#endif
