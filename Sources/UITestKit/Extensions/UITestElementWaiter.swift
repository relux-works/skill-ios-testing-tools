import XCTest

public enum UITestElementWaitStrategy {
    case first
    case all
}

public enum UITestElementWaitReadiness {
    case exists
    case hittable
    case interactable

    @MainActor
    public func matches(_ element: XCUIElement) -> Bool {
        switch self {
        case .exists:
            element.exists
        case .hittable:
            element.exists && element.isHittable
        case .interactable:
            element.exists && element.isHittable && element.isEnabled && !element.frame.isEmpty
        }
    }
}

public struct UITestElementWaitCandidate {
    public let selector: String
    private let elementsProvider: @MainActor () -> [XCUIElement]

    @MainActor
    public init(
        selector: String,
        elements: @escaping @MainActor () -> [XCUIElement]
    ) {
        self.selector = selector
        self.elementsProvider = elements
    }

    @MainActor
    public init(
        selector: String,
        element: XCUIElement
    ) {
        self.init(selector: selector) {
            [element]
        }
    }

    @MainActor
    public init(
        name: String,
        elements: @escaping @MainActor () -> [XCUIElement]
    ) {
        self.init(selector: name, elements: elements)
    }

    @MainActor
    public init(
        name: String,
        element: XCUIElement
    ) {
        self.init(selector: name, element: element)
    }

    @MainActor
    func firstMatch(readiness: UITestElementWaitReadiness) -> UITestElementWaitMatch? {
        elementsProvider()
            .first(where: readiness.matches)
            .map { (selector: selector, element: $0) }
    }
}

public typealias UITestElementWaitMatch = (selector: String, element: XCUIElement)

public struct UITestElementWaitResult {
    public let strategy: UITestElementWaitStrategy
    public let matches: [UITestElementWaitMatch]

    public var first: UITestElementWaitMatch? {
        matches.first
    }

    public var matchedNames: [String] {
        matchedSelectors
    }

    public var matchedSelectors: [String] {
        matches.map(\.selector)
    }
}

public enum UITestElementWaiter {
    @MainActor
    public static func waitForElements(
        _ candidates: [UITestElementWaitCandidate],
        strategy: UITestElementWaitStrategy = .first,
        readiness: UITestElementWaitReadiness = .exists,
        timeout: TimeInterval,
        pollingInterval: TimeInterval = 0.25
    ) -> UITestElementWaitResult? {
        guard !candidates.isEmpty else {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let result = result(
                candidates: candidates,
                strategy: strategy,
                readiness: readiness
            ) {
                return result
            }

            RunLoop.current.run(until: Date().addingTimeInterval(pollingInterval))
        }

        return result(
            candidates: candidates,
            strategy: strategy,
            readiness: readiness
        )
    }

    @MainActor
    private static func result(
        candidates: [UITestElementWaitCandidate],
        strategy: UITestElementWaitStrategy,
        readiness: UITestElementWaitReadiness
    ) -> UITestElementWaitResult? {
        switch strategy {
        case .first:
            guard let match = candidates.lazy.compactMap({ $0.firstMatch(readiness: readiness) }).first else {
                return nil
            }

            return UITestElementWaitResult(strategy: strategy, matches: [match])
        case .all:
            let matches = candidates.compactMap { $0.firstMatch(readiness: readiness) }
            guard matches.count == candidates.count else {
                return nil
            }

            return UITestElementWaitResult(strategy: strategy, matches: matches)
        }
    }
}
