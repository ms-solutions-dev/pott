import CoreData

/// The Core Data model, defined in code so it lives in the package and stays readable in diffs.
///
/// CloudKit rules apply: every attribute is optional or has a default, there are no unique
/// constraints, and every relationship is optional with an inverse.
enum PottModel {
    enum Entity {
        static let household = "Household"
        static let member = "Member"
        static let fixedCost = "FixedCost"
        static let income = "Income"
        static let savingsGoal = "SavingsGoal"
        static let monthSummary = "MonthSummary"
    }

    /// One shared instance: Core Data must not see two models describing the same entities.
    nonisolated(unsafe) static let shared: NSManagedObjectModel = make()

    private static func make() -> NSManagedObjectModel {
        let household = entity(
            Entity.household,
            [
                attribute("id", .uuid), attribute("name", .string, ""),
                attribute("rule", .string, "fixedAmounts"),
                attribute("createdAt", .date),
            ])
        let member = entity(
            Entity.member,
            [
                attribute("id", .uuid), attribute("name", .string, ""),
                attribute("monthlyNetIncomeCents", .integer64, 0),
                attribute("fixedContributionCents", .integer64, 0),
                attribute("shareBasisPoints", .integer64, 0), attribute("createdAt", .date),
            ])
        let cost = entity(
            Entity.fixedCost,
            [
                attribute("id", .uuid), attribute("name", .string, ""),
                attribute("amountCents", .integer64, 0),
                attribute("recurrence", .string, "monthly"), attribute("dueDay", .integer16, 1),
                attribute("category", .string, "subscriptions"), attribute("note", .string, ""),
                attribute("scope", .string, "personal"),
                attribute("isPaused", .boolean, false), attribute("createdAt", .date),
                attribute("contractEnd", .date), attribute("noticePeriodDays", .integer16),
            ])
        let income = entity(
            Entity.income,
            [
                attribute("id", .uuid), attribute("name", .string, ""),
                attribute("monthlyNetCents", .integer64, 0),
                attribute("originSummary", .string), attribute("note", .string, ""),
                attribute("createdAt", .date),
            ])
        let goal = entity(
            Entity.savingsGoal,
            [
                attribute("id", .uuid), attribute("name", .string, ""),
                attribute("targetCents", .integer64, 0),
                attribute("savedCents", .integer64, 0), attribute("months", .integer16, 12),
                attribute("scope", .string, "personal"),
                attribute("note", .string, ""), attribute("createdAt", .date),
            ])

        let month = entity(
            Entity.monthSummary,
            [
                attribute("id", .uuid), attribute("month", .string, ""),
                attribute("incomeCents", .integer64, 0),
                attribute("fixedCostsCents", .integer64, 0), attribute("savingsCents", .integer64, 0),
                attribute("contributionCents", .integer64, 0), attribute("leftCents", .integer64, 0),
                attribute("createdAt", .date),
            ])

        link(household, "members", toMany: member, "household", rule: .cascadeDeleteRule)
        link(household, "costs", toMany: cost, "household", rule: .cascadeDeleteRule)
        link(household, "goals", toMany: goal, "household", rule: .cascadeDeleteRule)

        let model = NSManagedObjectModel()
        model.entities = [household, member, cost, income, goal, month]
        return model
    }

    private static func entity(_ name: String, _ attributes: [NSAttributeDescription]) -> NSEntityDescription
    {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        entity.properties = attributes
        return entity
    }

    private static func attribute(
        _ name: String, _ type: NSAttributeDescription.AttributeType, _ defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.type = type
        attribute.isOptional = true
        attribute.defaultValue = defaultValue
        return attribute
    }

    /// Adds a to-many relationship from `parent` and its to-one inverse on `child`.
    private static func link(
        _ parent: NSEntityDescription, _ name: String, toMany child: NSEntityDescription,
        _ inverseName: String,
        rule: NSDeleteRule
    ) {
        let many = NSRelationshipDescription()
        many.name = name
        many.destinationEntity = child
        many.minCount = 0
        many.maxCount = 0
        many.isOptional = true
        many.deleteRule = rule

        let one = NSRelationshipDescription()
        one.name = inverseName
        one.destinationEntity = parent
        one.minCount = 0
        one.maxCount = 1
        one.isOptional = true
        one.deleteRule = .nullifyDeleteRule

        many.inverseRelationship = one
        one.inverseRelationship = many
        parent.properties.append(many)
        child.properties.append(one)
    }
}
