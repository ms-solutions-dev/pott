import Foundation
import PottCore

/// Short-time work allowance (Kurzarbeitergeld, §§ 105, 106 SGB III).
///
/// The allowance is 60 % (67 % with a child) of the difference between the flat-rate net pay of
/// the usual and of the actual gross. Flat-rate net pay is the gross rounded to 20 €, minus 20 %
/// for social insurance, minus wage tax and solidarity surcharge as the Federal Employment Agency's
/// table computes them (additional health contribution 2.9 %, no childless surcharge, no church
/// tax, no child allowances). The tests check every value of the official 2026 table.
extension GermanPayCalculator {
    /// The "rechnerischer Leistungssatz" of the table for one gross.
    static func shortTimeRate(gross: Money, taxClass: Int, withChild: Bool, factor: Decimal? = nil) -> Money {
        let p = Parameters.year2026
        let capped = min(max(gross, .zero), p.pensionCeiling)
        // Rounded to the nearest amount divisible by 20 (10.00 … 29.99 → 20).
        let rounded = (capped.cents + 1000) / 2000 * 20
        guard rounded > 0 else { return .zero }
        var tax = Lohnsteuer2026()
        tax.LZZ = 2
        tax.STKL = min(max(taxClass, 1), 6)
        tax.RE4 = BigDecimal.valueOf(Int(rounded * 100))
        tax.KVZ = BigDecimal(literal: "2.9")
        tax.PVZ = 0
        if tax.STKL == 4, let factor, factor > 0, factor < 1 {
            tax.af = 1
            tax.f = NSDecimalNumber(decimal: factor).doubleValue
        }
        tax.main()
        let net =
            Decimal(rounded) * Decimal(string: "0.8")! - Decimal(tax.LSTLZZ.longValue()) / 100
            - Decimal(tax.SOLZLZZ.longValue()) / 100
        let rate = withChild ? Decimal(string: "0.67")! : Decimal(string: "0.60")!
        return Money(net * rate)
    }

    /// The allowance for a month with `actual` instead of `planned` gross.
    func shortTimeAllowance(planned: Money, actual: Money, _ input: PayInput) -> Money {
        let withChild = input.childAllowances >= Decimal(string: "0.5")!
        let factor = input.taxFactor
        let usual = Self.shortTimeRate(
            gross: planned, taxClass: input.taxClass, withChild: withChild, factor: factor)
        let now = Self.shortTimeRate(
            gross: actual, taxClass: input.taxClass, withChild: withChild, factor: factor)
        return max(.zero, usual - now)
    }
}
