//
//  DownloadManager.swift
//  DownloadUnzip
//
//  Created by Andrey on 10/10/19.
//  Copyright © 2019 Gramercy Tech. All rights reserved.
//

import Foundation
import Zip

class DownloadManager: NSObject {
    static var shared = DownloadManager()
    typealias ProgressHandler = (Float?, Error?) -> ()

    var unzipProgress: ProgressHandler?
    var downloadProgress: ProgressHandler? {
        didSet {
            if downloadProgress != nil {
                let _ = activate()
            }
        }
    }
    

    var session: URLSession {
        get {
            let config = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).background")
            // Warning: If an URLSession still exists from a previous download, it doesn't create
            // a new URLSession object but returns the existing one with the old delegate object attached!
            return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
        }
    }
    
    func activate() -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).background")

        // Warning: If an URLSession still exists from a previous download, it doesn't create a new URLSession object but returns the existing one with the old delegate object attached!
        return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    }
}


extension DownloadManager: URLSessionDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            if let downloadProgress = downloadProgress {
                calculateProgress(session: session, completionHandler: downloadProgress)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("📦 Task completed: \(task.originalRequest?.url!), error: \(String(describing: error))")
        downloadProgress?(nil, error)
    }
    
//    private func calculateProgress(session : URLSession, completionHandler : @escaping (Float, String?) -> ()) {
//        session.getTasksWithCompletionHandler { (tasks, uploads, downloads) in
//            let progress = downloads.map({ (task) -> Float in
//                if task.countOfBytesExpectedToReceive > 0 {
//                    return Float(task.countOfBytesReceived) / Float(task.countOfBytesExpectedToReceive)
//                } else {
//                    return 0.0
//                }
//            })
//            completionHandler(progress.reduce(0.0, +), nil)
//        }
//    }
    
    private func calculateProgress(session : URLSession, completionHandler : @escaping (Float, Error?) -> ()) {
        session.getTasksWithCompletionHandler { (tasks, uploads, downloads) in
            let bytesReceived = downloads.map { $0.countOfBytesReceived }.reduce(0, +)
            let bytesExpectedToReceive = downloads.map { $0.countOfBytesExpectedToReceive }.reduce(0, +)
            let progress = bytesExpectedToReceive > 0 ? Float(bytesReceived) / Float(bytesExpectedToReceive) : 0.0
            completionHandler(progress, nil)
        }
    }
}


extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("📦 Download completed: \(location)")
        
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
            print(error.localizedDescription)
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
                print("🗄 Remove Error: \(error)")
                self.unzipProgress?(nil, error)
            }
        }
        
        // Attempt to unzip
        do {
            print("🗜 Attempting to unzip: \(filePath.path)")
            let unzipDirectory = try Zip.quickUnzipFile(filePath, progress: { progress in
                self.unzipProgress?(Float(progress), nil)
            })
            print("🗜 Unzipped successfuly to: \(unzipDirectory)")
        } catch {
            print("🗜 Unzip Error: \(error)")
            self.unzipProgress?(nil, error)
        }
        
        // Remove downloaded zip file
        if (fileManager.fileExists(atPath: filePath.path)) {
            do {
                print("🗄 Attempting to remove: \(filePath.path)")
                try FileManager.default.removeItem(at: filePath)
            } catch {
                print("🗄 Remove Error: \(error)")
                self.unzipProgress?(nil, error)
            }
        }
        
        listDocuments(directoryPath: documentsDirectory)
    }
    
    private func listDocuments(directoryPath: URL) {
        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: nil, options: [])
            print("--- Documents directory:")
            for item in directoryContents {
                print("🗂 \(item.path)")
            }
            print("---")
        } catch {
            print("🗂 Display Error: \(error)")
        }
    }
}
