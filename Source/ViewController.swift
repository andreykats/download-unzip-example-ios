//
//  ViewController.swift
//  DownloadUnzip
//
//  Created by Andrey on 10/10/19.
//  Copyright © 2019 Gramercy Tech. All rights reserved.
//

import UIKit
import Zip

class ViewController: UIViewController {
    var alertView: UIAlertController?
    var progressView: UIProgressView?

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        view.backgroundColor = .white
        setupButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("viewWillDisappear")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("viewDidDisappear")
    }
    
    @objc func appMovedToBackground() {
        print("App moved to background!")
    }
    
    @objc func appMovedToForeground() {
        print("App moved to Foreground!")
    }
    
    func setupButton() {
        let view = UIButton()
        view.backgroundColor = .darkGray
        view.setTitle("Download", for: .normal)
        view.setTitleColor(.white, for: .normal)
        view.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchUpInside)
        self.view.addSubview(view)
        
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 50).isActive = true
        view.widthAnchor.constraint(equalToConstant: 100).isActive = true
        view.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        view.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
    }
    
    @objc func buttonPressed(_ sender: UIButton) {
//        downloadThere()
        downloadHere()
    }
    
    func showAlert(msg: String, title: String, downloadTask: URLSessionDownloadTask? = nil, progressBar: Bool = false) {
        if let currentAlert = self.presentedViewController as? UIAlertController {
            DispatchQueue.main.async { self.progressView?.isHidden = progressBar ? false : true }
            currentAlert.title = title
            currentAlert.message = msg
            return
        }
        
        progressView = UIProgressView()
        progressView?.isHidden = progressBar ? false : true
        
        alertView = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        alertView?.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { action in
            downloadTask?.cancel()
            self.dismiss(animated: true)
        }))
        
        present(alertView!, animated: true, completion: {
            let margin: CGFloat = 20.0
            self.progressView?.frame = CGRect(x: margin, y: 68.0, width: self.alertView!.view.frame.width - margin * 2.0 , height: 2.0)
            self.progressView?.progress = 0.0
            self.progressView?.tintColor = self.view.tintColor
            self.progressView?.trackTintColor = .darkGray
            self.alertView?.view.addSubview(self.progressView!)
        })
    }

    func downloadThere() {
        print("Download")
        // https://www.ralfebert.de/ios-examples/networking/urlsession-background-downloads/
        
        let url = URL(string: "https://file-examples.com/wp-content/uploads/2017/02/zip_10MB.zip")!
        
        let task = DownloadManager.shared.activate().downloadTask(with: url)
        showAlert(msg: "Preparing to download files...", title: "Please wait", downloadTask: task)
        DownloadManager.shared.downloadProgress = { progress, error in
            if let error = error {
                DispatchQueue.main.async {
                    print(error.localizedDescription)
                    self.alertView?.dismiss(animated: true, completion: nil)
                    self.showAlert(msg: error.localizedDescription, title: "Error")
                }
            }
            
            guard let progress = progress else { return }
            OperationQueue.main.addOperation {
                print(progress)
                self.progressView?.progress = progress
                self.alertView?.message = "Downloading files \(Int(progress * 100))%"
                if progress == 1 { self.alertView?.message = "Preparing to unzip files..." }
            }
        }
        
        DownloadManager.shared.unzipProgress = { progress, error in
            if let error = error {
                DispatchQueue.main.async {
                    print(error.localizedDescription)
                    self.alertView?.dismiss(animated: true, completion: nil)
                    self.showAlert(msg: error.localizedDescription, title: "Error")
                }
            }
            
            guard let progress = progress else { return }
            OperationQueue.main.addOperation {
                print(progress)
                self.progressView?.progress = progress
                self.alertView?.message = "Unzipping files \(Int(progress * 100))%"
                if progress == 1 {
                    self.alertView?.dismiss(animated: true, completion: {
                        DownloadManager.shared.downloadProgress = nil
                        DownloadManager.shared.unzipProgress = nil
                    print("Alert dismissed")
                })}
            }
        }
        
        task.resume()
    }
    
    
    func downloadHere() {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        
        let url = URL(string: "https://file-examples.com/wp-content/uploads/2017/02/zip_10MB.zip")!
        
        let task = session.downloadTask(with: url)
        showAlert(msg: "Preparing to download files...", title: "Please wait", downloadTask: task)
        task.resume()
    }
}


