//
//  ContentView.swift
//  Noteai
//
//  Created by Sambit Biswas on 4/7/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var aiServiceWrapper: AIServiceWrapper
    @State private var showingCreateNoteSheet = false
    @State private var sortOrder = [SortDescriptor(\Note.creationDate, order: .reverse)]
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            NoteListView(searchString: searchText, sortOrder: sortOrder)
                .navigationTitle("Noteai")
                .searchable(text: $searchText, prompt: "Search Notes")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Picker("Sort", selection: $sortOrder) {
                                Text("Date Created (Newest First)").tag([SortDescriptor(\Note.creationDate, order: .reverse)])
                                Text("Date Created (Oldest First)").tag([SortDescriptor(\Note.creationDate, order: .forward)])
                                Text("Title (A-Z)").tag([SortDescriptor(\Note.title)])
                                Text("Title (Z-A)").tag([SortDescriptor(\Note.title, order: .reverse)])
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingCreateNoteSheet = true
                        } label: {
                            Label("Add Note", systemImage: "plus.circle.fill")
                        }
                    }
                }
                .sheet(isPresented: $showingCreateNoteSheet) {
                    // Present the view to create a new note
                    CreateNoteView()
                        .environmentObject(aiServiceWrapper)
                }
        }
    }
}

#Preview {
    // Create mock data for preview
    @MainActor
    func previewContent() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Note.self, configurations: config)

        // Add sample notes
        let sampleNotes = [
            Note(title: "Meeting Notes", noteType: .text, textContent: "Discussed project roadmap..."),
            Note(title: "Lecture Recording", noteType: .audio),
            Note(title: "Whiteboard Sketch", noteType: .image)
        ]
        sampleNotes.forEach { container.mainContext.insert($0) }

        return ContentView()
            .modelContainer(container)
            .environmentObject(AIServiceWrapper(service: MockAIService()))
    }

    return previewContent()
}
