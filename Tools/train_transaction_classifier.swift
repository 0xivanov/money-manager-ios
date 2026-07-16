import CreateML
import Foundation

struct TrainingRow: Codable {
    let text: String
    let label: String
}

let expenseSeeds: [String: [String]] = [
    "groceries": [
        "lidl", "kaufland", "billa", "fantastico", "t market", "supermarket", "grocery store",
        "neighborhood market", "fresh produce", "food shop"
    ],
    "dining_out": [
        "restaurant", "coffee shop", "cafe", "bakery", "glovo", "wolt", "mcdonalds", "kfc",
        "happy bar and grill", "takeaway dinner"
    ],
    "going_out": [
        "shisha", "hookah lounge", "nightclub", "night club", "cocktail lounge",
        "club entry", "club ticket", "evening drinks"
    ],
    "transport": [
        "uber", "bolt ride", "taxi", "sofia metro", "bus ticket", "train ticket", "bdz railway",
        "parking", "shell fuel", "omv petrol", "eko gas station", "public transport pass"
    ],
    "housing": [
        "monthly rent", "rent payment", "landlord", "mortgage payment", "property management",
        "home maintenance", "apartment service charge"
    ],
    "utilities": [
        "electricity bill", "water bill", "heating bill", "internet bill", "broadband",
        "mobile phone bill", "vivacom", "yettel", "a1 bulgaria", "toplofikacia", "electrohold"
    ],
    "health": [
        "pharmacy", "apteka", "sopharmacy", "hospital", "medical clinic", "doctor appointment",
        "dentist", "dental care", "laboratory test"
    ],
    "entertainment": [
        "netflix", "spotify", "cinema", "movie theatre", "concert ticket", "steam games",
        "playstation", "xbox", "youtube premium", "hbo max", "disney plus"
    ],
    "travel": [
        "airbnb", "booking com", "hotel", "hostel", "ryanair", "wizz air", "easyjet",
        "flight ticket", "travel agency", "airport transfer"
    ],
    "education": [
        "university tuition", "school fee", "online course", "udemy", "coursera", "textbook",
        "language lessons", "training academy"
    ],
    "beauty": [
        "barber", "barbershop", "hair salon", "hairdresser", "haircut", "beauty salon",
        "nail salon", "nails", "manicure", "pedicure", "cosmetics", "makeup store",
        "skin care", "skincare studio", "eyebrow studio", "brow studio", "lash studio",
        "waxing salon", "sephora", "douglas parfumerie"
    ],
    "shopping": [
        "amazon", "ebay", "etsy", "shopping mall", "zara", "ikea", "dm drogerie", "emag",
        "technopolis", "technomarket", "decathlon", "clothing store", "electronics store"
    ],
    "other": [
        "bank transfer", "cash withdrawal", "atm cash", "bank service fee", "unknown merchant",
        "card verification", "money sent to friend", "cash deposit", "account adjustment",
        "government payment", "insurance payment"
    ]
]

let incomeSeeds: [String: [String]] = [
    "salary": [
        "monthly salary", "salary payment", "payroll", "monthly wage", "wages from employer",
        "employment income", "company payroll transfer"
    ],
    "freelance": [
        "freelance payment", "contractor payment", "client invoice", "consulting fee",
        "project payment", "self employed income"
    ],
    "gift": [
        "birthday gift", "gift from family", "present money", "wedding gift", "family support"
    ],
    "investment": [
        "dividend", "interest payment", "investment return", "bond coupon", "broker distribution"
    ],
    "refund": [
        "refund", "purchase reversal", "cashback", "chargeback", "reimbursement", "merchant refund"
    ],
    "other": [
        "incoming bank transfer", "cash deposit", "account correction", "money received",
        "internal transfer", "unknown incoming payment"
    ]
]

func rows(type: String, seeds: [String: [String]]) -> [TrainingRow] {
    let templates: [(String, String) -> String] = [
        { type, seed in "\(type) \(seed)" },
        { type, seed in "\(type) card payment to \(seed)" },
        { type, seed in "\(type) transaction \(seed)" },
        { type, seed in "\(type) revolut \(seed)" }
    ]
    return seeds.flatMap { label, values in
        values.flatMap { seed in
            templates.map { TrainingRow(text: $0(type, seed), label: label) }
        }
    }
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "MoneyManager/Resources/TransactionCategoryClassifier.mlmodel")
let temporaryURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("money-manager-transaction-classifier-\(UUID().uuidString).json")
let trainingRows = rows(type: "expense", seeds: expenseSeeds) + rows(type: "income", seeds: incomeSeeds)
let encoder = JSONEncoder()
try encoder.encode(trainingRows).write(to: temporaryURL, options: .atomic)
defer { try? FileManager.default.removeItem(at: temporaryURL) }

let table = try MLDataTable(contentsOf: temporaryURL)
let classifier = try MLTextClassifier(
    trainingData: table,
    textColumn: "text",
    labelColumn: "label"
)
try classifier.write(
    to: outputURL,
    metadata: MLModelMetadata(
        author: "Money Manager",
        shortDescription: "On-device Revolut transaction category classifier",
        version: "1.0"
    )
)
print("Wrote \(outputURL.path) with \(trainingRows.count) training examples")
