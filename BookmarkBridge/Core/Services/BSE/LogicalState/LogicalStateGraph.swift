//
//  LogicalStateGraph.swift
//  BookmarkBridge
//

/// Immutable, validated collection of durable logical node states.
nonisolated struct LogicalStateGraph: Hashable, Codable, Sendable {
    let nodes: [LogicalNodeState]
    let report: LogicalStateBuildingReport

    init(
        nodes: [LogicalNodeState],
        report: LogicalStateBuildingReport
    ) throws {
        let orderedNodes = nodes.sorted { $0.logicalNodeID < $1.logicalNodeID }
        try Self.validate(orderedNodes)
        self.nodes = orderedNodes
        self.report = report
    }

    func node(for logicalNodeID: LogicalNodeID) -> LogicalNodeState? {
        nodes.first { $0.logicalNodeID == logicalNodeID }
    }

    init(from decoder: any Decoder) throws {
        let values = try Values(from: decoder)
        do {
            try self.init(nodes: values.nodes, report: values.report)
        } catch {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid logical state graph")
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        try Values(nodes: nodes, report: report).encode(to: encoder)
    }

    private static func validate(_ nodes: [LogicalNodeState]) throws {
        var index: [LogicalNodeID: LogicalNodeState] = [:]
        for node in nodes {
            guard index.updateValue(node, forKey: node.logicalNodeID) == nil else {
                throw LogicalStateBuildingError.inconsistentGraph(node.logicalNodeID)
            }
        }
        for node in nodes {
            if let parentID = node.parentID, index[parentID] == nil {
                throw LogicalStateBuildingError.missingParent(
                    logicalNodeID: node.logicalNodeID,
                    parentID: parentID
                )
            }
        }
        try validateNoCycles(index)
    }

    private static func validateNoCycles(
        _ index: [LogicalNodeID: LogicalNodeState]
    ) throws {
        enum VisitState { case visiting, visited }
        var states: [LogicalNodeID: VisitState] = [:]

        func visit(_ logicalNodeID: LogicalNodeID) throws {
            switch states[logicalNodeID] {
            case .visiting:
                throw LogicalStateBuildingError.inconsistentGraph(logicalNodeID)
            case .visited:
                return
            case nil:
                break
            }
            states[logicalNodeID] = .visiting
            if let parentID = index[logicalNodeID]?.parentID {
                try visit(parentID)
            }
            states[logicalNodeID] = .visited
        }

        for logicalNodeID in index.keys.sorted() {
            try visit(logicalNodeID)
        }
    }

    private struct Values: Codable {
        let nodes: [LogicalNodeState]
        let report: LogicalStateBuildingReport
    }
}