extension ViewController: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("📦 Task error: \(task), error: \(error.localizedDescription)")
            if error.localizedDescription == "cancelled" {
                // Race condition workaround
                DispatchQueue.main.async { self.alertView?.dismiss(animated: false, completion: nil) }
                return
            }
            DispatchQueue.main.async { self.showAlert(msg: error.localizedDescription, title: "Error") }
        }
    }
}


extension ViewController: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            print("📦 Download task: \(downloadTask) \(progress)")
            DispatchQueue.main.async {
                self.progressView?.progress = progress
                self.showAlert(msg: "Downloading files \(Int(progress * 100))%", title: "Please wait", progressBar: true)
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("📦 Download completed: \(location)")
        DispatchQueue.main.async { self.showAlert(msg: "Preparing to unzip files...", title: "Please wait")  }
        
        do {
            let downloadedData = try Data(contentsOf: location)
            print("🗄 File appears to be intact")
            let url = downloadTask.originalRequest?.url
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for:.documentDirectory, in: .userDomainMask)[0]
            let destinationPath = documentsDirectory.appendingPathComponent(url!.lastPathComponent)

            fileManager.createFile(atPath: destinationPath.path, contents: downloadedData, attributes: nil)
            if fileManager.fileExists(atPath: destinationPath.path) {
                print("🗄 Downloaded file transfered to documents directory")
                self.listDocuments(directoryPath: documentsDirectory)
                self.unzip(filePath: destinationPath)
            }
        } catch {
            print("🗄 File Error: \(error.localizedDescription)")
            DispatchQueue.main.async { self.showAlert(msg: error.localizedDescription, title: "Error") }
        }
    }
    
    private func unzip(filePath: URL) {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for:.documentDirectory, in: .userDomainMask)[0]
        let directoryName = filePath.deletingPathExtension()
        
        // Remove existing directory before extraction
        if (fileManager.fileExists(atPath: directoryName.path)) {
            do {
                print("🗄 Attempting to remove existing: \(directoryName.path)")
                try FileManager.default.removeItem(at: directoryName)
            } catch {
                print("🗄 Remove Error: \(error.localizedDescription)")
                DispatchQueue.main.async { self.showAlert(msg: error.localizedDescription, title: "Error") }
            }
        }
        
        // Attempt to unzip
        do {
            print("🗜 Attempting to unzip: \(filePath.path)")
            let unzipDirectory = try Zip.quickUnzipFile(filePath, progress: { progress in
                print(progress)
                DispatchQueue.main.async {
                    self.progressView?.progress = Float(progress)
                    self.showAlert(msg: "Unzipping files \(Int(progress * 100))%", title: "Please wait", progressBar: true)
                }
            })
            print("🗜 Unzipped successfuly to: \(unzipDirectory)")
        } catch {
            print("🗜 Unzip Error: \(error.localizedDescription)")
            DispatchQueue.main.async { self.showAlert(msg: error.localizedDescription, title: "Error") }
        }
        
        // Remove downloaded zip file
        if (fileManager.fileExists(atPath: filePath.path)) {
            do {
                print("🗄 Attempting to remove: \(filePath.path)")
                try FileManager.default.removeItem(at: filePath)
            } catch {
                print("🗄 Remove Error: \(error.localizedDescription)")
                DispatchQueue.main.async { self.showAlert(msg: error.localizedDescription, title: "Error") }
            }
        }
        
        listDocuments(directoryPath: documentsDirectory)
    }
    
    private func listDocuments(directoryPath: URL) {
        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: nil, options: [])
            print("🗂 Documents directory:")
            for item in directoryContents {
                print("🗂 \(item.path)")
            }
        } catch {
            print("🗂 File Error: \(error.localizedDescription)")
            DispatchQueue.main.async { self.showAlert(msg: error.localizedDescription, title: "Error") }
        }
    }
}
