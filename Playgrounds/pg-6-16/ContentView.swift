//
//  ContentView.swift
//  pg-6-16
//
//  Created by Vitalii Kuznetsov on 2025-12-29.
//

import SwiftUI
import Combine

// To not to use SwiftUI in data model.
typealias SimpleColor = (Double, Double, Double)

func randomSampleColor() -> SimpleColor {
    (
        Double(Int.random(in: 0...255)) / 255,
        Double(Int.random(in: 0...255)) / 255,
        Double(Int.random(in: 0...255)) / 255,
    )
}

struct Book {
    let id: UUID
    let name: String
    let color: SimpleColor
    let rating: Int
}

// To be able to use in SwiftUI ForEach loop
extension Book: Identifiable { }

extension Book {
    static let localShelf: [Book] = [
        Book(id: UUID(), name: "A Tale of Two Cities", color: SimpleColor(255/255, 0, 0), rating: 1),
        Book(id: UUID(), name: "The Little Prince", color: SimpleColor(255/255, 96/255, 208/255), rating: 2),
        Book(id: UUID(), name: "The Alchemist", color: SimpleColor(150/255, 100/255, 180/255), rating: 3),
        Book(id: UUID(), name: "Harry Potter and the Philosopher's Stone", color: SimpleColor(80/255, 0, 255/255), rating: 4),
        Book(id: UUID(), name: "And Then There Were None", color: SimpleColor(0, 192/255, 0), rating: 5),
        Book(id: UUID(), name: "Alice's Adventures in Wonderland", color: SimpleColor(255/255, 160/255, 16/255), rating: 0),
    ]
}

// Actor required, otherwise error: "Isolation mismatch" (on Actor conformance).
// Hence makes requirements actor-isolated.
// Swift can not promise Portocol thread safety, if not restricted to Actor.
// Error triggered on `booksStream` of Actor impl, it promises safe (isolated) but protocol deos not promise it if not Actor restricted.
// nonisolated makes it possible to call with no await, does not require separate actor hop.
protocol BooksProider: Actor {
    nonisolated var booksStream: AsyncStream<[Book]> { get }
    nonisolated func makeBookAsyncStream() async -> AsyncStream<[Book]>
    func fetchBooks() async throws
    func addBook(_ book: Book) async throws
}

// Actor properties are implicitly async externally.
// Actor properties are sync internally.
// Actor functions are never implicitly async.
actor LocalBooksProvider: BooksProider {
    
    private var books: [Book] = []
    private var continuations: [UUID: AsyncStream<[Book]>.Continuation] = [:]
    
    // Var in Actor is async for public use but does not require await for internal use.
    // Exposed var are not recommended for Actor. Preferred: getState(), getStream().
    nonisolated var booksStream: AsyncStream<[Book]> {
        AsyncStream { continuation in
            // Here we use Unstructured Task, lifetime isn't tied to the scope where it was created.
            Task { await self.addContinuation(continuation) }
        }
    }
    
    // Here self.addContinuation wrapped in Task since:
    // 1. Call is async and closure is not async.
    // 2. Closure is nonisolated. Can be called from anywhere.
    // 3. Need to do an actor hop since called on actor.
    // Nonisolated to make it clear. Without it, Swift inserts an implicit actor hop to read the property.
    nonisolated func makeBookAsyncStream() async -> AsyncStream<[Book]> {
        AsyncStream { continuation in
            Task { await self.addContinuation(continuation) } // Task scheduled on global executor.
        }
    }
    
    func fetchBooks() async throws {
        try await Task.sleep(for: .seconds(2))
        
        self.books = await Book.localShelf
        self.continuations.forEach { $0.value.yield(self.books) }
    }
    
    func addBook(_ book: Book) async throws {
        try await Task.sleep(for: .seconds(1))
        
        self.books.append(book)
        self.continuations.forEach { $0.value.yield(self.books) }
    }
    
    // Func is private but still has to be async since:
    // 1. Its being called outside of actor scope (passed in closure of public func) possibly on nonisolated scope.
    // 2. It mutates actor state (private var changes).
    private func addContinuation(_ continuation: AsyncStream<[Book]>.Continuation) async {
        let key = UUID()
        self.continuations[key] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuationForKey(key) }
        }
        continuation.yield(self.books)
    }
    
    private func removeContinuationForKey(_ key: UUID) async {
        self.continuations.removeValue(forKey: key)
    }
}

// The MainActor is not a concurrent thread, its serialized executor, but it is reentrant.
// await calls within it execute in separate Tasks and come back in queue when finished.
@MainActor
final class BooksViewModel: ObservableObject {
    
    @Published var books: [Book] = []
    private let booksProider: any BooksProider
    private var task: Task<Void, Never>?
    
    init(booksProider: BooksProider) {
        self.booksProider = booksProider
        self.startObserving()
    }
    
    deinit {
        self.task?.cancel()
    }
    
    // Not async since better to handle Task logic in view model instead of view
    func onAppear() {
        // inherits prio from parent Task, here @MainActor, since called on Actor data provider.
        // If data provider is class, Task.detached(priority: .background) better to be used.
        Task(priority: .userInitiated) {
            guard self.books.isEmpty else { return }
            
            try? await self.booksProider.fetchBooks()
        }
    }
    
    func onAddBook() {
        Task(priority: .userInitiated) {
            let newBook = Book(id: UUID(), name: "New Book", color: randomSampleColor(), rating: 3)
            
            try? await self.booksProider.addBook(newBook)
        }
    }
    
    private func startObserving() {
        self.task?.cancel()
        
        self.task = Task { [weak self] in
            guard let self,
                    Task.isCancelled == false
            else { return }
            // await called on actor here is "Actor-hop await".
            for await books in await self.booksProider.makeBookAsyncStream() { // in await needed since func is async.
//            for await books in booksProider.booksStream { // here: in await is not needed since accessing nonisolated var.
                if Task.isCancelled { break }
                self.books = books
            }
        }
    }
}

struct ContentView: View {
    
    @ObservedObject var viewModel: BooksViewModel
    
    var body: some View {
        ScrollView {
            LazyVGrid (
                columns: [GridItem(.adaptive(minimum: 120), spacing: 20)],
                spacing: 20
            ) {
                ForEach(self.viewModel.books) { book in
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: book.color.0, green: book.color.1, blue: book.color.2))
                            .shadow(radius: 1)
                        Text(book.name)
                            .font(.title2)
                            .padding()
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .navigationTitle("Books View")
        .toolbar { toolbar() }
        .task {
            self.viewModel.onAppear()
        }
        .padding()
    }
    
    private func toolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button("Add") {
                self.viewModel.onAddBook()
            }
        }
    }
}

#Preview {
    let dataProvider = LocalBooksProvider()
    let viewModel = BooksViewModel(booksProider: dataProvider)
    ContentView(viewModel: viewModel)
}
