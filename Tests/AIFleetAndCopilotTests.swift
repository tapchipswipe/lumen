import Foundation

enum AIFleetAndCopilotTests {
    static func run() {
        testAIFleetCollector()
        testAIFleetModels()
        testCopilotAIQueries()
        testCopilotConversationalQueries()
    }

    private static func testAIFleetCollector() {
        let fleet = AIFleetTelemetryCollector.scanFleet()
        expect(fleet.totalAccounts >= 1, "AI Fleet collector discovers real AI services (e.g. Antigravity)")
        expect(fleet.isAllStudentOrFree, "AI Fleet is marked as 100% Free / Student Access")
        expect(fleet.totalMonthlySpendUSD == 0.0, "AI Fleet calculates monthly subscription spend as $0.00 for student plan")
        expect(fleet.activeModelsCount > 0, "AI Fleet identifies active AI models")
    }

    private static func testAIFleetModels() {
        let agy = AIAccountQuota(
            id: "test_agy",
            service: .antigravity,
            accountIdentifier: "test@google.com",
            planTier: "Antigravity Ultra",
            isStudentOrFree: true,
            monthlyCostUSD: 0.0,
            renewalDateFormatted: "Free Student Tier",
            usedUnits: 500_000,
            totalUnits: 1_000_000,
            unitLabel: "tokens",
            activeModels: ["gemini-3.7-flash"],
            status: .healthy,
            dailyPromptCount: 25,
            lastActiveRelative: "Now",
            summaryNarrative: "Active test"
        )
        expect(agy.usagePercentage == 0.5, "AIAccountQuota computes usage percentage correctly (50%)")
        expect(agy.remainingUnits == 500_000, "AIAccountQuota computes remaining units correctly")
        expect(agy.formattedUsed == "500.0k", "AIAccountQuota formats token counts correctly")
    }

    private static func testCopilotAIQueries() {
        let response = LumenCopilotEngine.ask(
            query: "how is my ai usage and antigravity tokens?",
            stats: .empty,
            spendMonth: .empty,
            taxReport: .empty,
            forecast: .empty
        )
        expect(response.title.contains("AI"), "LumenCopilotEngine routes AI queries to AI Accounts & Student Usage")
        expect(response.answer.contains("student"), "LumenCopilotEngine answer mentions student memberships")
    }

    private static func testCopilotConversationalQueries() {
        let greetingResponse = LumenCopilotEngine.ask(
            query: "Hey Lumen",
            stats: .empty,
            spendMonth: .empty,
            taxReport: .empty,
            forecast: .empty
        )
        expect(greetingResponse.title == "Lumen Assistant", "LumenCopilotEngine responds naturally to 'Hey Lumen' greeting")

        let timeResponse = LumenCopilotEngine.ask(
            query: "what time is it",
            stats: .empty,
            spendMonth: .empty,
            taxReport: .empty,
            forecast: .empty
        )
        expect(timeResponse.title.contains("Time"), "LumenCopilotEngine answers time queries")
    }
}
