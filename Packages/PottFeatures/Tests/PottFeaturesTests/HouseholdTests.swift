import Foundation
import PottCore
import PottStore
import Testing

@testable import PottFeatures

@MainActor
@Suite("Household")
struct HouseholdTests {
    func makeModel() throws -> AppModel {
        let defaults = UserDefaults(suiteName: "pott-household-\(UUID().uuidString)")!
        return AppModel(
            repository: Repository(persistence: try Persistence(mode: .inMemory)),
            settings: AppSettings(defaults: defaults))
    }

    @Test("A flat share of three splits the rent by income")
    func flatShare() throws {
        let model = try makeModel()
        model.save(IncomeSource(name: "Job", monthlyNet: Money(units: 2000)))
        model.startHousehold(myName: "Alex", partnerName: "Sam")
        model.save(Member(name: "Robin", monthlyNetIncome: Money(units: 1000)))
        let sam = try #require(model.household?.members.first { $0.name == "Sam" })
        var richer = sam
        richer.monthlyNetIncome = Money(units: 3000)
        model.save(richer)
        model.syncMyIncome()
        model.setRule(.byIncome)
        model.save(FixedCost(name: "Rent", amount: Money(units: 1200), category: .housing, scope: .household))

        let pot = try #require(model.budget.household)
        #expect(model.household?.members.count == 3)
        #expect(pot.paidIn == Money(units: 1200))
        #expect(model.budget.personal.householdContribution == Money(units: 400))  // 2,000 of 6,000
        #expect(pot.contribution(of: sam.id) == Money(units: 600))
    }

    @Test("Joining without knowing who you are asks first")
    func identity() throws {
        let model = try makeModel()
        model.startHousehold(myName: "Alex", partnerName: "Sam")
        model.settings.meMemberID = nil
        #expect(model.needsIdentity)
        #expect(!model.householdActive)
        let sam = try #require(model.household?.members.first { $0.name == "Sam" })
        model.claim(sam)
        #expect(!model.needsIdentity)
        #expect(model.householdActive)
        model.settings.meMemberID = nil
        model.joinAsNewMember(named: "Robin")
        #expect(model.household?.members.count == 3)
        #expect(model.householdActive)
    }

    @Test("Without iCloud nothing is shared")
    func noCloud() throws {
        let model = try makeModel()
        model.startHousehold(myName: "Alex", partnerName: "Sam")
        #expect(!model.isCloudEnabled)
        #expect(!model.isHouseholdShared)
    }
}
