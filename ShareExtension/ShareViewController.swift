import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var sourceText = ""
    private var sourceURL: String?
    private var sourceLabel: UILabel!
    private var noteField: UITextView!
    private var errorLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "In Album sammeln"; title.font = .preferredFont(forTextStyle: .title2)
        sourceLabel = UILabel(); sourceLabel.textColor = .secondaryLabel; sourceLabel.numberOfLines = 3; sourceLabel.font = .preferredFont(forTextStyle: .subheadline)
        noteField = UITextView(); noteField.font = .preferredFont(forTextStyle: .body); noteField.layer.borderWidth = 0.5; noteField.layer.cornerRadius = 8; noteField.accessibilityLabel = "Optionale Nachricht"
        errorLabel = UILabel(); errorLabel.textColor = .systemRed; errorLabel.numberOfLines = 0; errorLabel.font = .preferredFont(forTextStyle: .footnote)
        let saveButton = UIButton(type: .system); saveButton.setTitle("In Album sammeln", for: .normal); saveButton.titleLabel?.font = .preferredFont(forTextStyle: .headline); saveButton.addTarget(self, action: #selector(ShareViewController.save), for: .touchUpInside)
        let cancelButton = UIButton(type: .system); cancelButton.setTitle("Abbrechen", for: .normal); cancelButton.addTarget(self, action: #selector(ShareViewController.cancel), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [title, sourceLabel, noteField, errorLabel, saveButton, cancelButton]); stack.axis = .vertical; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack); NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20), stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20), noteField.heightAnchor.constraint(greaterThanOrEqualToConstant: 90)])
        Task { await loadInput() }
    }

    private func loadInput() async {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else { showError(ShareInboxError.invalidInput); return }
        for provider in extensionItem.attachments ?? [] {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier), let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) {
                if let url = item as? URL, ["http", "https"].contains(url.scheme?.lowercased() ?? "") { sourceURL = url.absoluteString; sourceText = url.absoluteString; break }
                if let value = item as? String, let url = ShareInput.firstURL(in: value) { sourceURL = url.absoluteString; sourceText = url.absoluteString; break }
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier), let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier), let text = item as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sourceText = text; sourceURL = ShareInput.firstURL(in: text)?.absoluteString; break
            }
        }
        if sourceText.isEmpty { showError(ShareInboxError.invalidInput) }
        await MainActor.run { sourceLabel?.text = sourceURL ?? sourceText; sourceLabel?.accessibilityLabel = "Quelle: \(sourceURL ?? sourceText)" }
    }

    @objc private func save() {
        guard !sourceText.isEmpty else { showError(ShareInboxError.invalidInput); return }
        guard let context = ShareInbox().loadContext() else { showError(ShareInboxError.missingContext); return }
        let note = noteField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceOnlyURL = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sharedText = original == sourceOnlyURL ? "" : original
        let payload = [sharedText, note].filter { !$0.isEmpty }.joined(separator: "\n\n")
        let item = ShareQueueItem(payload: payload, url: sourceURL, tripKey: context.tripKey)
        do { try ShareInbox().save(item); extensionContext?.completeRequest(returningItems: nil) } catch { showError(error) }
    }

    @objc private func cancel() { extensionContext?.cancelRequest(withError: NSError(domain: "Album.Share", code: 0)) }
    private func showError(_ error: Error) { errorLabel?.text = error.localizedDescription }
}

private enum ShareInput {
    static func firstURL(in text: String) -> URL? {
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue), let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let url = match.url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") { return url }
        return nil
    }
}
