import UIKit
import WebKit
import SafariServices

final class BrowserViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, UIAdaptivePresentationControllerDelegate, SFSafariViewControllerDelegate {
    private var webView: WKWebView!
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let errorLabel = UILabel()
    private let errorPanel = UIStackView()
    private var observations: [NSKeyValueObservation] = []
    private var activeDownloads: [ObjectIdentifier: WKDownload] = [:]
    private var destinations: [ObjectIdentifier: URL] = [:]
    private var pendingAlerts: [UIAlertController] = []
    private var lastSiteRequest = URLRequest(url: NavigationRules.home)
    private lazy var back = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), style: .plain, target: self, action: #selector(goBack))
    private lazy var forward = UIBarButtonItem(image: UIImage(systemName: "chevron.forward"), style: .plain, target: self, action: #selector(goForward))
    private let downloadsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Downloads", isDirectory: true)
    private let partialDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("DownloadsInProgress", isDirectory: true)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        do {
            guard let imageURL = Bundle.main.url(forResource: "scorpion", withExtension: "png"),
                  let scriptURL = Bundle.main.url(forResource: "Mascot", withExtension: "js") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let image = try Data(contentsOf: imageURL).base64EncodedString()
            let script = try String(contentsOf: scriptURL, encoding: .utf8)
                .replacingOccurrences(of: "__SCORPION_DATA_URL__", with: "data:image/png;base64," + image)
            configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
            try FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
            // Interrupted downloads are never listed as finished files.
            if FileManager.default.fileExists(atPath: partialDirectory.path) {
                try FileManager.default.removeItem(at: partialDirectory)
            }
            try FileManager.default.createDirectory(at: partialDirectory, withIntermediateDirectories: true)
        } catch {
            notify("Setup failed", error.localizedDescription)
        }
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black

        let toolbar = UIToolbar()
        toolbar.items = [back, .flexibleSpace(), forward, .flexibleSpace(),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reload)), .flexibleSpace(),
            UIBarButtonItem(image: UIImage(systemName: "folder"), style: .plain, target: self, action: #selector(showDownloads)), .flexibleSpace(),
            UIBarButtonItem(image: UIImage(systemName: "safari"), style: .plain, target: self, action: #selector(openWebsite))]
        back.accessibilityLabel = "Back"
        forward.accessibilityLabel = "Forward"
        toolbar.items?[6].accessibilityLabel = "Downloaded files"
        toolbar.items?[8].accessibilityLabel = "Open website"
        [webView!, progress, toolbar, errorPanel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        let retry = UIButton(type: .system)
        retry.setTitle("Retry", for: .normal)
        retry.addTarget(self, action: #selector(reload), for: .touchUpInside)
        errorPanel.axis = .vertical
        errorPanel.spacing = 16
        errorPanel.addArrangedSubview(errorLabel)
        errorPanel.addArrangedSubview(retry)
        errorPanel.backgroundColor = .systemBackground
        errorPanel.isHidden = true
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            progress.topAnchor.constraint(equalTo: safe.topAnchor), progress.leadingAnchor.constraint(equalTo: safe.leadingAnchor), progress.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            webView.topAnchor.constraint(equalTo: progress.bottomAnchor), webView.leadingAnchor.constraint(equalTo: safe.leadingAnchor), webView.trailingAnchor.constraint(equalTo: safe.trailingAnchor), webView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: safe.leadingAnchor), toolbar.trailingAnchor.constraint(equalTo: safe.trailingAnchor), toolbar.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            errorPanel.centerYAnchor.constraint(equalTo: webView.centerYAnchor), errorPanel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24), errorPanel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24)
        ])
        observations = [webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
            self?.progress.progress = Float(webView.estimatedProgress)
            self?.progress.isHidden = webView.estimatedProgress >= 1
        }, webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
            self?.back.isEnabled = webView.canGoBack
        }, webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
            self?.forward.isEnabled = webView.canGoForward
        }]
        webView.load(URLRequest(url: NavigationRules.home))
    }

    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); presentNextAlert() }
    @objc private func goBack() { webView.goBack() }
    @objc private func goForward() { webView.goForward() }
    @objc private func reload() {
        let wasFailed = !errorPanel.isHidden
        errorPanel.isHidden = true
        if wasFailed || webView.url == nil { webView.load(lastSiteRequest) } else { webView.reload() }
    }
    @objc private func openWebsite() { openExternal(webView.url.flatMap { NavigationRules.isSite($0) ? $0 : nil } ?? NavigationRules.home) }
    private func openExternal(_ url: URL) {
        guard NavigationRules.isWeb(url) else { return }
        guard presentedViewController == nil else { notify("Link could not open", "Close the current sheet, then try the link again."); return }
        let browser = SFSafariViewController(url: url)
        browser.delegate = self
        browser.presentationController?.delegate = self
        present(browser, animated: true)
    }
    @objc private func showDownloads() {
        let files = FilesViewController(directory: downloadsDirectory)
        files.title = "Downloads"
        files.onClose = { [weak self] in self?.presentNextAlert() }
        let navigation = UINavigationController(rootViewController: files)
        navigation.presentationController?.delegate = self
        present(navigation, animated: true)
    }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { presentNextAlert() }
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) { controller.dismiss(animated: true) { [weak self] in self?.presentNextAlert() } }
    private func notify(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in self?.scheduleNextAlert() })
        pendingAlerts.append(alert)
        presentNextAlert()
    }
    private func presentNextAlert() {
        guard isViewLoaded, view.window != nil, presentedViewController == nil, !pendingAlerts.isEmpty else { return }
        present(pendingAlerts.removeFirst(), animated: true)
    }
    private func scheduleNextAlert() { DispatchQueue.main.async { [weak self] in self?.presentNextAlert() } }
    private func navigationFailed(_ error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        progress.isHidden = true
        errorLabel.text = "The website could not load.\n" + error.localizedDescription
        errorPanel.isHidden = false
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { navigationFailed(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { navigationFailed(error) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { errorPanel.isHidden = true }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { navigationFailed(NSError(domain: "Scorpion", code: 1, userInfo: [NSLocalizedDescriptionKey: "The web process stopped. Tap Retry to reload."])) }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, NavigationRules.allowsInternalURL(url) else { decisionHandler(.cancel); return }
        if action.targetFrame?.isMainFrame != false, NavigationRules.isSite(url) { lastSiteRequest = action.request }
        if action.shouldPerformDownload {
            guard action.sourceFrame.isMainFrame, action.sourceFrame.securityOrigin.protocol == "https", action.sourceFrame.securityOrigin.host == "cobalt.meowing.de", [0, 443].contains(action.sourceFrame.securityOrigin.port) else { decisionHandler(.cancel); return }
            decisionHandler(.download)
        } else { decisionHandler(.allow) }
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let attachment = (response.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition")?.lowercased().contains("attachment") == true
        switch NavigationRules.responseDisposition(url: response.response.url, mime: response.response.mimeType, canDisplay: response.canShowMIMEType, attachment: attachment, mainFrame: response.isForMainFrame) {
        case .download: decisionHandler(.download)
        case .cancel: decisionHandler(.cancel)
        case .external:
            decisionHandler(.cancel)
            if let url = response.response.url { openExternal(url) }
        case .display: decisionHandler(.allow)
        }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil, action.sourceFrame.isMainFrame, let url = action.request.url, NavigationRules.allowsInternalURL(url) {
            webView.load(action.request)
        }
        return nil
    }
    private func retainDownload(_ download: WKDownload) {
        activeDownloads[ObjectIdentifier(download)] = download
        download.delegate = self
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { retainDownload(download) }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { retainDownload(download) }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let destination = partialDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true).appendingPathComponent(DownloadFiles.safeName(suggestedFilename))
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            destinations[ObjectIdentifier(download)] = destination
            completionHandler(destination)
        } catch { completionHandler(nil); finish(download, error: error) }
    }
    func downloadDidFinish(_ download: WKDownload) { finish(download, error: nil) }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) { finish(download, error: error) }
    private func finish(_ download: WKDownload, error: Error?) {
        let key = ObjectIdentifier(download)
        guard activeDownloads.removeValue(forKey: key) != nil else { return }
        let partial = destinations.removeValue(forKey: key)
        defer {
            if let partial { try? FileManager.default.removeItem(at: partial.deletingLastPathComponent()) }
        }
        if let error { notify("Download failed", error.localizedDescription); return }
        guard let partial else { notify("Download failed", "No downloaded file was received."); return }
        do {
            let destination = DownloadFiles.uniqueURL(in: downloadsDirectory, name: partial.lastPathComponent)
            try FileManager.default.moveItem(at: partial, to: destination)
            NotificationCenter.default.post(name: FilesViewController.filesChanged, object: nil)
            notify("Download complete", destination.lastPathComponent)
        } catch { notify("Could not save download", error.localizedDescription) }
    }

    private func enqueueDialog(_ alert: UIAlertController) { pendingAlerts.append(alert); presentNextAlert() }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: frame.securityOrigin.host, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in completionHandler(); self?.scheduleNextAlert() })
        enqueueDialog(alert)
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: frame.securityOrigin.host, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in completionHandler(false); self?.scheduleNextAlert() })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in completionHandler(true); self?.scheduleNextAlert() })
        enqueueDialog(alert)
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: frame.securityOrigin.host, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in completionHandler(nil); self?.scheduleNextAlert() })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self, weak alert] _ in completionHandler(alert?.textFields?.first?.text); self?.scheduleNextAlert() })
        enqueueDialog(alert)
    }
}
