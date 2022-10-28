//
//  Network.swift
//  AR-TestTask
//
//  Created by MacBook on 27.10.2022.
//

import Foundation

func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
    URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
}
