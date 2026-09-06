import Foundation

func runNextGenIntegrationTests() {
    print("--- Running Next-Gen Integration Tests ---")

    // 1. Test Receipt Auto-Reconciliation Engine
    let date = Date()
    let mailReceipt = ReceiptPayload(
        id: UUID(),
        merchant: "Sweetgreen",
        amount: 18.50,
        currency: "USD",
        cardLast4: "8031",
        category: .dining,
        transactionDate: date,
        capturedAt: date,
        source: "mail",
        mailMessageID: "msg-12345",
        confidence: 0.95,
        needsReview: false,
        notes: nil
    )

    let cameraReceipt = ReceiptPayload(
        id: UUID(),
        merchant: "Sweetgreen #102",
        amount: 18.50,
        currency: "USD",
        cardLast4: "8031",
        category: .dining,
        transactionDate: date.addingTimeInterval(3600),
        capturedAt: date.addingTimeInterval(3600),
        source: "camera",
        mailMessageID: nil,
        confidence: 0.92,
        needsReview: false,
        notes: nil
    )

    let reconciled = ReceiptReconciliationEngine.reconcile(receipts: [mailReceipt, cameraReceipt])
    assert(reconciled.count == 1, "Expected 2 duplicates to reconcile into 1 entry")
    assert(reconciled.first?.isCrossVerified == true, "Expected crossVerified to be true")
    assert(reconciled.first?.scheduleCLine.contains("Line 24b") == true, "Expected Schedule-C Line 24b")
    print("✓ Receipt Auto-Reconciliation passed.")

    // 2. Test CPA Tax Pack Generator
    let taxPack = CPATaxPackGenerator.generateTaxPack(year: 2026, receipts: [mailReceipt, cameraReceipt])
    assert(taxPack.receiptCount == 1, "Expected 1 reconciled receipt in tax pack")
    assert(taxPack.totalDeductible == 9.25, "Expected 50% deduction on dining: $9.25")
    assert(FileManager.default.fileExists(atPath: taxPack.folderURL.appendingPathComponent("ScheduleC_2026.csv").path), "Expected ScheduleC_2026.csv to exist")
    assert(FileManager.default.fileExists(atPath: taxPack.folderURL.appendingPathComponent("CPA_Audit_Summary.md").path), "Expected CPA_Audit_Summary.md to exist")
    print("✓ 1-Click CPA Tax Pack Generator passed.")

    // 3. Test Cognitive Handoff & Break Classifier
    let breakContext = CognitiveHandoffEngine.evaluateHandoff(
        lastActiveProject: "Lumen",
        lastBranch: "main",
        idleDurationSeconds: 900,
        stepCount: 450,
        isWalking: true,
        isDriving: false
    )

    assert(breakContext.classification == "Kinetic Walk & Recharge", "Expected Kinetic Walk classification")
    assert(breakContext.stepsDuringBreak == 450, "Expected 450 steps")
    assert(breakContext.resumptionPrompt.contains("450 steps"), "Expected resumption prompt with steps")
    print("✓ Cognitive Handoff & Break Classifier passed.")

    // 4. Test Predictive Focus Shield Engine
    let shield = FocusShieldEngine.shared
    shield.evaluateFocusState(liveWPM: 65.0, uncommittedDiffLines: 35)
    shield.recordInterruption(sourceApp: "Slack")
    shield.recordRecovery()
    assert(shield.lastInterruptionRecoverySeconds >= 0, "Expected valid recovery latency calculation")
    print("✓ Predictive Focus Shield Engine passed.")

    // 5. Test On-Device Neural Vector Store
    let vectorStore = LocalVectorStore.shared
    let testEvents: [TrackerEvent] = [
        TrackerEvent(
            ts: date,
            kind: .windowFocus,
            payload: .windowFocus(WindowFocusPayload(
                appName: "Xcode",
                windowTitle: "LumenApp.swift — lumen",
                start: date,
                end: date.addingTimeInterval(600),
                durationSeconds: 600
            ))
        ),
        TrackerEvent(
            ts: date,
            kind: .gitVelocity,
            payload: .gitVelocity(GitVelocityPayload(
                observedAt: date,
                repoName: "lumen",
                branch: "feature/p2p-sync",
                uncommittedDiffLines: 120,
                commitsToday: 4
            ))
        )
    ]

    vectorStore.indexLifelogEvents(testEvents)
    let searchResults = vectorStore.search(query: "Xcode Swift lumen", limit: 5)
    assert(!searchResults.isEmpty, "Expected non-empty vector search results")
    print("✓ On-Device Semantic Vector Memory passed.")
}
