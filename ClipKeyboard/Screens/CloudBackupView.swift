//
//  CloudBackupView.swift
//  ClipKeyboard
//
//  Created by Claude on 2025-11-28.
//

import SwiftUI
import UniformTypeIdentifiers

struct CloudBackupView: View {
    @StateObject private var backupService = CloudKitBackupService.shared
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showRestoreConfirmation = false
    @State private var showDeleteConfirmation = false
    // 백업이 기존 데이터를 줄일 때(빈/대폭축소) 사용자 동의를 받기 위한 상태
    @State private var showReduceConfirm = false
    @State private var reduceExisting = 0
    @State private var reduceNew = 0
    /// 현재 iCloud 백업에 들어있는 메모 개수("무엇이 백업돼 있는지" 확인용)
    @State private var backupMemoCount: Int? = nil
    @State private var showPaywall = false
    // 파일 백업(내보내기/가져오기) - CloudKit·Pro·로그인과 무관한 최후의 보루
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument: BackupFileDocument? = nil
    @State private var exportFilename = "ClipKeyboard-Backup.json"
    @Environment(\.appTheme) private var theme

    var body: some View {
        if !ProFeatureManager.isCloudBackupAvailable {
            // 무료 유저: Pro 유도
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: AppSymbol.icloudFill)
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(NSLocalizedString("iCloud 백업은 Pro 기능입니다", comment: "Cloud backup pro"))
                    .font(.title3)
                    .fontWeight(.medium)
                Text(NSLocalizedString("한번 구매로 데이터를 안전하게 백업하세요", comment: "Cloud backup pro desc"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    showPaywall = true
                } label: {
                    Text(NSLocalizedString("Pro 업그레이드", comment: "Upgrade"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(height: 50)
                        .frame(maxWidth: 240)
                        .background(.orange.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                }
                Spacer()
            }
            .navigationTitle(NSLocalizedString("백업 및 복원", comment: "Backup and restore"))
            .paywall(isPresented: $showPaywall, triggeredBy: .cloudBackup)
        } else {
        List {
            // iCloud 상태 섹션
            Section {
                HStack {
                    Image(systemName: backupService.isAuthenticated ? "checkmark.icloud.fill" : "xmark.icloud.fill")
                        .foregroundColor(backupService.isAuthenticated ? .green : .red)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("iCloud 상태", comment: "iCloud status label"))
                            .font(.headline)
                        Text(backupService.isAuthenticated ? NSLocalizedString("연결됨", comment: "Connected status") : NSLocalizedString("연결 안 됨", comment: "Disconnected status"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)

                if !backupService.isAuthenticated {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("iCloud에 로그인하세요", comment: "iCloud login prompt"))
                            .font(.body)
                            .foregroundColor(.orange)

                        Text(NSLocalizedString("설정 > [사용자 이름] > iCloud에서 로그인할 수 있습니다.", comment: "iCloud login instruction"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text(NSLocalizedString("연결 상태", comment: "Connection status section header"))
            }

            // 백업 정보 섹션
            if backupService.isAuthenticated {
                Section {
                    if let lastBackup = backupService.lastBackupDate {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("마지막 백업", comment: "Last backup label"))
                                    .font(.headline)
                                Text(lastBackup, style: .relative)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                Text(lastBackup, style: .date)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                if let count = backupMemoCount {
                                    Text(String(format: NSLocalizedString("단축어 %d개 백업됨", comment: "Backed-up memo count"), count))
                                        .font(.caption)
                                        .foregroundColor(count == 0 ? .orange : .secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: AppSymbol.checkmarkCircleFill)
                                .foregroundColor(Color.checkGreen)
                                .font(.title2)
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("백업 없음", comment: "No backup label"))
                                    .font(.headline)
                                Text(NSLocalizedString("데이터를 백업하지 않았습니다", comment: "No backup description"))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: AppSymbol.exclamationmarkCircleFill)
                                .foregroundColor(.orange)
                                .font(.title2)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(NSLocalizedString("백업 정보", comment: "Backup information section header"))
                }

                // 자동 백업 섹션
                Section {
                    Toggle(isOn: Binding(
                        get: { backupService.autoBackupEnabled },
                        set: { newValue in
                            if newValue {
                                backupService.enableAutoBackup()
                            } else {
                                backupService.disableAutoBackup()
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("자동 백업", comment: "Auto backup label"))
                                .font(.headline)
                            Text(NSLocalizedString("데이터 변경 시 자동으로 백업합니다", comment: "Auto backup description"))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(NSLocalizedString("자동 백업 설정", comment: "Auto backup settings section header"))
                } footer: {
                    Text(NSLocalizedString("• 자동 백업이 활성화되면 단축어, 클립보드, 콤보 변경 시 자동으로 백업됩니다\n• 5분마다 정기적으로 백업이 실행됩니다", comment: "Auto backup info"))
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                // 백업 작업 섹션
                Section {
                    // 백업 버튼
                    Button {
                        performBackup()
                    } label: {
                        HStack {
                            Image(systemName: AppSymbol.arrowUpDocFill)
                                .foregroundColor(.accentColor)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("백업하기", comment: "Backup button label"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("현재 데이터를 iCloud에 백업합니다", comment: "Backup button description"))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if backupService.isBackingUp {
                                ProgressView()
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(backupService.isBackingUp || backupService.isRestoring)

                    // 복구 버튼
                    Button {
                        showRestoreConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: AppSymbol.arrowDownDocFill)
                                .foregroundColor(.green)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("복구하기", comment: "Restore button label"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("iCloud에서 데이터를 복구합니다", comment: "Restore button description"))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if backupService.isRestoring {
                                ProgressView()
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(backupService.isBackingUp || backupService.isRestoring)

                    // 버전(타임머신)에서 복원 - 날짜별 스냅샷 선택
                    NavigationLink {
                        BackupVersionsView()
                    } label: {
                        HStack {
                            Image(systemName: AppSymbol.clockArrowCirclepath)
                                .foregroundColor(.green)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("이전 버전에서 복원", comment: "Restore from a previous version"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("날짜별 백업에서 골라서 복원합니다", comment: "Restore from dated snapshots description"))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(backupService.isBackingUp || backupService.isRestoring)

                    // 백업 삭제 버튼
                    if backupService.lastBackupDate != nil {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: AppSymbol.trashFill)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("백업 삭제", comment: "Delete backup button label"))
                                        .font(.headline)
                                    Text(NSLocalizedString("iCloud의 백업 데이터를 삭제합니다", comment: "Delete backup button description"))
                                        .font(.body)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .disabled(backupService.isBackingUp || backupService.isRestoring)
                    }
                } header: {
                    Text(NSLocalizedString("백업 관리", comment: "Backup management section header"))
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("• 백업은 단축어와 클립보드 히스토리를 모두 포함합니다", comment: "Backup info 1"))
                        Text(NSLocalizedString("• 복구 시 현재 데이터는 백업 데이터로 교체됩니다", comment: "Backup info 2"))
                        Text(NSLocalizedString("• 백업 데이터는 iCloud에 안전하게 저장됩니다", comment: "Backup info 3"))
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
            }

            // 파일 백업 섹션 - iCloud가 막혀도(미로그인/스키마 문제/네트워크) 데이터를
            // 기기 파일로 직접 빼낼 수 있는 최후의 보루. 메모·클립보드·콤보·이미지를
            // 자기완결형 .json 한 파일로 내보내고, 그 파일에서 되살린다.
            Section {
                Button {
                    performExportToFile()
                } label: {
                    HStack {
                        Image(systemName: AppSymbol.arrowUpDocFill)
                            .foregroundColor(.purple)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("파일로 내보내기", comment: "Export to file button label"))
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(NSLocalizedString("모든 데이터를 파일 한 개로 저장합니다 (iCloud 불필요)", comment: "Export to file description"))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Button {
                    showImporter = true
                } label: {
                    HStack {
                        Image(systemName: AppSymbol.arrowDownDocFill)
                            .foregroundColor(.purple)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("파일에서 가져오기", comment: "Import from file button label"))
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(NSLocalizedString("내보낸 파일에서 데이터를 되살립니다 (기존 데이터는 보존)", comment: "Import from file description"))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text(NSLocalizedString("파일 백업", comment: "File backup section header"))
            } footer: {
                Text(NSLocalizedString("• iCloud와 별개로, 데이터를 파일로 직접 보관하는 가장 확실한 방법입니다\n• 가져오기는 현재 데이터를 지우지 않고 합칩니다(같은 항목은 최신본 유지)", comment: "File backup info"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                alertTitle = NSLocalizedString("내보내기 완료", comment: "Export completed")
                alertMessage = NSLocalizedString("데이터를 파일로 저장했습니다. 안전한 곳에 보관하세요.", comment: "Export success message")
            case .failure(let error):
                alertTitle = NSLocalizedString("내보내기 실패", comment: "Export failed")
                alertMessage = error.localizedDescription
            }
            showAlert = true
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .navigationTitle(NSLocalizedString("iCloud 백업", comment: "iCloud backup navigation title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
        .alert(alertTitle, isPresented: $showAlert) {
            Button(NSLocalizedString("확인", comment: "OK button"), role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(NSLocalizedString("백업 데이터 복구", comment: "Restore backup dialog title"), isPresented: $showRestoreConfirmation, titleVisibility: .visible) {
            Button(NSLocalizedString("복구", comment: "Restore button"), role: .destructive) {
                performRestore()
            }
            Button(NSLocalizedString("취소", comment: "Cancel button"), role: .cancel) { }
        } message: {
            if backupService.hasLocalData() {
                Text(NSLocalizedString("⚠️ 현재 기기에 데이터가 있습니다.\n\n복구하면 현재의 모든 단축어, 클립보드, 콤보가 삭제되고 백업 데이터로 교체됩니다.\n\n이 작업은 되돌릴 수 없습니다. 계속하시겠습니까?", comment: "Restore with data warning message"))
            } else {
                Text(NSLocalizedString("백업 데이터를 복구합니다.", comment: "Restore empty device message"))
            }
        }
        .confirmationDialog(NSLocalizedString("정말 백업할까요?", comment: "Backup reduce confirm title"), isPresented: $showReduceConfirm, titleVisibility: .visible) {
            Button(NSLocalizedString("그래도 백업", comment: "Back up anyway"), role: .destructive) {
                performBackup(allowReduce: true)
            }
            Button(NSLocalizedString("취소", comment: "Cancel button"), role: .cancel) { }
        } message: {
            Text(String(format: NSLocalizedString("기존 백업(단축어 %1$d개)이 %2$d개로 줄어듭니다.\n줄어든 데이터는 백업에서 사라집니다.\n(나중에 '이전 버전에서 복원'으로 되돌릴 수 있어요.)", comment: "Backup reduce confirm message"), reduceExisting, reduceNew))
        }
        .confirmationDialog(NSLocalizedString("백업 삭제", comment: "Delete backup dialog title"), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(NSLocalizedString("삭제", comment: "Delete button"), role: .destructive) {
                performDelete()
            }
            Button(NSLocalizedString("취소", comment: "Cancel button"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("iCloud의 백업 데이터를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.", comment: "Delete confirmation message"))
        }
        .task {
            // 현재 백업에 메모가 몇 개 들어있는지 불러와 표시(무엇이 백업돼 있는지 확인).
            backupMemoCount = await backupService.currentBackupMemoCount()
        }
        } // else (Pro 유저)
    }

    // MARK: - Actions

    private func performBackup(allowReduce: Bool = false) {
        Task {
            do {
                let outcome = try await backupService.backupData(allowReduce: allowReduce)
                await MainActor.run {
                    switch outcome {
                    case .backedUp(let memoCount):
                        alertTitle = NSLocalizedString("백업 완료", comment: "Backup completed")
                        alertMessage = String(format: NSLocalizedString("단축어 %d개를 iCloud에 백업했습니다.", comment: "Backup success with count"), memoCount)
                    case .nothingToBackUp:
                        alertTitle = NSLocalizedString("백업할 내용 없음", comment: "Nothing to back up title")
                        alertMessage = NSLocalizedString("백업할 데이터가 없습니다. 단축어를 추가한 뒤 다시 시도해주세요.", comment: "Nothing to back up message")
                    case .skippedToProtectExisting(let existing, let new):
                        alertTitle = NSLocalizedString("백업 건너뜀", comment: "Backup skipped title")
                        alertMessage = String(format: NSLocalizedString("기존 백업(단축어 %1$d개)을 지키기 위해 이번 백업(%2$d개)을 건너뛰었습니다.", comment: "Backup skipped to protect existing"), existing, new)
                    }
                    backupMemoCount = nil
                    showAlert = true
                }
                // 백업에 실제로 들어있는 개수를 갱신해 화면에 반영
                let count = await backupService.currentBackupMemoCount()
                await MainActor.run { backupMemoCount = count }
            } catch CloudKitError.backupWouldReduceData(let existing, let new) {
                // 데이터 손실 위험 → 바로 백업하지 않고 사용자 동의를 받는다.
                await MainActor.run {
                    reduceExisting = existing
                    reduceNew = new
                    showReduceConfirm = true
                }
            } catch let error as CloudKitError {
                await MainActor.run {
                    alertTitle = NSLocalizedString("백업 실패", comment: "Backup failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = NSLocalizedString("백업 실패", comment: "Backup failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    private func performRestore() {
        Task {
            do {
                // 사용자가 확인 대화상자에서 "복구"를 선택했으므로 forceOverwrite = true
                try await backupService.restoreData(forceOverwrite: true)
                await MainActor.run {
                    alertTitle = NSLocalizedString("복구 완료", comment: "Restore completed")
                    alertMessage = NSLocalizedString("데이터가 성공적으로 복구되었습니다. 앱을 재시작하여 변경사항을 확인하세요.", comment: "Data successfully restored")
                    showAlert = true
                }
            } catch let error as CloudKitError {
                await MainActor.run {
                    alertTitle = NSLocalizedString("복구 실패", comment: "Restore failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = NSLocalizedString("복구 실패", comment: "Restore failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    private func performDelete() {
        Task {
            do {
                try await backupService.deleteBackup()
                await MainActor.run {
                    alertTitle = NSLocalizedString("삭제 완료", comment: "Deletion completed")
                    alertMessage = NSLocalizedString("백업 데이터가 삭제되었습니다.", comment: "Backup data deleted")
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = NSLocalizedString("삭제 실패", comment: "Deletion failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    // MARK: - 파일 백업 (내보내기/가져오기)

    /// 현재 모든 데이터를 자기완결형 .json 번들로 만들어 파일 내보내기 시트를 띄운다.
    private func performExportToFile() {
        do {
            let data = try DataPortability.makeBundleData()
            exportDocument = BackupFileDocument(data: data)
            exportFilename = DataPortability.suggestedFilename()
            showExporter = true
        } catch {
            alertTitle = NSLocalizedString("내보내기 실패", comment: "Export failed")
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    /// 파일 선택 결과를 받아 번들을 병합 가져오기한다.
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            alertTitle = NSLocalizedString("가져오기 실패", comment: "Import failed")
            alertMessage = error.localizedDescription
            showAlert = true
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                // 샌드박스 밖 파일 접근 권한 확보
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                // (`.dataRestored` 는 importBundle 이 스스로 쏜다)
                let summary = try DataPortability.importBundle(data)
                alertTitle = NSLocalizedString("가져오기 완료", comment: "Import completed")
                alertMessage = summary.localizedDescription
                showAlert = true
            } catch {
                alertTitle = NSLocalizedString("가져오기 실패", comment: "Import failed")
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}

// MARK: - 버전(타임머신) 복원 화면

/// 보관 중인 백업 스냅샷을 날짜별로 보여주고, 선택한 시점으로 복원한다.
struct BackupVersionsView: View {
    @ObservedObject private var backupService = CloudKitBackupService.shared
    @State private var snapshots: [BackupSnapshotInfo] = []
    @State private var isLoading = true
    @State private var pendingRestore: BackupSnapshotInfo?
    @State private var showConfirm = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if snapshots.isEmpty {
                Text(NSLocalizedString("저장된 버전이 없습니다", comment: "No backup versions available"))
                    .foregroundColor(.secondary)
            } else {
                Section {
                    ForEach(snapshots) { snap in
                        Button {
                            pendingRestore = snap
                            showConfirm = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(snap.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(String(format: NSLocalizedString("단축어 %d개", comment: "Memo count in a backup snapshot"), snap.memoCount))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: AppSymbol.arrowDownDocFill)
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(backupService.isRestoring)
                    }
                } footer: {
                    Text(NSLocalizedString("선택한 시점의 데이터로 복원됩니다. 현재 데이터는 교체됩니다.", comment: "Version restore footer"))
                }
            }
        }
        .navigationTitle(NSLocalizedString("버전에서 복원", comment: "Restore from a version: screen title"))
        .task { await load() }
        .confirmationDialog(
            NSLocalizedString("이 버전으로 복원할까요?", comment: "Restore this version confirmation"),
            isPresented: $showConfirm, titleVisibility: .visible
        ) {
            Button(NSLocalizedString("복원", comment: "Restore"), role: .destructive) {
                if let snap = pendingRestore { restore(snap) }
            }
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {}
        } message: {
            if let snap = pendingRestore {
                Text(String(format: NSLocalizedString("%@ · 단축어 %d개, 현재 데이터는 이 시점으로 교체됩니다.", comment: "Version restore confirm message"),
                            snap.date.formatted(date: .abbreviated, time: .shortened), snap.memoCount))
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button(NSLocalizedString("확인", comment: "OK")) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func load() async {
        let snaps = await backupService.listSnapshots()
        await MainActor.run {
            snapshots = snaps
            isLoading = false
        }
    }

    private func restore(_ snap: BackupSnapshotInfo) {
        Task {
            do {
                try await backupService.restoreData(forceOverwrite: true, snapshotName: snap.recordName)
                // (`.dataRestored` 는 restoreData 가 스스로 쏜다)
                await MainActor.run {
                    alertTitle = NSLocalizedString("복구 완료", comment: "Restore completed")
                    alertMessage = NSLocalizedString("데이터가 성공적으로 복구되었습니다. 앱을 재시작하여 변경사항을 확인하세요.", comment: "Data successfully restored")
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = NSLocalizedString("복구 실패", comment: "Restore failed")
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

struct CloudBackupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CloudBackupView()
        }
    }
}

// MARK: - 파일 백업 번들 (내보내기/가져오기)

/// App Group에 저장된 모든 사용자 데이터를 담는 자기완결형 백업 번들.
/// 이미지까지 base64로 동봉하므로 이 파일 하나로 전체 복원이 가능하다.
/// (iCloud·Pro·로그인과 무관 - 데이터 유실에 대한 최후의 보루)
struct ExportBundle: Codable {
    var formatVersion: Int
    var exportedAt: Date
    var appVersion: String
    var memos: [Memo]
    var smartClipboard: [SmartClipboardHistory]
    var combos: [Combo]
    var images: [String: Data]
    /// 카테고리 설정(목록·아이콘·색·순서·숨김).
    ///
    /// ⚠️ 옵셔널이다. 이 필드가 생기기 전에 내보낸 파일에는 없다.
    ///    단축어의 `category` 값은 파일에 늘 들어 있었지만 **목록 자체는 없어서**,
    ///    가져오면 단축어는 다 돌아오는데 탭이 하나도 없었다.
    var categories: CategorySnapshot?
}

/// 가져오기 결과 요약.
struct ImportSummary {
    var addedMemos: Int
    var updatedMemos: Int
    var totalMemos: Int
    var addedStacks: Int
    var addedClips: Int
    var images: Int
    /// 함께 살아난 카테고리 수.
    var categories: Int = 0

    var localizedDescription: String {
        String(format: NSLocalizedString("단축어 %1$d개 추가, %2$d개 갱신 (총 %3$d개).\n콤보 %4$d개, 이미지 %5$d개, 카테고리 %6$d개를 가져왔습니다.", comment: "Import summary message"),
               addedMemos, updatedMemos, totalMemos, addedStacks, images, categories)
    }
}

enum PortabilityError: LocalizedError {
    case noContainer
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .noContainer:
            return NSLocalizedString("저장소를 찾을 수 없습니다.", comment: "App Group container missing")
        case .unreadableFile:
            return NSLocalizedString("이 파일은 ClipKeyboard 백업 파일이 아니거나 손상되었습니다.", comment: "Unrecognized backup file")
        }
    }
}

/// 내보내기/가져오기 공통 로직. App Group 컨테이너 파일을 직접 다루므로
/// UIKit/AppKit 의존이 없고 iOS·macOS 양쪽에서 동일하게 동작한다.
enum DataPortability {
    static let currentFormatVersion = 1

    private static func container() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
    }

    private static func read<T: Decodable>(_ file: String, as type: T.Type) -> T? {
        guard let url = container()?.appendingPathComponent(file),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to file: String) throws {
        guard let url = container()?.appendingPathComponent(file) else { throw PortabilityError.noContainer }
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }

    static var appVersionString: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }

    static func suggestedFilename() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmm"
        return "ClipKeyboard-Backup-\(f.string(from: Date())).json"
    }

    /// 현재 App Group의 모든 데이터를 JSON 번들로 직렬화(이미지 동봉).
    static func makeBundleData() throws -> Data {
        let memos = read(StorageFile.memos, as: [Memo].self) ?? []
        let smart = read(StorageFile.smartClipboardHistory, as: [SmartClipboardHistory].self) ?? []
        let combos = read(StorageFile.combos, as: [Combo].self) ?? []

        var images: [String: Data] = [:]
        if let imagesDir = container()?.appendingPathComponent("Images", isDirectory: true) {
            for name in Set(memos.flatMap { $0.imageFileNames }) {
                if let d = try? Data(contentsOf: imagesDir.appendingPathComponent(name)) {
                    images[name] = d
                }
            }
        }

        let bundle = ExportBundle(
            formatVersion: currentFormatVersion,
            exportedAt: Date(),
            appVersion: appVersionString,
            memos: memos, smartClipboard: smart, combos: combos, images: images,
            categories: CategorySnapshotStore.current()
        )
        return try JSONEncoder().encode(bundle)
    }

    /// 번들을 병합 가져오기. 절대 삭제하지 않고, id 기준으로 합치며 충돌 시 최신본(lastEdited) 유지.
    @discardableResult
    static func importBundle(_ data: Data) throws -> ImportSummary {
        guard let bundle = try? JSONDecoder().decode(ExportBundle.self, from: data) else {
            throw PortabilityError.unreadableFile
        }
        guard let container = container() else { throw PortabilityError.noContainer }

        // 1) 이미지 먼저 복원(메모가 참조). 이미 있으면 보존.
        var restoredImages = 0
        if !bundle.images.isEmpty {
            let imagesDir = container.appendingPathComponent("Images", isDirectory: true)
            try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
            for (name, bytes) in bundle.images {
                let dest = imagesDir.appendingPathComponent(name)
                if !FileManager.default.fileExists(atPath: dest.path) {
                    // 실패했는데 개수를 올리면 "이미지 N개 복원"이 거짓말이 된다.
                    // 이 앱은 조용한 실패(성공처럼 보이는 무동작)를 없애는 걸 원칙으로 한다.
                    do {
                        try bytes.write(to: dest, options: .atomic)
                        restoredImages += 1
                    } catch {
                        AppLog.error(.backup, "❌ [CloudBackupView] 이미지 복원 실패(\(name)): \(error.localizedDescription)")
                    }
                }
            }
        }

        // 2) 메모 병합 (순서 보존, id 충돌 시 최신 lastEdited 우선)
        var memos = read(StorageFile.memos, as: [Memo].self) ?? []
        var indexById = [UUID: Int]()
        for (i, m) in memos.enumerated() { indexById[m.id] = i }
        var added = 0, updated = 0
        for m in bundle.memos {
            if let i = indexById[m.id] {
                if m.lastEdited > memos[i].lastEdited { memos[i] = m; updated += 1 }
            } else {
                indexById[m.id] = memos.count
                memos.append(m)
                added += 1
            }
        }
        try write(memos, to: StorageFile.memos)

        // 3) 콤보 병합 (union by id)
        var combos = read(StorageFile.combos, as: [Combo].self) ?? []
        var stackIds = Set(combos.map { $0.id })
        var addedStacks = 0
        for c in bundle.combos where !stackIds.contains(c.id) {
            combos.append(c); stackIds.insert(c.id); addedStacks += 1
        }
        try write(combos, to: StorageFile.combos)

        // 4) 스마트 클립보드 병합 (union by id)
        var clips = read(StorageFile.smartClipboardHistory, as: [SmartClipboardHistory].self) ?? []
        var clipIds = Set(clips.map { $0.id })
        var addedClips = 0
        for c in bundle.smartClipboard where !clipIds.contains(c.id) {
            clips.append(c); clipIds.insert(c.id); addedClips += 1
        }
        try write(clips, to: StorageFile.smartClipboardHistory)

        // 5) 카테고리 설정
        //    ⚠️ `.merge` 다. 가져오기는 "합친다"는 뜻이라(단축어도 지우지 않고 합친다)
        //       이 기기에만 있던 카테고리를 파일이 지우면 안 된다.
        //    파일에 카테고리가 없으면(옛 파일) 단축어의 `category` 값에서 이름만 역산해 구제한다.
        var restoredCategories = 0
        if let snapshot = bundle.categories, !snapshot.isEmpty {
            CategorySnapshotStore.apply(snapshot, strategy: .merge)
            restoredCategories = snapshot.categories.count
        } else {
            restoredCategories = CategorySnapshotStore.rebuildFromMemos(memos).count
        }

        MemoStore.postDataChanged()
        // 카테고리는 `.memoDataChanged` 로 안 딸려 온다. 저장소·화면이 다시 읽게 따로 알린다.
        NotificationCenter.postOnMain(name: .dataRestored)

        return ImportSummary(addedMemos: added, updatedMemos: updated, totalMemos: memos.count,
                             addedStacks: addedStacks, addedClips: addedClips, images: restoredImages,
                             categories: restoredCategories)
    }
}

// MARK: - 파일 도큐먼트 (fileExporter/fileImporter 용)

struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
