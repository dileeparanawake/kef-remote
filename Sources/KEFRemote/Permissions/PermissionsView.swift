import KEFRemoteCore
import SwiftUI

/// The permissions guide: a row per permission KEF Remote needs.
///
/// ```
/// KEF Remote needs two permissions
/// ✗ Accessibility                          [Open Settings]
///   So the volume keys reach the speaker.
///   Not allowed yet
///   Privacy & Security > Accessibility
/// ? Local Network                          [Open Settings]
///   So the app can find the speaker.
///   Not checked yet: shows once the speaker answers
///   In Privacy & Security, click Local Network, then turn on KEF Remote
/// ```
///
/// The Accessibility hint names the row as this Mac's System Settings
/// does: Device Control and Data Access from macOS 27.
///
/// It only shows ``PermissionsModel/rows``; what each row says is
/// decided in ``PermissionRow``.
struct PermissionsView: View {
    @ObservedObject var model: PermissionsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("KEF Remote needs two permissions")
                .font(.headline)

            ForEach(model.rows, id: \.permission) { row in
                PermissionRowView(row: row) { model.openSettings(for: row.permission) }
            }

            Text("Open this again any time: menu bar icon > Permissions…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PermissionRowView: View {
    let row: PermissionRow
    let openSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.statusSymbol)
                .font(.title2)
                .foregroundStyle(statusColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).bold()
                Text(row.purpose)
                Text(row.statusText)
                    .font(.caption)
                    .foregroundStyle(row.needsAttention ? .red : .secondary)
                Text(row.settingsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Open Settings", action: openSettings)
        }
        .accessibilityElement(children: .combine)
    }

    /// Green tick, red cross, grey question mark: the shape says it too.
    private var statusColor: Color {
        switch row.status {
        case .granted: return .green
        case .notGranted: return .red
        case .notCheckedYet: return .secondary
        }
    }
}
