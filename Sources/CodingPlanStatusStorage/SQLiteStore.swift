import Foundation
import SQLite3
import CodingPlanStatusCore

public enum SQLiteStoreError: Error, LocalizedError {
    case openDatabase(String)
    case execute(String)
    case prepare(String)
    case step(String)

    public var errorDescription: String? {
        switch self {
        case .openDatabase(let message): return message
        case .execute(let message): return message
        case .prepare(let message): return message
        case .step(let message): return message
        }
    }
}

public actor SQLiteStore: SnapshotStore, AlertEventStore {
    private var db: OpaquePointer?
    private let path: String

    public init(path: String? = nil) throws {
        let fileManager = FileManager.default
        if let path {
            self.path = path
        } else {
            let baseDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let appDir = baseDir.appending(path: "coding-plan-status", directoryHint: .isDirectory)
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
            self.path = appDir.appending(path: "usage.sqlite").path
        }

        if sqlite3_open(self.path, &db) != SQLITE_OK {
            throw SQLiteStoreError.openDatabase("Unable to open database at \(self.path)")
        }

        try Self.createTablesIfNeeded(db: db)
    }

    public func save(statuses: [PlanStatus], rawPayloadByPlanID: [String: Data]) async throws {
        for status in statuses {
            let sql = """
            INSERT INTO plan_snapshots (
                provider, account_id, plan_id, plan_name, used_percent, remaining,
                remaining_unit, reset_at, fetched_at, severity, raw_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            let payload = rawPayloadByPlanID[status.planId].flatMap { String(data: $0, encoding: .utf8) } ?? ""
            try execute(sql: sql, bindings: [
                status.provider.rawValue,
                status.accountId,
                status.planId,
                status.planName ?? "",
                status.usedPercent,
                NSDecimalNumber(decimal: status.remaining).stringValue,
                status.remainingUnit,
                status.resetAt?.timeIntervalSince1970 ?? NSNull(),
                status.fetchedAt.timeIntervalSince1970,
                status.severity.rawValue,
                payload
            ])
        }
    }

    public func latestStatuses() async throws -> [PlanStatus] {
        let sql = """
        SELECT s.provider, s.account_id, s.plan_id, s.plan_name, s.used_percent, s.remaining,
               s.remaining_unit, s.reset_at, s.fetched_at, s.severity
        FROM plan_snapshots s
        INNER JOIN (
            SELECT provider, account_id, plan_id, MAX(fetched_at) AS max_fetched
            FROM plan_snapshots
            GROUP BY provider, account_id, plan_id
        ) latest
        ON s.provider = latest.provider
        AND s.account_id = latest.account_id
        AND s.plan_id = latest.plan_id
        AND s.fetched_at = latest.max_fetched;
        """

        let rows = try query(sql: sql)
        return rows.compactMap { row in
            guard
                let providerRaw = row[0] as? String,
                let provider = ProviderID(rawValue: providerRaw),
                let accountId = row[1] as? String,
                let planId = row[2] as? String,
                let planName = row[3] as? String,
                let usedPercent = row[4] as? Double,
                let remainingStr = row[5] as? String,
                let remaining = Decimal(string: remainingStr),
                let remainingUnit = row[6] as? String,
                let fetchedAtTs = row[8] as? Double,
                let severityRaw = row[9] as? Int,
                let severity = StatusSeverity(rawValue: severityRaw)
            else {
                return nil
            }

            let resetAt = (row[7] as? Double).map { Date(timeIntervalSince1970: $0) }
            return PlanStatus(
                provider: provider,
                accountId: accountId,
                planId: planId,
                planName: planName.isEmpty ? nil : planName,
                usedPercent: usedPercent,
                remaining: remaining,
                remainingUnit: remainingUnit,
                resetAt: resetAt,
                fetchedAt: Date(timeIntervalSince1970: fetchedAtTs),
                severity: severity
            )
        }
    }

    public func saveDailyEOD(statuses: [PlanStatus], day: Date) async throws {
        let dayString = dayKey(for: day)
        for status in statuses {
            let sql = """
            INSERT INTO daily_plan_metrics (day, provider, account_id, plan_id, eod_used_percent, eod_remaining, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(day, provider, account_id, plan_id)
            DO UPDATE SET
                eod_used_percent = excluded.eod_used_percent,
                eod_remaining = excluded.eod_remaining,
                updated_at = excluded.updated_at;
            """
            try execute(sql: sql, bindings: [
                dayString,
                status.provider.rawValue,
                status.accountId,
                status.planId,
                status.usedPercent,
                NSDecimalNumber(decimal: status.remaining).stringValue,
                Date().timeIntervalSince1970
            ])
        }
    }

    public func prune(olderThan cutoff: Date) async throws {
        let snapshotCutoff = cutoff.timeIntervalSince1970
        try execute(sql: "DELETE FROM plan_snapshots WHERE fetched_at < ?;", bindings: [snapshotCutoff])
        try execute(sql: "DELETE FROM daily_plan_metrics WHERE day < ?;", bindings: [dayKey(for: cutoff)])
        try execute(sql: "DELETE FROM alert_events WHERE triggered_at < ?;", bindings: [snapshotCutoff])
    }

    public func latestEvent(for dedupeKey: String) async throws -> AlertEvent? {
        let sql = """
        SELECT dedupe_key, threshold, triggered_at, cleared_at
        FROM alert_events
        WHERE dedupe_key = ?
        ORDER BY triggered_at DESC
        LIMIT 1;
        """
        let rows = try query(sql: sql, bindings: [dedupeKey])
        guard let row = rows.first,
              let key = row[0] as? String,
              let threshold = row[1] as? Int,
              let triggeredTs = row[2] as? Double
        else {
            return nil
        }
        let clearedTs = row[3] as? Double
        return AlertEvent(
            dedupeKey: key,
            threshold: threshold,
            triggeredAt: Date(timeIntervalSince1970: triggeredTs),
            clearedAt: clearedTs.map { Date(timeIntervalSince1970: $0) }
        )
    }

    public func upsert(event: AlertEvent) async throws {
        let sql = """
        INSERT INTO alert_events (dedupe_key, threshold, triggered_at, cleared_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(dedupe_key)
        DO UPDATE SET threshold = excluded.threshold, triggered_at = excluded.triggered_at, cleared_at = excluded.cleared_at;
        """
        try execute(sql: sql, bindings: [
            event.dedupeKey,
            event.threshold,
            event.triggeredAt.timeIntervalSince1970,
            event.clearedAt?.timeIntervalSince1970 ?? NSNull()
        ])
    }

    private static func createTablesIfNeeded(db: OpaquePointer?) throws {
        try execute(db: db, sql: """
        CREATE TABLE IF NOT EXISTS plan_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            provider TEXT NOT NULL,
            account_id TEXT NOT NULL,
            plan_id TEXT NOT NULL,
            plan_name TEXT,
            used_percent REAL NOT NULL,
            remaining TEXT NOT NULL,
            remaining_unit TEXT NOT NULL,
            reset_at REAL,
            fetched_at REAL NOT NULL,
            severity INTEGER NOT NULL,
            raw_json TEXT NOT NULL
        );
        """)

        try execute(db: db, sql: """
        CREATE TABLE IF NOT EXISTS daily_plan_metrics (
            day TEXT NOT NULL,
            provider TEXT NOT NULL,
            account_id TEXT NOT NULL,
            plan_id TEXT NOT NULL,
            eod_used_percent REAL NOT NULL,
            eod_remaining TEXT NOT NULL,
            updated_at REAL NOT NULL,
            PRIMARY KEY (day, provider, account_id, plan_id)
        );
        """)

        try execute(db: db, sql: """
        CREATE TABLE IF NOT EXISTS alert_events (
            dedupe_key TEXT PRIMARY KEY,
            threshold INTEGER NOT NULL,
            triggered_at REAL NOT NULL,
            cleared_at REAL
        );
        """)

        try execute(db: db, sql: "CREATE INDEX IF NOT EXISTS idx_snapshots_lookup ON plan_snapshots(provider, account_id, plan_id, fetched_at DESC);")
        try execute(db: db, sql: "CREATE INDEX IF NOT EXISTS idx_alert_lookup ON alert_events(dedupe_key, triggered_at DESC);")
    }

    private static func execute(db: OpaquePointer?, sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw SQLiteStoreError.execute("SQLite exec failed")
        }
    }

    private func execute(sql: String, bindings: [Any] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(errorMessage)
        }
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.step(errorMessage)
        }
    }

    private func query(sql: String, bindings: [Any] = []) throws -> [[Any?]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(errorMessage)
        }
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        var rows: [[Any?]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let columnCount = sqlite3_column_count(statement)
            var row: [Any?] = []
            row.reserveCapacity(Int(columnCount))
            for index in 0..<columnCount {
                let type = sqlite3_column_type(statement, index)
                switch type {
                case SQLITE_INTEGER:
                    row.append(Int(sqlite3_column_int64(statement, index)))
                case SQLITE_FLOAT:
                    row.append(Double(sqlite3_column_double(statement, index)))
                case SQLITE_TEXT:
                    let cString = sqlite3_column_text(statement, index)
                    row.append(cString.map { String(cString: $0) })
                case SQLITE_NULL:
                    row.append(nil)
                default:
                    row.append(nil)
                }
            }
            rows.append(row)
        }

        return rows
    }

    private func bind(_ bindings: [Any], to statement: OpaquePointer?) throws {
        for (offset, value) in bindings.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case let string as String:
                let nsString = string as NSString
                sqlite3_bind_text(statement, index, nsString.utf8String, -1, SQLITE_TRANSIENT)
            case let int as Int:
                sqlite3_bind_int64(statement, index, sqlite3_int64(int))
            case let double as Double:
                sqlite3_bind_double(statement, index, double)
            case let float as Float:
                sqlite3_bind_double(statement, index, Double(float))
            case _ as NSNull:
                sqlite3_bind_null(statement, index)
            default:
                let text = "\(value)" as NSString
                sqlite3_bind_text(statement, index, text.utf8String, -1, SQLITE_TRANSIENT)
            }
        }
    }

    private var errorMessage: String {
        guard let db else { return "Unknown SQLite error" }
        return String(cString: sqlite3_errmsg(db))
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
