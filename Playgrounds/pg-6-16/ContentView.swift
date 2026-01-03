//
//  ContentView.swift
//  pg-6-16
//
//  Created by Vitalii Kuznetsov on 2025-12-29.
//

import SwiftUI
import Combine

typealias SimpleColor = (Double, Double, Double)

struct Book {
    let id: UUID
    let name: String
    let color: SimpleColor
    let rating: Int
}

extension Book: Identifiable { } // To be able to use in SwiftUI ForEach loop

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
protocol BooksProider: Actor {
    nonisolated var booksStream: AsyncStream<[Book]> { get }
    func fetchBooks() async throws
    func addBook(_ book: Book) async throws
}

actor LocalBooksProvider: BooksProider {
    
    private var books: [Book] = []
    private var continuations: [AsyncStream<[Book]>.Continuation] = []
    
    nonisolated var booksStream: AsyncStream<[Book]> {
        AsyncStream { continuation in
            Task { await self.addContinuation(continuation) }
        }
    }
    
    private func addContinuation(_ continuation: AsyncStream<[Book]>.Continuation) {
        self.continuations.append(continuation)
        continuation.yield(self.books)
        
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(continuation) }
        }
    }
    
    private func removeContinuation(_ continuation: AsyncStream<[Book]>.Continuation) {
//        self.continuations.removeAll { $0 === continuation }
    }
    
    func fetchBooks() async throws {
        try await Task.sleep(for: .seconds(2))
        
        self.books = await Book.localShelf
        self.continuations.forEach { $0.yield(self.books) }
    }
    
    func addBook(_ book: Book) async throws {
        
    }
}

@MainActor
final class BooksViewModel: ObservableObject {
    
    @Published var books: [Book] = []
    private let booksProider: any BooksProider
    private var task: Task<Void, Never>?
    
    init(booksProider: BooksProider) {
        self.booksProider = booksProider
        self.task = Task {
            for await books in booksProider.booksStream {
                self.books = books
            }
        }
    }
    
    func onAppear() async {
        guard self.books.isEmpty else { return }
        
        try? await self.booksProider.fetchBooks()
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
            await self.viewModel.onAppear()
        }
        .padding()
    }
    
    private func toolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button("Fetch") {
                
            }
        }
    }
}

#Preview {
    let dataProvider = LocalBooksProvider()
    let viewModel = BooksViewModel(booksProider: dataProvider)
    ContentView(viewModel: viewModel)
}
