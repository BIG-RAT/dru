//
//  TokenDelegate.swift
//  Last Run
//
//  Created by Leslie Helou on 11/26/21
//

import Cocoa

class TokenDelegate: NSObject, URLSessionDelegate {
    
    var renewQ = DispatchQueue(label: "com.token_refreshQ", qos: DispatchQoS.background)   // running background process for refreshing token
    
    let userDefaults = UserDefaults.standard
    
    func getToken(whichServer: String, serverUrl: String, base64creds: String, completion: @escaping (_ authResult: (Int,String)) -> Void) {
       
        let forceBasicAuth = (userDefaults.integer(forKey: "forceBasicAuth") == 1) ? true:false
        WriteToLog().message(stringOfText: "[TokenDelegate.getToken] Force basic authentication on \(serverUrl): \(forceBasicAuth)\n")
       
        URLCache.shared.removeAllCachedResponses()
                
        var tokenUrlString = "\(serverUrl)/api/v1/auth/token"
        tokenUrlString     = tokenUrlString.replacingOccurrences(of: "//api", with: "/api")
    //        print("\(tokenUrlString)")
        
        let tokenUrl       = URL(string: "\(tokenUrlString)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: tokenUrl!)
        request.httpMethod = "POST"
        
        let forWhat = (whichServer == "source") ? "sourceTokenAge":"destTokenAge"
        let (_, minutesOld, _) = timeDiff(forWhat: forWhat)
//        print("[JamfPro] \(whichServer) tokenAge: \(minutesOld) minutes")
        if !(jamfProServer.validToken[whichServer] ?? false) || (jamfProServer.base64Creds[whichServer] != base64creds) || (minutesOld > 25) {
            WriteToLog().message(stringOfText: "[TokenDelegate.getToken] Attempting to retrieve token from \(String(describing: tokenUrl!)) for version look-up\n")
            
            configuration.httpAdditionalHeaders = ["Authorization" : "Basic \(base64creds)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : appInfo.userAgentHeader]
            let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
            let task = session.dataTask(with: request as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                session.finishTasksAndInvalidate()
                if let httpResponse = response as? HTTPURLResponse {
                    if httpSuccess.contains(httpResponse.statusCode) {
                        let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                        if let endpointJSON = json! as? [String: Any], let _ = endpointJSON["token"], let _ = endpointJSON["expires"] {
                            jamfProServer.validToken[whichServer]  = true
                            jamfProServer.authCreds[whichServer]   = endpointJSON["token"] as? String
                            jamfProServer.authExpires[whichServer] = "\(endpointJSON["expires"] ?? "")"
                            jamfProServer.authType[whichServer]    = "Bearer"
                            jamfProServer.base64Creds[whichServer] = base64creds
                            
                            jamfProServer.tokenCreated[whichServer] = Date()
                            
    //                      if LogLevel.debug { WriteToLog().message(stringOfText: "[TokenDelegate.getToken] Retrieved token: \(token)") }
    //                      print("[JamfPro] result of token request: \(endpointJSON)")
                            WriteToLog().message(stringOfText: "[TokenDelegate.getToken] new token created for \(serverUrl)\n")
                            
                            if jamfProServer.version[whichServer] == "" {
                                // get Jamf Pro version - start
                                self.getVersion(serverUrl: serverUrl, endpoint: "jamf-pro-version", apiData: [:], id: "", token: jamfProServer.authCreds[whichServer]!, method: "GET") {
                                    (result: [String:Any]) in
                                    if let versionString = result["version"] as? String {
                                        
                                        if versionString != "" {
                                            WriteToLog().message(stringOfText: "[TokenDelegate.getVersion] Jamf Pro Version: \(versionString)\n")
                                            jamfProServer.version[whichServer] = versionString
                                            let tmpArray = versionString.components(separatedBy: ".")
                                            if tmpArray.count > 2 {
                                                for i in 0...2 {
                                                    switch i {
                                                    case 0:
                                                        jamfProServer.majorVersion = Int(tmpArray[i]) ?? 0
                                                    case 1:
                                                        jamfProServer.minorVersion = Int(tmpArray[i]) ?? 0
                                                    case 2:
                                                        let tmp = tmpArray[i].components(separatedBy: "-")
                                                        jamfProServer.patchVersion = Int(tmp[0]) ?? 0
                                                        if tmp.count > 1 {
                                                            jamfProServer.build = tmp[1]
                                                        }
                                                    default:
                                                        break
                                                    }
                                                }
                                                if ( jamfProServer.majorVersion > 9 && jamfProServer.minorVersion > 34 ) && !forceBasicAuth {
                                                    jamfProServer.authType[whichServer] = "Bearer"
                                                    jamfProServer.validToken[whichServer] = true
                                                    WriteToLog().message(stringOfText: "[TokenDelegate.getVersion] \(serverUrl) set to use Bearer Token\n")
                                                    
                                                } else {
                                                    jamfProServer.authType[whichServer]  = "Basic"
                                                    jamfProServer.validToken[whichServer] = false
                                                    jamfProServer.authCreds[whichServer] = base64creds
                                                    WriteToLog().message(stringOfText: "[TokenDelegate.getVersion] \(serverUrl) set to use Basic Authentication\n")
                                                }
                                                if jamfProServer.authType[whichServer] == "Bearer" {
                                                    self.refresh(server: serverUrl, whichServer: whichServer, b64Creds: jamfProServer.base64Creds[whichServer]!)
                                                }
                                                completion((200, "success"))
                                                return
                                            }
                                        }
                                    } else {   // if let versionString - end
                                        WriteToLog().message(stringOfText: "[TokenDelegate.getToken] failed to get version information from \(String(describing: serverUrl))\n")
                                        jamfProServer.validToken[whichServer]  = false
                                        _ = Alert().display(header: "Attention", message: "Failed to get version information from \(String(describing: serverUrl))")
                                        completion((httpResponse.statusCode, "failed"))
                                        return
                                    }
                                }
                                // get Jamf Pro version - end
                            } else {
                                if jamfProServer.authType[whichServer] == "Bearer" {
                                    WriteToLog().message(stringOfText: "[TokenDelegate.getVersion] call token refresh process for \(serverUrl)\n")
                                    self.refresh(server: serverUrl, whichServer: whichServer, b64Creds: jamfProServer.base64Creds[whichServer]!)
                                }
                                completion((200, "success"))
                                return
                            }
                        } else {    // if let endpointJSON error
                            WriteToLog().message(stringOfText: "[TokenDelegate.getToken] JSON error.\n\(String(describing: json))\n")
                            jamfProServer.validToken[whichServer]  = false
                            completion((httpResponse.statusCode, "failed"))
                            return
                        }
                    } else {    // if httpResponse.statusCode <200 or >299
                        WriteToLog().message(stringOfText: "[TokenDelegate.getToken] Failed to authenticate to \(serverUrl).  Response error: \(httpResponse.statusCode).\n")

                        _ = Alert().display(header: "\(serverUrl)", message: "Failed to authenticate to \(serverUrl). \nStatus Code: \(httpResponse.statusCode)")
                        
                        jamfProServer.validToken[whichServer]  = false
                        completion((httpResponse.statusCode, "failed"))
                        return
                    }
                } else {
                    _ = Alert().display(header: "\(serverUrl)", message: "Failed to connect. \nUnknown error, verify url and port.")
                    WriteToLog().message(stringOfText: "[TokenDelegate.getToken] token response error from \(serverUrl).  Verify url and port.\n")
                    jamfProServer.validToken[whichServer]  = false
                    completion((0, "failed"))
                    return
                }
            })
            task.resume()
        } else {
            WriteToLog().message(stringOfText: "[TokenDelegate.getToken] Use existing token from \(String(describing: tokenUrl!))\n")
            completion((200, "success"))
            return
        }
        
    }
    
    func getVersion(serverUrl: String, endpoint: String, apiData: [String:Any], id: String, token: String, method: String, completion: @escaping (_ returnedJSON: [String: Any]) -> Void) {
        
        if method.lowercased() == "skip" {
            if LogLevel.debug { WriteToLog().message(stringOfText: "[Jpapi.action] skipping \(endpoint) endpoint with id \(id).\n") }
            let JPAPI_result = (endpoint == "auth/invalidate-token") ? "no valid token":"failed"
            completion(["JPAPI_result":JPAPI_result, "JPAPI_response":000])
            return
        }
        
        URLCache.shared.removeAllCachedResponses()
        var path = ""

        switch endpoint {
        case  "buildings", "csa/token", "icon", "jamf-pro-version", "auth/invalidate-token":
            path = "v1/\(endpoint)"
        default:
            path = "v2/\(endpoint)"
        }

        var urlString = "\(serverUrl)/api/\(path)"
        urlString     = urlString.replacingOccurrences(of: "//api", with: "/api")
        if id != "" && id != "0" {
            urlString = urlString + "/\(id)"
        }
//        print("[Jpapi] urlString: \(urlString)")
        
        let url            = URL(string: "\(urlString)")
        let configuration  = URLSessionConfiguration.default
        var request        = URLRequest(url: url!)
        switch method.lowercased() {
        case "get":
            request.httpMethod = "GET"
        case "create", "post":
            request.httpMethod = "POST"
        default:
            request.httpMethod = "PUT"
        }
        
        if apiData.count > 0 {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: apiData, options: .prettyPrinted)
            } catch let error {
                print(error.localizedDescription)
            }
        }
        
