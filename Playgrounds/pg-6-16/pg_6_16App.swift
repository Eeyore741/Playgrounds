//
//  pg_6_16App.swift
//  pg-6-16
//
//  Created by Vitalii Kuznetsov on 2025-12-29.
//

import SwiftUI

@main
struct pg_6_16App: App {
    
    @ObservedObject private(set) var viewModel: BooksViewModel = .init(booksProider: LocalBooksProvider())
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView(viewModel: viewModel)
            }
        }
    }
}
