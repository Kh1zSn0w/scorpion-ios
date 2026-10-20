import UIKit

final class FilesViewController: UITableViewController {
    static let filesChanged = Notification.Name("ScorpionFilesChanged")
    private let directory: URL
    private var files: [URL] = []
    var onClose: (() -> Void)?

    init(directory: URL) { self.directory = directory; super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: Self.filesChanged, object: nil)
        refresh()
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func close() { dismiss(animated: true, completion: onClose) }
    @objc private func refresh() {
        do {
            files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles)
                .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            let label = UILabel()
            label.text = "Completed downloads appear here."
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            tableView.backgroundView = files.isEmpty ? label : nil
            tableView.reloadData()
        } catch {
            let label = UILabel()
            label.text = "Could not read downloads: " + error.localizedDescription
            label.numberOfLines = 0
            tableView.backgroundView = label
        }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { files.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = files[indexPath.row].lastPathComponent
        cell.textLabel?.numberOfLines = 2
        cell.imageView?.image = UIImage(systemName: "square.and.arrow.up")
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let activity = UIActivityViewController(activityItems: [files[indexPath.row]], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
        present(activity, animated: true)
    }
}
