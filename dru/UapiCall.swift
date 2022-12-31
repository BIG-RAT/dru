//
//  UapiCall.swift
//  dru
//
//  Created by Leslie Helou on 9/1/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Foundation

class UapiCall: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {
    
    let defaults = UserDefaults.standard
    var theUapiQ = OperationQueue() // create operation queue for API calls
    //    let jps      = Preferences().jamfServerUrl
    //    let b64user  = Preferences().username.data(using: .utf8)?.base64EncodedString() ?? ""
    //    let b64pass  = Preferences().password.data(using: .utf8)?.base64EncodedString() ?? ""
    
    
    func get(endpoint: String, completion: @escaping (_ notificationAlerts: [Dictionary<String,Any>]) -> Void) {
        
        let jps        = defaults.string(forKey:"jamfServerUrl") ?? ""
        let urlRegex   = try! NSRegularExpression(pattern: "http(.*?)://", options:.caseInsensitive)
        let serverFqdn = urlRegex.stringByReplacingMatches(in: jps, options: [], range: NSRange(0..<jps.utf16.count), withTemplate: "")
        
        URLCache.shared.removeAllCachedResponses()
        
        var workingUrlString = "\(jps)/uapi/\(endpoint)"
        workingUrlString     = workingUrlString.replacingOccurrences(of: "//uapi", with: "/uapi")
        
        self.theUapiQ.maxConcurrentOperationCount = 1
        
        self.theUapiQ.addOperation {
            URLCache.shared.removeAllCachedResponses()
            
            let encodedURL = URL(string: workingUrlString)
            let request = NSMutableURLRequest(url: encodedURL! as URL)
            
            let configuration  = URLSessionConfiguration.default
            request.httpMethod = "GET"
            
            configuration.httpAdditionalHeaders = ["Authorization" : "\(String(describing: jamfProServer.authType["source"]!)) \(String(describing: jamfProServer.authCreds["source"]!))", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : appInfo.userAgentHeader]
            let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
            
            let task = session.dataTask(with: request as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                        let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                        if let notificationsDictArray = json! as? [Dictionary<String, Any>] {
                            completion(notificationsDictArray)
                            return
                        } else {    // if let endpointJSON error
                            WriteToLog().message(stringOfText: "[UapiCall] get JSON error")
                            completion([])
                            return
                        }
                    } else {    // if httpResponse.statusCode <200 or >299
                        WriteToLog().message(stringOfText: "[UapiCall] get response error: \(httpResponse.statusCode)")
                        completion([])
                        return
                    }
                    
                } else {
                    WriteToLog().message(stringOfText: "[UapiCall.get] HTTP error")
                }
            })
            task.resume()
            
        }   // theUapiQ.addOperation - end
    }   // func get - end
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}
