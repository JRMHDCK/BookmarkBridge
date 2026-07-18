//
//  SynchronizationExecutor.swift
//  BookmarkBridge
//

/// Sequential orchestration boundary between an immutable plan and one write
/// adapter. It performs no retry, rollback, persistence, or operation rewrite.
nonisolated struct SynchronizationExecutor: Sendable {
    func execute(
        request: SynchronizationExecutionRequest
    ) async -> SynchronizationExecutionResult {
        var phaseResults: [SynchronizationPhaseExecutionResult] = []
        var mustStop = false
        var wasCancelled = false

        for phase in request.plan.phases {
            guard !mustStop, !wasCancelled else { break }

            let result = await execute(
                phase: phase,
                adapter: request.adapter,
                context: request.context,
                policy: request.policy
            )
            phaseResults.append(result)

            switch result.status {
            case .completed, .completedWithFailures:
                break
            case .stoppedOnFailure:
                mustStop = true
            case .cancelled:
                wasCancelled = true
            }
        }

        if Task.isCancelled, !mustStop {
            wasCancelled = true
        }

        return makeResult(
            plan: request.plan,
            phaseResults: phaseResults,
            stoppedOnFailure: mustStop,
            cancelled: wasCancelled
        )
    }

    private func execute(
        phase: SynchronizationPhase,
        adapter: any BookmarkWriteAdapter,
        context: WriteExecutionContext,
        policy: SynchronizationExecutionPolicy
    ) async -> SynchronizationPhaseExecutionResult {
        let descriptor = describe(phase)
        var operationResults: [SynchronizationOperationExecutionResult] = []
        var hasFailure = false

        for operation in descriptor.operations {
            if Task.isCancelled {
                return SynchronizationPhaseExecutionResult(
                    phase: descriptor.phase,
                    status: .cancelled,
                    operationResults: operationResults
                )
            }

            if let missingCapability = missingCapability(
                for: operation,
                capabilities: adapter.capabilities,
                context: context
            ) {
                operationResults.append(SynchronizationOperationExecutionResult(
                    operation: operation,
                    status: .refused,
                    adapterResult: nil,
                    error: .unsupportedCapability(missingCapability)
                ))
                hasFailure = true

                if policy == .stopOnFirstFailure {
                    return SynchronizationPhaseExecutionResult(
                        phase: descriptor.phase,
                        status: .stoppedOnFailure,
                        operationResults: operationResults
                    )
                }
                continue
            }

            do {
                let adapterResult = try await adapter.execute(
                    operation: operation,
                    context: context
                )
                operationResults.append(SynchronizationOperationExecutionResult(
                    operation: operation,
                    status: executionStatus(for: adapterResult.status),
                    adapterResult: adapterResult,
                    error: nil
                ))
            } catch is CancellationError {
                operationResults.append(cancelledResult(for: operation))
                return SynchronizationPhaseExecutionResult(
                    phase: descriptor.phase,
                    status: .cancelled,
                    operationResults: operationResults
                )
            } catch let error as WriteAdapterError {
                if Task.isCancelled {
                    operationResults.append(cancelledResult(for: operation))
                    return SynchronizationPhaseExecutionResult(
                        phase: descriptor.phase,
                        status: .cancelled,
                        operationResults: operationResults
                    )
                }

                operationResults.append(failedResult(
                    for: operation,
                    error: .adapterFailure(error)
                ))
                hasFailure = true
            } catch {
                if Task.isCancelled {
                    operationResults.append(cancelledResult(for: operation))
                    return SynchronizationPhaseExecutionResult(
                        phase: descriptor.phase,
                        status: .cancelled,
                        operationResults: operationResults
                    )
                }

                operationResults.append(failedResult(
                    for: operation,
                    error: .unexpectedAdapterFailure(operation.writeOperationKind)
                ))
                hasFailure = true
            }

            if hasFailure, policy == .stopOnFirstFailure {
                return SynchronizationPhaseExecutionResult(
                    phase: descriptor.phase,
                    status: .stoppedOnFailure,
                    operationResults: operationResults
                )
            }
        }

        return SynchronizationPhaseExecutionResult(
            phase: descriptor.phase,
            status: hasFailure ? .completedWithFailures : .completed,
            operationResults: operationResults
        )
    }

    private func missingCapability(
        for operation: SynchronizationOperation,
        capabilities: WriteAdapterCapabilities,
        context: WriteExecutionContext
    ) -> WriteAdapterCapability? {
        guard capabilities.supports(operation.requiredWriteCapability) else {
            return operation.requiredWriteCapability
        }
        guard context.mode != .dryRun || capabilities.supports(.dryRun) else {
            return .dryRun
        }
        return nil
    }

    private func executionStatus(
        for status: WriteOperationStatus
    ) -> SynchronizationOperationExecutionStatus {
        switch status {
        case .applied: .applied
        case .alreadySatisfied: .alreadySatisfied
        case .simulated: .simulated
        }
    }

    private func cancelledResult(
        for operation: SynchronizationOperation
    ) -> SynchronizationOperationExecutionResult {
        SynchronizationOperationExecutionResult(
            operation: operation,
            status: .cancelled,
            adapterResult: nil,
            error: .cancelled
        )
    }

    private func failedResult(
        for operation: SynchronizationOperation,
        error: SynchronizationExecutionError
    ) -> SynchronizationOperationExecutionResult {
        SynchronizationOperationExecutionResult(
            operation: operation,
            status: .failed,
            adapterResult: nil,
            error: error
        )
    }

    private func describe(
        _ phase: SynchronizationPhase
    ) -> (phase: SynchronizationExecutionPhase, operations: [SynchronizationOperation]) {
        switch phase {
        case .preparation(let operations): (.preparation, operations)
        case .structural(let operations): (.structural, operations)
        case .content(let operations): (.content, operations)
        case .cleanup(let operations): (.cleanup, operations)
        }
    }

    private func makeResult(
        plan: SynchronizationPlan,
        phaseResults: [SynchronizationPhaseExecutionResult],
        stoppedOnFailure: Bool,
        cancelled: Bool
    ) -> SynchronizationExecutionResult {
        let results = phaseResults.flatMap(\.operationResults)
        let failedCount = results.count { $0.status == .failed }
        let refusedCount = results.count { $0.status == .refused }
        let hasFailure = failedCount + refusedCount > 0
        let status: SynchronizationExecutionStatus

        if cancelled {
            status = .cancelled
        } else if stoppedOnFailure {
            status = .stoppedOnFailure
        } else if hasFailure {
            status = .completedWithFailures
        } else {
            status = .completed
        }

        return SynchronizationExecutionResult(
            status: status,
            phaseResults: phaseResults,
            report: SynchronizationExecutionReport(
                plannedOperationCount: plan.operations.count,
                attemptedOperationCount: results.count { $0.status != .refused },
                refusedOperationCount: refusedCount,
                appliedOperationCount: results.count { $0.status == .applied },
                alreadySatisfiedOperationCount: results.count {
                    $0.status == .alreadySatisfied
                },
                simulatedOperationCount: results.count { $0.status == .simulated },
                failedOperationCount: failedCount,
                cancelledOperationCount: results.count { $0.status == .cancelled },
                completedPhaseCount: phaseResults.count { result in
                    result.status == .completed || result.status == .completedWithFailures
                }
            )
        )
    }
}
