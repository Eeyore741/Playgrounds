//
//  PlaygroundsApp.swift
//  Playgrounds
//
//  Created by Vitalii Kuznetsov on 2025-12-22.
//

import SwiftUI
import Combine

// To not to use SwiftUI in data model.
fileprivate typealias SimpleColor = (Double, Double, Double)

fileprivate func randomSampleColor() -> SimpleColor {
    (
        Double(Int.random(in: 0...255)) / 255,
        Double(Int.random(in: 0...255)) / 255,
        Double(Int.random(in: 0...255)) / 255,
    )
}

fileprivate struct Book {
    let id: UUID
    let name: String
    let color: SimpleColor
    let rating: Int
}

fileprivate  protocol BookProvider {
    func addBook(_ book: Book)
    func makeSubject() -> CurrentValueSubject<[Book], Never>
    func loadBooks()
}

fileprivate actor LocalBookProvider: BookProvider {
    
    private(set) var books: [Book] = []
    
    func addBook(_ book: Book) {
        books.append(book)
    }
    
    func makeSubject() -> CurrentValueSubject<[Book], Never> {
        .init(books)
    }
    
    func loadBooks() {
        
    }
}

fileprivate struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

@main
fileprivate struct PlaygroundsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
