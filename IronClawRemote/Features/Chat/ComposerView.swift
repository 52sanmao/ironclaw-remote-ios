import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ComposerNotice: Equatable {
    enum Tone: Equatable {
        case info
        case warning
        case error
    }

    let message: String
    let tone: Tone
}

struct ComposerAttachment: Identifiable, Equatable {
    let id: UUID
    let filename: String
    let mediaType: String
    let data: Data

    init(id: UUID = UUID(), filename: String, mediaType: String, data: Data) {
        self.id = id
        self.filename = filename
        self.mediaType = mediaType
        self.data = data
    }

    var payload: ImagePayload {
        ImagePayload(mediaType: mediaType, data: data.base64EncodedString())
    }

    var byteCountText: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }

    var previewImage: Image? {
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
    }
}

struct ComposerView: View {
    @Binding var text: String
    let attachments: [ComposerAttachment]
    let notice: ComposerNotice?
    let streamState: ChatStreamState
    let onAttachmentsChanged: ([ComposerAttachment]) -> Void
    let onSend: () -> Void
    let onStop: () -> Void

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isPreparingAttachments = false
    @State private var attachmentErrorMessage: String?

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !trimmedText.isEmpty && !isBusy && !isPreparingAttachments
    }

    private var isBusy: Bool {
        streamState == .sending || streamState == .streaming || streamState == .waitingForGate
    }

    private var canStop: Bool {
        streamState == .sending || streamState == .streaming
    }

    private var shouldShowDraftHint: Bool {
        !attachments.isEmpty && trimmedText.isEmpty && !isBusy && !isPreparingAttachments
    }

    private var hasFooterContent: Bool {
        statusText != nil || notice != nil || attachmentErrorMessage != nil || isPreparingAttachments || shouldShowDraftHint
    }

    var body: some View {
        VStack(spacing: ICSpacing.xs) {
            Divider()

            if !attachments.isEmpty {
                attachmentTray
            }

            HStack(alignment: .bottom, spacing: ICSpacing.sm) {
                attachmentButton

                TextField("Message or / for commands…", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)
                    .disabled(isBusy)
                    .submitLabel(canSend ? .send : .return)
                    .onSubmit {
                        if canSend {
                            onSend()
                        }
                    }

                if canStop {
                    Button(action: onStop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 28))
                    }
                    .tint(ICColor.danger)
                    .accessibilityLabel("Stop live response")
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                    }
                    .disabled(!canSend)
                    .accessibilityLabel("Send message")
                }
            }
            .padding(ICSpacing.md)

            if hasFooterContent {
                footer
            }
        }
        .background(.regularMaterial)
        .onChange(of: selectedPhotos) { _, newValue in
            Task {
                await loadAttachments(from: newValue)
            }
        }
        .onChange(of: attachments.isEmpty) { _, isEmpty in
            if isEmpty {
                selectedPhotos = []
            }
        }
    }

    private var attachmentButton: some View {
        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 3, matching: .images) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: attachments.isEmpty ? "paperclip.circle" : "paperclip.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(attachments.isEmpty ? ICColor.textSecondary : ICColor.accent)
                    .frame(width: 36, height: 36)

                if !attachments.isEmpty {
                    Text("\(attachments.count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(ICColor.accent)
                        .clipShape(Capsule())
                        .offset(x: 8, y: -6)
                }
            }
        }
        .disabled(isBusy || isPreparingAttachments)
        .accessibilityLabel("Attach images")
    }

    private var attachmentTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ICSpacing.sm) {
                ForEach(attachments) { attachment in
                    AttachmentChip(attachment: attachment)
                }

                Button("Clear") {
                    selectedPhotos = []
                    attachmentErrorMessage = nil
                    onAttachmentsChanged([])
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, ICSpacing.md)
            .padding(.top, ICSpacing.sm)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: ICSpacing.xxs) {
            if let statusText {
                footerRow(text: statusText, color: statusColor, systemImage: statusIconName)
            }

            if isPreparingAttachments {
                footerRow(text: "Preparing image attachments…", color: ICColor.textSecondary, systemImage: "photo.on.rectangle.angled")
            }

            if shouldShowDraftHint {
                footerRow(text: "Add a message before sending the attached images.", color: ICColor.warning, systemImage: "text.cursor")
            }

            if let attachmentErrorMessage {
                footerRow(text: attachmentErrorMessage, color: ICColor.danger, systemImage: "exclamationmark.triangle.fill")
            }

            if let notice {
                footerRow(text: notice.message, color: noticeColor(notice), systemImage: noticeIcon(notice))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ICSpacing.md)
        .padding(.bottom, ICSpacing.sm)
    }

    private func footerRow(text: String, color: Color, systemImage: String) -> some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(color)
        } icon: {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(color)
        }
    }

    private var statusText: String? {
        switch streamState {
        case .idle:
            return nil
        case .sending:
            return "Sending your message…"
        case .streaming:
            return "IronClaw is responding…"
        case .waitingForGate:
            return "Awaiting approval before the run can continue."
        case .failed:
            return "Live response needs attention."
        }
    }

    private var statusColor: Color {
        switch streamState {
        case .failed:
            return ICColor.danger
        case .waitingForGate:
            return ICColor.warning
        default:
            return ICColor.textSecondary
        }
    }

    private var statusIconName: String {
        switch streamState {
        case .sending:
            return "paperplane"
        case .streaming:
            return "waveform"
        case .waitingForGate:
            return "lock.shield"
        case .failed:
            return "xmark.octagon.fill"
        case .idle:
            return "info.circle"
        }
    }

    private func noticeColor(_ notice: ComposerNotice) -> Color {
        switch notice.tone {
        case .info:
            return ICColor.textSecondary
        case .warning:
            return ICColor.warning
        case .error:
            return ICColor.danger
        }
    }

    private func noticeIcon(_ notice: ComposerNotice) -> String {
        switch notice.tone {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.shield"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private func loadAttachments(from items: [PhotosPickerItem]) async {
        await MainActor.run {
            attachmentErrorMessage = nil
            isPreparingAttachments = !items.isEmpty
        }

        guard !items.isEmpty else {
            await MainActor.run {
                onAttachmentsChanged([])
                isPreparingAttachments = false
            }
            return
        }

        var loadedAttachments: [ComposerAttachment] = []
        var failedCount = 0

        for (index, item) in items.prefix(3).enumerated() {
            do {
                guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                    failedCount += 1
                    continue
                }
                loadedAttachments.append(makeAttachment(from: data, supportedTypes: item.supportedContentTypes, index: index + 1))
            } catch {
                failedCount += 1
            }
        }

        await MainActor.run {
            onAttachmentsChanged(loadedAttachments)
            isPreparingAttachments = false
            if failedCount > 0 {
                attachmentErrorMessage = loadedAttachments.isEmpty
                    ? "Couldn’t prepare the selected images."
                    : "Some selected images couldn’t be attached."
            }
        }
    }

    private func makeAttachment(from data: Data, supportedTypes: [UTType], index: Int) -> ComposerAttachment {
        let primaryType = supportedTypes.first(where: { $0.conforms(to: .image) })
        let mimeType = primaryType?.preferredMIMEType

        if mimeType == "image/png" || mimeType == "image/gif" {
            let fileExtension = primaryType?.preferredFilenameExtension ?? "img"
            return ComposerAttachment(
                filename: "Image \(index).\(fileExtension)",
                mediaType: mimeType ?? "application/octet-stream",
                data: data
            )
        }

        if let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.82) {
            return ComposerAttachment(
                filename: "Image \(index).jpg",
                mediaType: "image/jpeg",
                data: jpegData
            )
        }

        let fileExtension = primaryType?.preferredFilenameExtension ?? "img"
        return ComposerAttachment(
            filename: "Image \(index).\(fileExtension)",
            mediaType: mimeType ?? "application/octet-stream",
            data: data
        )
    }
}

private struct AttachmentChip: View {
    let attachment: ComposerAttachment

    var body: some View {
        HStack(spacing: ICSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: ICCornerRadius.md, style: .continuous)
                    .fill(ICColor.background)
                    .frame(width: 44, height: 44)

                if let previewImage = attachment.previewImage {
                    previewImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.md, style: .continuous))
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(ICColor.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ICColor.textPrimary)
                    .lineLimit(1)
                Text(attachment.byteCountText)
                    .font(.caption2)
                    .foregroundStyle(ICColor.textSecondary)
            }
        }
        .padding(8)
        .background(ICColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: ICCornerRadius.card, style: .continuous))
    }
}
