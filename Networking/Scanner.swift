//
//  Scanner.swift
//  Altid - discover services on the local network
//
//  Created by halfwit on 2024-01-03.
//

import Network

var sharedBrowser: Scanner?

protocol ScannerDelegate: AnyObject {
    func refreshResults(results: Set<NWBrowser.Result>)
    func displayBrowseError(_ error: NWError)
}

class Scanner {
    weak var delegate: ScannerDelegate?
    var browser: NWBrowser?

    // Create a browsing object with a delegate.
    init(delegate: ScannerDelegate) {
        self.delegate = delegate
        startBrowsing()
    }

    // Start browsing for services.
    func startBrowsing() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_altid._tcp", domain: nil), using: parameters)
        self.browser = browser
        browser.stateUpdateHandler = { newState in
            switch newState {
            case .failed(let error):
                if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                    print("Browser failed with \(error), restarting")
                    browser.cancel()
                    self.startBrowsing()
                } else {
                    print("Browser failed with \(error), stopping")
                    self.delegate?.displayBrowseError(error)
                    browser.cancel()
                }
            case .ready:
                self.delegate?.refreshResults(results: browser.browseResults)
            case .cancelled:
                sharedBrowser = nil
                self.delegate?.refreshResults(results: Set())
            default:
                break
            }
        }

        // When the list of discovered endpoints changes, refresh the delegate.
        browser.browseResultsChangedHandler = { results, changes in
            self.delegate?.refreshResults(results: results)
        }

        // Start browsing and ask for updates on the main queue.
        browser.start(queue: .main)
    }
}
