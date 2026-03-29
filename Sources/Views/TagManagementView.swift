import SwiftData
import SwiftUI

private struct EditableTagTarget: Identifiable {
    let id: UUID
    let tag: TagRecord
}

private struct TagEntriesTarget: Identifiable {
    let id: UUID
    let tagName: String
    let tintHex: Int
}

struct TagManagementView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\TagRecord.createdAt, order: .forward)]) private var tags: [TagRecord]
    @Query(sort: [SortDescriptor(\LedgerEntry.createdAt, order: .reverse)]) private var entries: [LedgerEntry]

    @State private var newTagName = ""
    @State private var selectedTintHex = TagEmojiLibrary.defaultTintHex
    @State private var pendingDeleteTag: TagRecord?
    @State private var editingTag: EditableTagTarget?
    @State private var viewingTagEntries: TagEntriesTarget?
    @State private var noticeMessage = ""
    @State private var showNotice = false
    @FocusState private var isInputFocused: Bool

    private var visibleTags: [TagRecord] {
        var seen = Set<String>()
        return tags.filter { tag in
            let normalized = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return false }
            return seen.insert(normalized.lowercased()).inserted
        }
    }

    private var tagTintHexByName: [String: Int] {
        var result: [String: Int] = [:]
        for tag in visibleTags {
            result[tag.name] = tag.resolvedTintHex
        }
        return result
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                addTagCard
                existingTagsCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .navigationTitle("标签管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert("提示", isPresented: $showNotice) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(noticeMessage)
        }
        .alert(
            "删除标签",
            isPresented: Binding(
                get: { pendingDeleteTag != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeleteTag = nil
                    }
                }
            ),
            presenting: pendingDeleteTag
        ) { tag in
            Button("删除", role: .destructive) {
                delete(tag)
            }
            Button("取消", role: .cancel) {
                pendingDeleteTag = nil
            }
        } message: { tag in
            Text(L10n.string("tag.deleteMessage", locale: locale, tag.name))
        }
        .sheet(item: $editingTag) { target in
            TagEditorSheet(
                initialName: target.tag.name,
                initialTintHex: target.tag.resolvedTintHex
            ) { updatedName, updatedTintHex in
                updateTag(target.tag, newName: updatedName, tintHex: updatedTintHex)
            }
        }
        .sheet(item: $viewingTagEntries) { target in
            TagEntriesSheet(
                tagName: target.tagName,
                tintHex: target.tintHex,
                entries: entriesForTag(named: target.tagName),
                tagTintHexByName: tagTintHexByName
            )
        }
        .appBackground()
    }

    private var addTagCard: some View {
        SettingsSectionCard(title: "新增标签") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(SWTheme.accentBlue)
                        .frame(width: 22)

                    TextField("例如：通勤 / 家庭 / 报销 / 旅行", text: $newTagName)
                        .focused($isInputFocused)
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(SWTheme.primaryText)

                    Button("添加") {
                        addTag()
                    }
                    .font(.subheadline.weight(.semibold))
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TagEmojiLibrary.tintOptions, id: \.self) { tintHex in
                            Button {
                                selectedTintHex = tintHex
                                HapticService.selection()
                            } label: {
                                tagTintSwatch(
                                    tintHex: tintHex,
                                    isSelected: selectedTintHex == tintHex
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Text("标签统一使用标签图标，你可以为它选择不同颜色。")
                    .font(.caption)
                    .foregroundStyle(SWTheme.textSecondary)
            }
        }
    }

    private var existingTagsCard: some View {
        SettingsSectionCard(title: "已有标签") {
            if visibleTags.isEmpty {
                Text("还没有标签，先添加一个常用标签吧。")
                    .font(.subheadline)
                    .foregroundStyle(SWTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ForEach(Array(visibleTags.enumerated()), id: \.element.id) { index, tag in
                    HStack(spacing: 12) {
                        Menu {
                            ForEach(TagEmojiLibrary.tintOptions, id: \.self) { tintHex in
                                Button {
                                    updateTint(for: tag, tintHex: tintHex)
                                } label: {
                                    HStack {
                                        Image(systemName: "tag.fill")
                                            .foregroundStyle(Color.sw(UInt(tintHex)))
                                        Text(colorName(for: tintHex))
                                    }
                                }
                            }
                        } label: {
                            tagTintSwatch(
                                tintHex: tag.resolvedTintHex,
                                isSelected: false
                            )
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(tag.name)
                                .foregroundStyle(SWTheme.primaryText)

                            Text(L10n.string("tag.usageCount", locale: locale, Int64(usageCount(for: tag.name))))
                                .font(.caption)
                                .foregroundStyle(SWTheme.textSecondary)
                        }

                        Spacer()

                        Button {
                            viewingTagEntries = TagEntriesTarget(
                                id: tag.id,
                                tagName: tag.name,
                                tintHex: tag.resolvedTintHex
                            )
                        } label: {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SWTheme.accentBlue)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.04))
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            editingTag = EditableTagTarget(id: tag.id, tag: tag)
                        } label: {
                            Image(systemName: "pencil")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SWTheme.accentGreen)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.04))
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            pendingDeleteTag = tag
                        } label: {
                            Image(systemName: "trash")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SWTheme.accentOrange)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.04))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)

                    if index < visibleTags.count - 1 {
                        SettingsRowDivider()
                    }
                }
            }
        }
    }

    private func usageCount(for tagName: String) -> Int {
        entries.reduce(0) { partialResult, entry in
            partialResult + (entry.tagNames.contains(tagName) ? 1 : 0)
        }
    }

    private func entriesForTag(named tagName: String) -> [LedgerEntry] {
        entries.filter { $0.tagNames.contains(tagName) }
    }

    private func addTag() {
        let trimmedName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if visibleTags.contains(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            noticeMessage = L10n.string("tag.exists", locale: locale, trimmedName)
            showNotice = true
            return
        }

        modelContext.insert(TagRecord(name: trimmedName, tintHex: selectedTintHex))
        try? modelContext.save()

        newTagName = ""
        selectedTintHex = TagEmojiLibrary.defaultTintHex
        isInputFocused = false
        HapticService.impact()
    }

    private func delete(_ tag: TagRecord) {
        modelContext.delete(tag)
        try? modelContext.save()
        pendingDeleteTag = nil
        HapticService.impact()
    }

    private func presentNotice(message: String) {
        noticeMessage = message
        showNotice = true
    }

    private func updateTag(_ tag: TagRecord, newName: String, tintHex: Int) -> String? {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return "标签名称不能为空。".appLocalized(in: locale)
        }

        if visibleTags.contains(where: {
            $0.id != tag.id && $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }) {
            return L10n.string("tag.exists", locale: locale, trimmedName)
        }

        let originalName = tag.name
        tag.name = trimmedName
        tag.tintHex = tintHex

        if originalName != trimmedName {
            for entry in entries where entry.tagNames.contains(originalName) {
                entry.tagNames = entry.tagNames.map { $0 == originalName ? trimmedName : $0 }
            }
        }

        do {
            try modelContext.save()
            HapticService.impact()
            presentNotice(message: "标签已更新。".appLocalized(in: locale))
            return nil
        } catch {
            return "标签更新失败，请稍后再试。".appLocalized(in: locale)
        }
    }

    private func updateTint(for tag: TagRecord, tintHex: Int) {
        tag.tintHex = tintHex
        try? modelContext.save()
        HapticService.selection()
    }

    private func colorName(for tintHex: Int) -> String {
        let options = TagEmojiLibrary.tintOptions
        if tintHex == options[0] { return "蓝色".appLocalized(in: locale) }
        if tintHex == options[1] { return "绿色".appLocalized(in: locale) }
        if tintHex == options[2] { return "橙色".appLocalized(in: locale) }
        if tintHex == options[3] { return "粉色".appLocalized(in: locale) }
        if tintHex == options[4] { return "紫色".appLocalized(in: locale) }
        if tintHex == options[5] { return "青色".appLocalized(in: locale) }
        if tintHex == options[6] { return "金色".appLocalized(in: locale) }
        return "红色".appLocalized(in: locale)
    }

    private func tagTintSwatch(tintHex: Int, isSelected: Bool) -> some View {
        let tint = Color.sw(UInt(tintHex))

        return Image(systemName: "tag.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isSelected ? tint.opacity(0.9) : Color.white.opacity(0.10),
                                lineWidth: isSelected ? 1.4 : 1
                            )
                    )
            )
    }
}

