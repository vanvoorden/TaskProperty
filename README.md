# Task Property: Reusing Stateful Business Logic for SwiftUI Views

The documentation for [`SwiftUI.DynamicProperty`](https://developer.apple.com/documentation/swiftui/dynamicproperty) does not currently ship with real-world examples or sample code that shows developers how to approach building their own dynamic properties. Developers building on SwiftUI are probably already familiar with the dynamic properties shipping directly from Apple:

* [`SwiftUI.State`](https://developer.apple.com/documentation/swiftui/state)
* [`SwiftUI.Binding`](https://developer.apple.com/documentation/swiftui/binding)
* [`SwiftUI.Environment`](https://developer.apple.com/documentation/swiftui/environment)

What about *our own* dynamic properties? How can those be built? Why would we want our own dynamic properties?

Dynamic Properties are a good place to put “business” logic: algorithms or patterns we might want to share across multiple view components. Dynamic Properties also compose well with *other* dynamic properties: we can make them *stateful*. We will work together through an example to see how this can work and how this can lead to code that is easier to maintain over time.

## View Modifiers

Suppose we are building a simple view component to display a clock. Our only job for now is to just display the current time and update every second.

Our first approach could be to build from the [`task(name:priority:file:line:_:)`](https://developer.apple.com/documentation/swiftui/view/task(name:priority:file:line:_:)) view modifier:

```swift
import AsyncAlgorithms
import SwiftUI

struct TimerDetailView: View {
  @State private var date = Date.now
  
  var body: some View {
    Text(
      self.date,
      format: Date.FormatStyle(time: .standard)
    ).task {
      let taskID = UUID()
      print("Task \(taskID) has started.")
      defer {
        print("Task \(taskID) has been cancelled.")
      }
      self.date = Date.now
      for await _ in AsyncTimerSequence.repeating(every: .seconds(1.0)) {
        let now = Date.now
        self.date = now
        print(
          "Task \(taskID) :",
          now.formatted(
            date: .omitted,
            time: .standard
          )
        )
      }
    }
  }
}
```

This example is inspired by an essay from Fatbobman.[^1]

Our `TimerDetailView` has one `State` variable: the current `Date`. Our `body` property attaches a `task` view modifier: we begin an `AsyncTimerSequence` to update our `Date` every second.

Let’s add some more code to put this in a real application:

```swift
struct TimerView: View {
  @State private var isPresented = false
  @State private var id = UUID()
  
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
struct TaskDemoApp: App {
  var body: some Scene {
    WindowGroup {
      TabView {
        TimerView()
        TimerView()
      }
    }
  }
}
```

We can build and run our application to learn a little more about the behavior of our `task` modifier.

* Our application launches with a `TabView` to display two different `TimerView` components.
* Each `TimerView` displays a `Button` to show our `TimerDetailView`.
* Our `TimerView` also displays a `Button` to reset the `id` of our `TimerDetailView`.

This example is not very complex, but we can learn a lot about `task` from running our application:

* Tapping the "Show Timer" button begins our `AsyncTimerSequence` with a new `Task`.
* Tapping the "Reset Timer" button cancels our current `Task` and begins a new one.
* Tapping the "Hide Timer" button cancels our current `Task`.
* Selecting tab two from our `TabView` cancels our current `Task` from tab one. Switching back to tab one then begins a new `Task`. As we learned from Fatbobman, SwiftUI is working here for us to behave similar to the [`onAppear(perform:)`](https://developer.apple.com/documentation/swiftui/view/onappear(perform:)) and [`onDisappear(perform:)`](https://developer.apple.com/documentation/swiftui/view/ondisappear(perform:)) modifiers.

This is all great! So what’s the problem? It’s the always inevitable “changing requirements”.[^2] We brought this to our product managers and now we want a *different* view component that *also* needs a current `Date` updated every second. What options do we have to then implement two or more view components built from an `AsyncTimerSequence` that updates on every second?

Well… we could start by just copying the implementation to our new view component:

```swift
struct NewDetailView: View {
  @State private var date = Date.now
  
  var body: some View {
    SomeOtherView(
      self.date
    ).task {
      let taskID = UUID()
      print("Task \(taskID) has started.")
      defer {
        print("Task \(taskID) has been cancelled.")
      }
      self.date = Date.now
      for await _ in AsyncTimerSequence.repeating(every: .seconds(1.0)) {
        let now = Date.now
        self.date = now
        print(
          "Task \(taskID) :",
          now.formatted(
            date: .omitted,
            time: .standard
          )
        )
      }
    }
  }
}
```

Our `NewDetailView` now behaves similarly to our original `TimerDetailView`. This works… but you can see how this becomes difficult to scale. What happens when the business logic inside `task` needs to be updated? We have to update it in two different places if we want them to behave consistently. We are also “sneaking” imperative logic inside our view component: *when* the `AsyncTimerSequence` fires *then* we update our `State`. It’s not very *declarative*.

## Containers and Presenters

Suppose `TimerDetailView` and `NewDetailView` did not themselves *directly* perform the business logic to manage this `AsyncTimerSequence`. Suppose we delegate that work to *another* view component which then passes the current `Date` as a property. Then we can keep our business logic factored in just one place.

Here is a `TimerContainer` to get us started:

```swift
struct TimerContainer<Content: View>: View {
  @State private var date = Date.now
  
  private let content: (Date) -> Content
  
  init(@ViewBuilder content: @escaping (Date) -> Content) {
    self.content = content
  }
  
  var body: some View {
    self.content(self.date).task {
      let taskID = UUID()
      print("Task \(taskID) has started.")
      defer {
        print("Task \(taskID) has been cancelled.")
      }
      self.date = Date.now
      for await _ in AsyncTimerSequence.repeating(every: .seconds(1.0)) {
        let now = Date.now
        self.date = now
        print(
          "Task \(taskID) :",
          now.formatted(
            date: .omitted,
            time: .standard
          )
        )
      }
    }
  }
}
```

All we need then is a `TimerPresenter` to display our `Date`:

```swift
struct TimerPresenter: View {
  private let date: Date
  
  init(date: Date) {
    self.date = date
  }
  
  var body: some View {
    Text(
      self.date,
      format: Date.FormatStyle(time: .standard)
    )
  }
}
```

And our new `TimerDetailView` composes these two together:

```swift
struct TimerDetailView: View {
  var body: some View {
    TimerContainer { date in
      TimerPresenter(date: date)
    }
  }
}
```

Those of you who have a background programming on ReactJS might recognize a similar pattern here: *Containers* and *Presenters*.[^3] Our `TimerPresenter` does not itself directly manage any `State`: it receives each `Date` as a property from a `TimerContainer`. The business logic to manage an `AsyncTimerSequence` can live in just one place: the container. We can then build any new presenter components for our changing requirements *without* duplicating the logic to manage an `AsyncTimerSequence`.

This looks like an improvement. So what is it about this approach that could go wrong?

* Our `TimerDetailView` composes together `TimerContainer` and `TimerPresenter`. But what if we need to use `TimerContainer` together with a much larger view component that is already shipping? Factoring presentation logic down out of a larger view component down to a presenter would be touching a lot of code. If *every* view component that needed to use our shared `TimerContainer` needed to change hundreds of lines of code to add that support… this can add a lot of extra friction once we factor code review and testing.
* Our `TimerDetailView` is responsible for “feeding” `Date` values from `TimerContainer` to `TimerPresenter`. Again… it’s not very declarative. What would happen if `TimerPresenter` actually needed *another* property from a *different* container? Now we add *more* imperative logic that wires everything together.
* When our `TimerContainer` updates our `Date` we construct a *new* `TimerPresenter` *every time*. This might not be so bad… constructing view components can and should be cheap. But it might add up to expensive work if we call this many times and we have no choice but to perform some expensive operations in our constructor.
* We construct our `TimerContainer` with an *escaping* closure. This can have important side-effects like breaking optimizations in the SwiftUI infra that can prevent unnecessary `body` computations.[^4]

## Defining Dynamic Properties

Let’s try and rethink our approach. Suppose we start from the perspective of our original `TimerDetailView`. What would we *want* this to look like? If we really tried to “think declaratively”… what could a potential `TimerDetailView` look like *without* business logic to manage an `AsyncTimerSequence`?

```swift
struct TimerDetailView: View {
  @TimerProperty private var date
  
  var body: some View {
    Text(
      self.date,
      format: Date.FormatStyle(time: .standard)
    )
  }
}
```

If there did exist some potential `TimerProperty` here that had *its own* business logic to manage an `AsyncTimerSequence` this would give us an alternative that avoids a lot of the drawbacks of our previous two approaches. It’s easy. It’s clean. It’s simple. It’s declarative.

Let’s build `TimerProperty`:

```swift
@MainActor
@propertyWrapper struct TimerProperty: @MainActor DynamicProperty {
  @State private var storage = TimerPropertyStorage()
  
  var wrappedValue: Date {
    self.storage.date
  }
  
  func update() {
    self.storage.update { @MainActor [weak storage = self.storage] in
      let taskID = UUID()
      print("Task \(taskID) has started.")
      defer {
        print("Task \(taskID) has been cancelled.")
      }
      storage?.update(date: Date.now)
      for await _ in AsyncTimerSequence.repeating(every: .seconds(1.0)) {
        let now = Date.now
        storage?.update(date: now)
        print(
          "Task \(taskID) :",
          now.formatted(
            date: .omitted,
            time: .standard
          )
        )
      }
    }
  }
}
```

Our `TimerProperty` is not complex. Let’s look through all we have so far:

* `TimerProperty` declares a private `State` variable to manage a `TimerPropertyStorage` reference. We will talk more about this later.
* `TimerProperty` is a property wrapper. The `wrappedValue` property returns the `date` property from our `TimerPropertyStorage` reference.
* `TimerProperty` adopts `DynamicProperty`. The `update` method is forwarded to our `TimerPropertyStorage` reference with the same business logic we previously defined in our view components.

Let’s build `TimerPropertyStorage`:

```swift
@Observable
@MainActor
final class TimerPropertyStorage {
  private(set) var date = Date.now
  private var task: Task<Void, Never>?
  
  @MainActor deinit {
    self.task?.cancel()
  }
  
  func update(_ action: sending @escaping @isolated(any) () async -> ()) {
    if let _ = self.task {
      return
    }
    self.task = Task.immediate(operation: action)
  }
  
  func update(date: Date) {
    self.date = date
  }
}
```

Let’s look through here one step at a time:

* `TimerPropertyStorage` is an `Observable` class bound to the `MainActor`.
* `TimerPropertyStorage` has one `Observable` property: a `Date` value.
* `TimerPropertyStorage` owns a private `Task`.
* `TimerPropertyStorage` cancels its `Task` when `deinit` is called and this reference is deallocated.

We also define two `update` methods: one method will create a new `Task` (assuming we did not already create one) and the other method will update our `Date`.

Let’s now look back at `TimerProperty` and see what happens during the SwiftUI lifecycle:[^5]

* We construct our view component and construct a new `TimerProperty` value.
* The *first* time our view component is constructed we save a new `TimerPropertyStorage` reference to `State`. From modern SDKs, `State` will be a macro that will only create a new reference once.[^6]
* The `DynamicProperty` contract tells us that `update` will be called before `body`. This implies that before every `body` is computed we have started a `Task`. If `body` is called again we do *not* create a new `Task` unless our identity has changed.
* When our view component is no longer needed the infra will no longer need its `State`. This implies our `TimerPropertyStorage` will deallocate and call `deinit`. This will cancel our currently running `Task`.

When we run our application built from this new `TimerDetailView` we see *almost* the same behavior as before when we used the `task` modifier:

* Tapping the "Show Timer" button begins our `AsyncTimerSequence` with a new `Task`.
* Tapping the "Reset Timer" button cancels our current `Task` and begins a new one.
* Tapping the "Hide Timer" button cancels our current `Task`.
* Selecting tab two from our `TabView` *does not* cancel our current `Task` from tab one.

So what happened? Our `TimerProperty` is working correctly at following the basic SwiftUI lifecycle. We start a new task when a new view component is constructed. We cancel a task when a view component is destroyed or its identity has changed. What we don’t have a way to do is automatically “inherit” the ability to respond to `onAppear(perform:)` and `onDisappear(perform:)` modifiers. A future direction of our `TimerProperty` might look something like this:

```swift
extension TimerProperty {
  func onDisappear() {
    ...
  }
}

struct TimerDetailView: View {
  @TimerProperty private var date
  
  var body: some View {
    Text(
      self.date,
      format: Date.FormatStyle(time: .standard)
    ).onDisappear(perform: self._date.onDisappear)
  }
}
```

Now we have the ability to cancel our `Task` when our view component disappears. Also consider that we might not always *want* to cancel our `Task`. Suppose our `Task` performed some kind of expensive operation. We don’t necessarily want to *cancel* our `Task`… we might just want to *pause* it and resume later. With a `task` view modifier on our component we then need extra `State` and business logic to handle resuming. With a `DynamicProperty` we can move most of that imperative logic out of our view component for a solution that is more flexible and reusable.

## Composing Dynamic Properties

Our new `TimerProperty` gives us a place to put stateful business logic in a way that is more reusable and flexible than putting that business logic directly in a view component. But what if we wanted something even *more* reusable and *more* flexible?

Suppose our product managers bring to us a new view component that needs to update time every second. We have that already: `TimerProperty`. But suppose our product managers bring to us a new view component that needs some *other* asynchronous operation. This could be a network connection or something else expensive that we don’t want to block on `MainActor`.

What would happen if we built a new `DynamicProperty` with all the business logic to manage our new asynchronous operation? There might still be some shared overlap between what we already have: `TimerProperty` already manages a `Task` that starts and stops with the view lifecycle.

Let’s take what we learned so far and try something new: we’re going to *compose* custom dynamic properties together. The example we build together could then help you think creatively about how this pattern can be used to solve problems for your own products.

Let’s start with our existing `TimerDetailView`:

```swift
struct TimerDetailView: View {
  @TimerProperty private var date: Date
  
  var body: some View {
    Text(
      self.date,
      format: Date.FormatStyle(time: .standard)
    )
  }
}
```

This looks great: it’s simple and declarative. We want to keep this working the same way. Let’s open up `TimerProperty` and look at a different way to manage our `Task`:

```swift
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
        print(
          "Task \(taskID) :",
          now.formatted(
            date: .omitted,
            time: .standard
          )
        )
      }
    }
  }
}
```

This looks *mostly* the same as before. Let’s walk through what changed:

* We define a new `task` variable that saves a `TaskProperty`. We’ll say more about this later.
* Our `update` method now forwards its asynchronous business logic through to our `TaskProperty` value instead of its `TimerPropertyStorage` reference.

Let’s see how we can clean up our `TimerPropertyStorage`:

```swift
@Observable
@MainActor
final class TimerPropertyStorage {
  private(set) var date = Date.now
  
  func update(date: Date) {
    self.date = date
  }
}
```

All the business logic to manage a `Task` will exist somewhere else. Let’s build our `TaskProperty`:

```swift
@MainActor
struct TaskProperty: @MainActor DynamicProperty {
  @State private var storage = TaskPropertyStorage()
  
  func update(_ action: sending @escaping @isolated(any) () async -> Void) {
    self.storage.update(action)
  }
}
```

You might expect `TaskProperty` to also be a property wrapper. This would be more consistent with the existing property wrappers that already ship from SwiftUI. A `DynamicProperty` usually is a property wrapper but this is not a requirement. If we *did* make `TaskProperty` a property wrapper our `wrappedValue` would just be `Void`.

Here is our `TaskPropertyStorage`:

```swift
final class TaskPropertyStorage {
  private var task: Task<Void, Never>?
  
  deinit {
    self.task?.cancel()
  }
  
  func update(_ action: sending @escaping @isolated(any) () async -> ()) {
    if let _ = self.task {
      return
    }
    self.task = Task.immediate(operation: action)
  }
}
```

We can compare this to our previous approach and begin to see why breaking this in two pieces was a good idea. `TaskPropertyStorage` is focused *just* on managing the lifecycle of a `Task`: it does not know about a `Date` or any other value we might *produce* from that `Task`. `TimerPropertyStorage` is focused *just* on managing a `Date` value: it does not know anything about an asynchronous operation which might produce that value.

Imagine an `ImageProperty` that knows how to download an image from a URL as an asynchronous operation. This could be built using our `TaskProperty`. The advantage is that the work to manage a `Task` can exist in just one place: `TaskProperty`. We don’t have to manage a `Task` in `ImageProperty` *and* `TimerProperty`.

When we run our application we see the same behavior as before:

* Tapping the "Show Timer" button begins our `AsyncTimerSequence` with a new `Task`.
* Tapping the "Reset Timer" button cancels our current `Task` and begins a new one.
* Tapping the "Hide Timer" button cancels our current `Task`.

Factoring stateful and imperative business logic out of view components is a good step to keep that business logic reusable and flexible. When your product requirements change your dynamic properties will help make it easy to bring that business logic to more places.

Those of you who are have a background in ReactJS might recognize a similar pattern here: Hooks.[^7] Hooks introduced a stateful primitive to React: an alternative to keeping business logic in view components.

## Dynamic Updates

Let’s try and think through a more advanced example. Our `TimerProperty` gives us stateful business logic to update our `Date` value every second. Suppose we wanted more control over when those updates happen. Suppose we want our view component to control the interval our `AsyncTimerSequence` repeats from.

Here is a new version of `TimerDetailView` with a `Stepper` control:

```swift
struct TimerDetailView: View {
  @TimerProperty private var date: Date
  @State private var interval = 1
  
  var body: some View {
    VStack {
      Text(
        self.date,
        format: Date.FormatStyle(time: .standard)
      )
      Stepper(
        value: self.$interval,
        in: 1...3,
        step: 1
      ) {
        Text(
          self.interval,
          format: .number
        )
      }
    }
  }
}
```

From the `Stepper` we can choose from one to three seconds to update our `Date` value. The problem is we don’t currently have a way to communicate that new `interval` value to our `TimerProperty`.

Let’s see another approach:

```swift
struct TimerDetailView: View {
  @TimerProperty private var date: Date
  
  var body: some View {
    VStack {
      Text(
        self.date,
        format: Date.FormatStyle(time: .standard)
      )
      Stepper(
        value: self._date.$interval,
        in: 1...3,
        step: 1
      ) {
        Text(
          self._date.interval,
          format: .number
        )
      }
    }
  }
}
```

We’re no longer *directly* saving the state of our `interval` in our component itself: it belongs in `TimerProperty`:

```swift
@MainActor
@propertyWrapper struct TimerProperty: @MainActor DynamicProperty {
  @State private var storage = TimerPropertyStorage()
  @State var interval = 1

  private var task = TaskProperty()
  
  var wrappedValue: Date {
    self.storage.date
  }
  
  func update() {
    self.task.update { @MainActor [
      weak storage = self.storage,
      interval = self.interval
    ] in
      let taskID = UUID()
      print("Task \(taskID) has started.")
      defer {
        print("Task \(taskID) has been cancelled.")
      }
      storage?.update(date: Date.now)
      for await _ in AsyncTimerSequence.repeating(every: .seconds(interval)) {
        let now = Date.now
        storage?.update(date: now)
        print(
          "Task \(taskID) :",
          now.formatted(
            date: .omitted,
            time: .standard
          )
        )
      }
    }
  }
}
```

We’re heading in the right direction… but this is still not working correctly. When our `Stepper` selects a new `interval` our `Date` continues updating every second. What we want is to somehow *dynamically* update `TaskProperty`.

One way to solve this is to look at how SwiftUI handles a similar problem. We will pass an `id` value to our `TaskProperty`. This will behave in a similar way to the [`task(id:name:priority:file:line:_:)`](https://developer.apple.com/documentation/swiftui/view/task(id:name:priority:file:line:_:)) view modifier. Passing a new `id` value will cancel the previous `Task` and start a new one.

Here is a new version of `TaskProperty` that accepts an `id`:

```swift
@MainActor
struct TaskProperty<T: Equatable>: @MainActor DynamicProperty {
  @State private var storage = TaskPropertyStorage<T>()
  
  func update(
    id: T,
    _ action: sending @escaping @isolated(any) () async -> Void
  ) {
    self.storage.update(
      id: id,
      action
    )
  }
}
```

And here is our new `TaskPropertyStorage`:

```swift
final class TaskPropertyStorage<T: Equatable> {
  private var id: T?
  private var task: Task<Void, Never>?
  
  deinit {
    self.task?.cancel()
  }
  
  func update(
    id: T,
    _ action: sending @escaping @isolated(any) () async -> Void
  ) {
    if self.id != id {
      self.id = id
      self.task?.cancel()
      self.task = nil
    }
    if let _ = self.task {
      return
    }
    self.task = Task.immediate(operation: action)
  }
}
```

When we call `update` with a `id` that is not equal to the previous `id` we cancel our task and start a new one.

We can now update our `TimerProperty` to pass the `interval` as an `id`:

```swift
@MainActor
@propertyWrapper struct TimerProperty: @MainActor DynamicProperty {
  @State private var storage = TimerPropertyStorage()
  @State var interval = 1

  private var task = TaskProperty<Int>()
  
  var wrappedValue: Date {
    self.storage.date
  }
  
  func update() {
    self.task.update(id: self.interval) { @MainActor [
      weak storage = self.storage,
      interval = self.interval
    ] in
      let taskID = UUID()
      print("Task \(taskID) has started.")
      defer {
        print("Task \(taskID) has been cancelled.")
      }
      storage?.update(date: Date.now)
      for await _ in AsyncTimerSequence.repeating(every: .seconds(interval)) {
        let now = Date.now
        storage?.update(date: now)
        print(
          "Task \(taskID) :",
          now.formatted(
            date: .omitted,
            time: .standard
          )
        )
      }
    }
  }
}
```

We can build and run our application to now see the expected behavior. Our application starts with a timer that fires every second. Selecting a new value from our `Picker` is correctly selecting the new interval our `AsyncTimerSequence` repeats from.

If this starts to look a little like “magic” to you… try and also think through the contract that was promised by `DynamicProperty`. The SwiftUI infra will call our `update` *before* our `body` property is computed. If our view component uses a `Binding` on our `interval` to select a new value this will then compute a new `body` property. But *before* that new `body` property is computed we get `update` called. And when that `update` is called we have the *new* value of `interval` available.

## Next Steps

Hopefully these examples gave you some practical ideas to start thinking creatively about where to put stateful business logic. Start by auditing your own products. Do any of your view components contain stateful business logic? Could any of your view components *share* that stateful business logic if it was built in just one place? Try starting here: build a `DynamicProperty` that can then be reused across multiple view components. Then see if your custom dynamic properties could *also* share stateful business logic. Think about how you can compose custom dynamic properties together.

## References

The following references are great resources to learn more about `DynamicProperty`:

* Dave DeLong • [Custom Property Wrappers for SwiftUI](https://davedelong.com/blog/2021/04/02/custom-property-wrappers-for-swiftui/) • 2021
* Dave DeLong • [Core Data and SwiftUI](https://davedelong.com/blog/2021/04/03/core-data-and-swiftui/) • 2021
* Fatbobman • [How to Avoid Repeating SwiftUI View Updates](https://fatbobman.com/en/posts/avoid_repeated_calculations_of_swiftui_views/) • 2022
* Saagar Jha • [Making Friends with AttributeGraph](https://saagarjha.com/blog/2024/02/27/making-friends-with-attributegraph/) • 2024
* Shadowfacts • [Custom Property Wrappers in SwiftUI](https://shadowfacts.net/2025/swiftui-property-wrappers/) • 2025

[^1]: <https://fatbobman.com/en/posts/mastering_swiftui_task_modifier/>
[^2]: <https://martinfowler.com/distributedComputing/soft.pdf>
[^3]: <https://medium.com/@dan_abramov/smart-and-dumb-components-7ca2f9a7c7d0>
[^4]: <https://rensbr.eu/blog/swiftui-escaping-closures/>
[^5]: <https://fatbobman.com/en/posts/swiftuilifecycle/>
[^6]: <https://developer.apple.com/videos/play/wwdc2026/269/>
[^7]: <https://www.youtube.com/watch?v=dpw9EHDh2bM>