        if LogLevel.debug { WriteToLog().message(stringOfText: "[Jpapi.action] Attempting \(method) on \(urlString).\n") }
//        print("[Jpapi.action] Attempting \(method) on \(urlString).")
        
        configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(token)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : appInfo.userAgentHeader]
        
        // sticky session
//        print("jpapi sticky session for \(serverUrl)")
        if jamfProServer.sessionCookie.count > 0 && jamfProServer.stickySession {
            URLSession.shared.configuration.httpCookieStorage!.setCookies(jamfProServer.sessionCookie, for: URL(string: serverUrl), mainDocumentURL: URL(string: serverUrl))
        }
        
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                    
//                    print("[jpapi] endpoint: \(endpoint)")

                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json as? [String:Any] {
                        if LogLevel.debug { WriteToLog().message(stringOfText: "[Jpapi.action] Data retrieved from \(urlString).\n") }
                        completion(endpointJSON)
                        return
                    } else {    // if let endpointJSON error
                        if httpResponse.statusCode == 204 && endpoint == "auth/invalidate-token" {
                            completion(["JPAPI_result":"token terminated", "JPAPI_response":httpResponse.statusCode])
                        } else {
                            if LogLevel.debug { WriteToLog().message(stringOfText: "[Jpapi.action] JSON error.  Returned data: \(String(describing: json))\n") }
                            completion(["JPAPI_result":"failed", "JPAPI_response":httpResponse.statusCode])
                        }
                        return
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                if LogLevel.debug { WriteToLog().message(stringOfText: "[TokenDelegate.getVersion] Response error: \(httpResponse.statusCode).\n") }
                    completion(["JPAPI_result":"failed", "JPAPI_method":request.httpMethod ?? method, "JPAPI_response":httpResponse.statusCode, "JPAPI_server":urlString, "JPAPI_token":token])
                    return
                }
            } else {
                if LogLevel.debug { WriteToLog().message(stringOfText: "[TokenDelegate.getVersion] GET response error.  Verify url and port.\n") }
                completion([:])
                return
            }
        })
        task.resume()
        
    }   // func getVersion - end
    
    func refresh(server: String, whichServer: String, b64Creds: String) {
//        if controller!.go_button.title == "Stop" {
        DispatchQueue.main.async { [self] in
            if runComplete {
                jamfProServer.validToken["source"]      = false
                jamfProServer.validToken["destination"] = false
                WriteToLog().message(stringOfText: "[TokenDelegate.refresh] terminated token refresh\n")
                return
            }
            WriteToLog().message(stringOfText: "[TokenDelegate.refresh] queue token refresh for \(server)\n")
            renewQ.async { [self] in
                sleep(refreshInterval)
                jamfProServer.validToken[whichServer] = false
                getToken(whichServer: whichServer, serverUrl: server, base64creds: jamfProServer.base64Creds[whichServer]!) {
                    (result: (Int, String)) in
//                    print("[JamfPro.refresh] returned: \(result)")
                }
            }
        }
    }
}