private struct TagEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let onSave: (String, Int) -> String?

    @State private var name: String
    @State private var selectedTintHex: Int
    @State private var errorMessage = ""
    @State private var showError = false

    init(initialName: String, initialTintHex: Int, onSave: @escaping (String, Int) -> String?) {
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _selectedTintHex = State(initialValue: initialTintHex)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    SettingsSectionCard(title: "编辑标签") {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("例如：通勤 / 家庭 / 报销 / 旅行", text: $name)
                                .textInputAutocapitalization(.never)
                                .foregroundStyle(SWTheme.primaryText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.04))
                                )

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(TagEmojiLibrary.tintOptions, id: \.self) { tintHex in
                                        Button {
                                            selectedTintHex = tintHex
                                            HapticService.selection()
                                        } label: {
                                            tagTintSwatch(
                                                tintHex: tintHex,
                                                isSelected: selectedTintHex == tintHex
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }

                            Text("修改标签名称或颜色后，会同步更新已有账单。".appLocalized(in: locale))
                                .font(.caption)
                                .foregroundStyle(SWTheme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .navigationTitle("编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存修改") {
                        if let message = onSave(name, selectedTintHex) {
                            errorMessage = message
                            showError = true
                        } else {
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("提示", isPresented: $showError) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .appBackground()
        }
    }

    private func tagTintSwatch(tintHex: Int, isSelected: Bool) -> some View {
        let tint = Color.sw(UInt(tintHex))

        return Image(systemName: "tag.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isSelected ? tint.opacity(0.9) : Color.white.opacity(0.10),
                                lineWidth: isSelected ? 1.4 : 1
                            )
                    )
            )
    }
}

private struct TagEntriesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let tagName: String
    let tintHex: Int
    let entries: [LedgerEntry]
    let tagTintHexByName: [String: Int]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    SettingsSectionCard(title: "标签账单") {
                        HStack(spacing: 10) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.sw(UInt(tintHex)))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(tagName)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(SWTheme.primaryText)
                                Text("与该标签关联的全部收支记录".appLocalized(in: locale))
                                    .font(.caption)
                                    .foregroundStyle(SWTheme.textSecondary)
                            }

                            Spacer()
                        }
                    }

                    if entries.isEmpty {
                        EmptyStateCard(
                            title: "该标签暂无账单",
                            subtitle: "给账单选择这个标签后，这里会自动汇总显示",
                            symbol: "tray.fill"
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(entries) { entry in
                                LedgerRow(entry: entry, tagTintHexByName: tagTintHexByName)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .navigationTitle(tagName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .appBackground()
        }
    }
}
