import Foundation

enum CurrencyFormatter {
    static func string(from amount: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        let number = NSDecimalNumber(decimal: amount)
        return formatter.string(from: number) ?? "\(amount) \(currencyCode)"
    }
}
