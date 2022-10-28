//
//  FileDownloader.swift
//  AR-TestTask
//
//  Created by MacBook on 27.10.2022.
//

import Foundation

class Downloader {
    open class func load(URL: URL, completion: @escaping (String?, Error?) -> Void) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        let task = session.dataTask(with: URL) { data, response, error in
            guard error == nil else {
                print(error.unsafelyUnwrapped.localizedDescription)
                return
            }

            guard let data = data else { return }

            save(data: data, to: URL, completion: completion)
        }

        task.resume()
    }

    class func save(data: Data, to url: URL, completion: (String?, Error?) -> Void) {
        let savePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationPath = savePath.appendingPathComponent(url.lastPathComponent)

        if FileManager().fileExists(atPath: destinationPath.path) {
            print("File exists")
            completion(destinationPath.path, NSError(domain: "Exist", code: 500))
        } else {
            do {
                try data.write(to: destinationPath, options: .atomic)
                completion(destinationPath.path, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
}
