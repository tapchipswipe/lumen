import Foundation

var failures = 0
var checks = 0
func expect(_ cond: Bool, _ msg: String) {
    checks += 1
    if !cond { failures += 1; print("FAIL: \(msg)") }
}

AggregatorTests.run()
CryptoTests.run()
CategoryTests.run()
UpdateTests.run()
ReceiptParserTests.run()
ReceiptCategorizerTests.run()
SpendAggregatorTests.run()
SpendExportTests.run()
CardPortfolioTests.run()
SubscriptionRadarTests.run()
SpendingPacingTests.run()
DayStoryTests.run()
LifelogSearchTests.run()
ZombieDetectorTests.run()
ScheduleCTaxTests.run()
WorkspaceClusterTests.run()
MorningBriefingTests.run()
DeepTelemetryTests.run()
FrontierCore4Tests.run()
AIFleetAndCopilotTests.run()
runNextGenIntegrationTests()

print("\(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
