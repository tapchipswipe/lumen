import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
    let timestamp: Date
    let copilotResponse: CopilotResponse?

    init(isUser: Bool, text: String, copilotResponse: CopilotResponse? = nil) {
        self.isUser = isUser
        self.text = text
        self.timestamp = Date()
        self.copilotResponse = copilotResponse
    }
}

struct SpotlightPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState = AppState.shared
    @State private var query: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var searchResults: [SearchResultCategory: [SearchResultItem]] = [:]
    @State private var isSearchingLifelog: Bool = false
    @FocusState private var isInputFocused: Bool

    init() {}

    private let suggestedPrompts = [
        "🤖 How is my AI usage?",
        "⚡ How many Cursor requests left?",
        "🔋 What is my battery runway?",
        "⏳ What did I build today?",
        "🧹 Run Master Turbo Sweep",
        "🎵 What music helped me focus?",
        "💰 What is my monthly spend?"
    ]

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider().opacity(0.2)

            // Main Conversation / Search Area
            if messages.isEmpty && query.isEmpty {
                emptyWelcomeView
            } else if !query.isEmpty && isSearchingLifelog {
                searchResultsListView
            } else {
                chatThreadView
            }

            Divider().opacity(0.2)

            // Input Bar & Action Chips
            inputBar
        }
        .frame(width: 640, height: 520)
        .background(Color(hex: "#12131A"))
        .preferredColorScheme(.dark)
        .onAppear {
            isInputFocused = true
            if messages.isEmpty {
                // Initial welcome message from Lumen
                messages.append(
                    ChatMessage(
                        isUser: false,
                        text: "Hey! I'm Lumen Copilot. Ask me anything about your AI usage across Cursor and Antigravity, battery runway, Git commits, focus pacing, or system storage.",
                        copilotResponse: nil
                    )
                )
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")], startPoint: .top, endPoint: .bottom))
                Text("Lumen Copilot ⌘K")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    isSearchingLifelog.toggle()
                    if isSearchingLifelog && !query.isEmpty {
                        performSearch(query)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isSearchingLifelog ? "message.fill" : "magnifyingglass")
                            .font(.system(size: 10))
                        Text(isSearchingLifelog ? "Chat Mode" : "Search Lifelog")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3.5)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)

                if !messages.isEmpty {
                    Button {
                        messages.removeAll()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }

                Button { dismiss() } label: {
                    Text("ESC")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#181922"))
    }

    // MARK: - Empty Welcome View

    private var emptyWelcomeView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: "#FBBF24").opacity(0.12))
                    .frame(width: 60, height: 60)
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")], startPoint: .top, endPoint: .bottom))
            }

            VStack(spacing: 4) {
                Text("Lumen Neural Copilot")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text("Chat about your work, AI accounts, battery runway, and cognitive focus.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Quick Prompt Chips
            VStack(spacing: 8) {
                Text("SUGGESTED PROMPTS")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(suggestedPrompts, id: \.self) { prompt in
                        Button {
                            submitQuery(prompt.replacingOccurrences(of: "🤖 ", with: "").replacingOccurrences(of: "⚡ ", with: "").replacingOccurrences(of: "🔋 ", with: "").replacingOccurrences(of: "⏳ ", with: "").replacingOccurrences(of: "🧹 ", with: "").replacingOccurrences(of: "🎵 ", with: "").replacingOccurrences(of: "💰 ", with: ""))
                        } label: {
                            HStack {
                                Text(prompt)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color(hex: "#FBBF24").opacity(0.7))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Chat Thread View

    private var chatThreadView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(messages) { msg in
                        if msg.isUser {
                            userBubble(msg.text)
                                .id(msg.id)
                        } else {
                            copilotBubble(msg)
                                .id(msg.id)
                        }
                    }
                }
                .padding(16)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "#3B82F6").opacity(0.85))
                )
        }
    }

    private func copilotBubble(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")], startPoint: .top, endPoint: .bottom))
                    .frame(width: 24, height: 24)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                if let copilot = msg.copilotResponse {
                    // Card Title Header
                    HStack(spacing: 6) {
                        Text(copilot.title.uppercased())
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(Color(hex: "#FBBF24"))
                            .tracking(1)
                        Spacer()
                    }

                    // Main Answer text
                    Text(copilot.answer)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    // Bullet Points
                    if !copilot.bulletPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(copilot.bulletPoints, id: \.self) { pt in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•").foregroundStyle(Color(hex: "#FBBF24"))
                                    Text(pt)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                    }

                    // Interactive Action Button
                    if let pill = copilot.actionPill {
                        HStack {
                            Spacer()
                            Button {
                                handleActionPill(pill)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(pill).font(.system(size: 10, weight: .bold))
                                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 10))
                                }
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(Capsule().fill(Color(hex: "#FBBF24").opacity(0.2)))
                                .foregroundStyle(Color(hex: "#FBBF24"))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Text(msg.text)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#1A1B24").opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            Spacer()
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 6) {
            // Quick suggestions strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(suggestedPrompts.prefix(4), id: \.self) { p in
                        Button {
                            submitQuery(p.replacingOccurrences(of: "🤖 ", with: "").replacingOccurrences(of: "⚡ ", with: "").replacingOccurrences(of: "🔋 ", with: "").replacingOccurrences(of: "⏳ ", with: "").replacingOccurrences(of: "🧹 ", with: "").replacingOccurrences(of: "🎵 ", with: "").replacingOccurrences(of: "💰 ", with: ""))
                        } label: {
                            Text(p)
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Capsule().fill(Color.white.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.top, 4)

            // Textfield & Submit
            HStack(spacing: 10) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#FBBF24"))

                TextField("Ask Lumen Copilot anything (e.g. Cursor requests, battery runway, what did I build)…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        if !query.isEmpty {
                            submitQuery(query)
                        }
                    }

                if !query.isEmpty {
                    Button {
                        submitQuery(query)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: "#FBBF24"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(hex: "#181922"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Search Results View

    private var searchResultsListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(SearchResultCategory.allCases) { cat in
                    if let items = searchResults[cat], !items.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(cat.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.4))
                                Spacer()
                                Text("\(items.count)")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.white.opacity(0.3))
                            }

                            ForEach(items) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color(hex: item.colorHex))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                                        Text(item.subtitle).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: - Actions

    private func submitQuery(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        // Append User Message
        messages.append(ChatMessage(isUser: true, text: q))
        query = ""

        // Process Response
        let response = LumenCopilotEngine.ask(
            query: q,
            stats: appState.stats,
            spendMonth: appState.spendMonth,
            taxReport: appState.taxReport2026,
            forecast: appState.financialForecast,
            storage: appState.storageSnapshot,
            power: appState.powerSnapshot,
            renewals: appState.predictedRenewals,
            audioReport: appState.audioFlowReport,
            gitCommits: appState.gitCommits,
            aiFleet: appState.aiFleetSummary
        )

        // Append Copilot Response
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.messages.append(ChatMessage(isUser: false, text: response.answer, copilotResponse: response))
        }
    }

    private func performSearch(_ text: String) {
        searchResults = LifelogSearchEngine.search(query: text)
    }

    private func handleActionPill(_ pill: String) {
        if pill == "Optimize in Cloud" || pill == "Run Master Turbo Sweep" {
            appState.runMasterTurboSweep()
        } else if pill == "View AI Fleet" {
            appState.refreshAIFleet()
            dismiss()
        } else if pill == "Open Standup" {
            appState.showStandupModal = true
            dismiss()
        } else if pill == "Export Schedule-C CSV" {
            appState.exportScheduleCTaxCSV()
        }
    }
}
