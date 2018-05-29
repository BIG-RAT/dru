//
//  PreviewController.swift
//  dru
//
//  Created by Leslie Helou on 8/9/17.
//  Copyright © 2017 jamf. All rights reserved.
//

import Cocoa
import Foundation
import WebKit

class PreviewController: NSViewController, URLSessionDelegate {

    @IBOutlet weak var preview_WebView: WKWebView!
    var myQ = DispatchQueue(label: "com.jamf.current")
    
    @IBOutlet weak var webSpinner_ProgInd: NSProgressIndicator!
    
    var newValues = String()
    var prevAllRecordValuesArray = [[String:String]]()
    var prevLowercaseEaHeaderArray = [String]()    // array of (lowercase) extension attributes to update
    var currentRecord           = 0
    
    var previewPage             = ""
    var previewPage2            = ""
    
    var previewJssUrl           = ""
    var previewJamfCreds        = ""
    var previewDeviceType       = ""
    var previewRecordID         = ""
    
    var currentValuesDict       = [String:String]()
    var generalDict             = [String:Any]()
    var locationDict            = [String:Any]()
    var extAttributesDict       = [Dictionary<String, Any>]()
    var currentEaValuesDict     = [String:String]()
    var lowercaseEaValuesDict   = [String:String]()   // array of EA names [lowercase name:original name]
    
    var currentName             = ""
    var currentSerialnumber     = ""
    var currentDept             = ""
    
    @IBAction func prevRecord_Button(_ sender: Any) {
        currentRecord -= 1
        currentRecord = (currentRecord < 0 ? prevAllRecordValuesArray.count-1:currentRecord)
        generatePage(recordNumber: currentRecord)
    }
    
    @IBAction func nextRecord_Button(_ sender: Any) {
        webSpinner_ProgInd.startAnimation(Any?.self)
        currentRecord += 1
        currentRecord = (currentRecord > prevAllRecordValuesArray.count-1 ? 0:currentRecord)
        generatePage(recordNumber: currentRecord)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webSpinner_ProgInd.startAnimation(Any.self)
        generatePage(recordNumber: 0)
    }
    
    func generatePage(recordNumber: Int) {
        print("present values: \(prevAllRecordValuesArray[recordNumber])")
        let theDevice = "\(prevAllRecordValuesArray[recordNumber]["deviceName"] ?? "")"
        let serialNumber = "\(prevAllRecordValuesArray[recordNumber]["serial_number"] ?? "")"
        let assetTag = "\(prevAllRecordValuesArray[recordNumber]["asset_tag"] ?? "")"
        let site = "\(prevAllRecordValuesArray[recordNumber]["siteName"] ?? "")"
        let username = "\(prevAllRecordValuesArray[recordNumber]["username"] ?? "")"
        let realname = "\(prevAllRecordValuesArray[recordNumber]["real_name"] ?? "")"
        let emailAddress = "\(prevAllRecordValuesArray[recordNumber]["email_address"] ?? "")"
        let phoneNumber = "\(prevAllRecordValuesArray[recordNumber]["phone_number"] ?? "")"
        let position = "\(prevAllRecordValuesArray[recordNumber]["position"] ?? "")"
        let department = "\(prevAllRecordValuesArray[recordNumber]["department"] ?? "")"
        let building = "\(prevAllRecordValuesArray[recordNumber]["building"] ?? "")"

        getEndpoint(id: serialNumber) {
            (result: Dictionary) in
            print("result: \(result)")
            let existingValuesDict = result
            print("bundle path: \(Bundle.main.bundlePath)")
            self.previewPage = "<!DOCTYPE html>" +
                "<html>" +
                "<head>" +
                "<style>" +
                "body { background-color: #FFFFFF; }" +
                "table, th, td {" +
                "border: 0px solid black;padding-right: 3px;" +
                "}" +
                "#table1 { border-collapse: collapse; table-layout: fixed; margin: auto; }" +
                "th, td { border-bottom: 1px solid #ddd; }" +
//                "tr:nth-child(even) { background-color: #FFFFFF; }" +
                "</style>" +
                "</head>" +
                "<body>" +
                "<table id='table1'>" +
                "<tr>" +
                "<th style='width: 26%'></th>" +
                "<th style='text-align:left; width: 37%'>Current</th>" +
                "<th style='text-align:left; width: 37%'>Update</th>" +
                "</tr>" +
                "<tr>" +
                "<td style=\"text-align:right\">Device Name:</td>" +
                
                "<td>\(existingValuesDict["deviceName"] ?? "")</td>" +
                "<td>\(theDevice)</td>" +
                "</tr>" +
                self.addTableRow(attribute: "Serial Number", existing: "\(existingValuesDict["serial_number"] ?? "")", update: "\(serialNumber)") +
                self.addTableRow(attribute: "Asset Tag", existing: "\(existingValuesDict["asset_tag"] ?? "")", update: "\(assetTag)") +
                "<tr>" +
                "<td style=\"text-align:right\">Site:</td>" +
                
                "<td>\(existingValuesDict["siteName"] ?? "")</td>" +
                "<td>\(site)</td>" +
                "</tr>" +
                self.addTableRow(attribute: "Username", existing: "\(existingValuesDict["username"] ?? "")", update: "\(username)") +
                self.addTableRow(attribute: "Realname", existing: "\(existingValuesDict["real_name"] ?? "")", update: "\(realname)") +
                self.addTableRow(attribute: "Email Address", existing: "\(existingValuesDict["email_address"] ?? "")", update: "\(emailAddress)") +
                self.addTableRow(attribute: "Phone Number", existing: "\(existingValuesDict["phone_number"] ?? "")", update: "\(phoneNumber)") +
                self.addTableRow(attribute: "Position", existing: "\(existingValuesDict["position"] ?? "")", update: "\(position)") +
                self.addTableRow(attribute: "Building", existing: "\(existingValuesDict["building"] ?? "")", update: "\(building)") +
                "<tr>" +
                "<td style=\"text-align:right\">Department:</td>" +
                
                "<td>\(existingValuesDict["department"] ?? "")</td>" +
                "<td>\(department)</td>" +
                "</tr>" +
                self.addEaToTable(updateValues: self.prevAllRecordValuesArray[recordNumber]) +
//                "<tr>" +
//                "<td style=\"text-align:left\">Extension Attributes</td>" +
//                
//                
//                
//                "</tr>" +
                "</table>" +
                "</body>" +
            "</html>"
//        print("new test: \(previewPage)")
            self.preview_WebView.loadHTMLString(self.previewPage, baseURL: nil)
            self.webSpinner_ProgInd.stopAnimation(Any?.self)
            return [:]
        }
        
    }
    
    func getEndpoint(id: String, completion: @escaping (Dictionary<String, Any>) -> Dictionary<String, Any>) {
        let safeCharSet = CharacterSet.alphanumerics
        let uniqueID = id.addingPercentEncoding(withAllowedCharacters: safeCharSet)!
        let semaphore = DispatchSemaphore(value: 0)
        myQ.async {
            var serverUrl = "\(self.previewJssUrl)/JSSResource/\(self.previewDeviceType)/\(self.previewRecordID)/\(uniqueID)"
            serverUrl = serverUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
//            print("serverUrl: \(serverUrl)")
            
            let serverEncodedURL = NSURL(string: serverUrl)
            let serverRequest = NSMutableURLRequest(url: serverEncodedURL! as URL)
            print("serverRequest: \(serverRequest)")
            serverRequest.httpMethod = "GET"
            let serverConf = URLSessionConfiguration.default
            serverConf.httpAdditionalHeaders = ["Authorization" : "Basic \(self.previewJamfCreds)", "Content-Type" : "application/json", "Accept" : "application/json"]
            let serverSession = Foundation.URLSession(configuration: serverConf, delegate: self, delegateQueue: OperationQueue.main)
            let task = serverSession.dataTask(with: serverRequest as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                if let httpResponse = response as? HTTPURLResponse {
//                  print("httpResponse: \(String(describing: response))")
                    do {
                        let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                        if let endpointJSON = json as? [String: Any] {
//                          print("endpointJSON: \(endpointJSON)")
                            switch self.previewDeviceType {
                            case "computers":
                                print("computer case")
                                let fullRecord = endpointJSON["computer"] as! [String:Any]
                                // general info
                                self.generalDict = fullRecord["general"] as! [String:Any]
                                self.currentValuesDict["deviceName"] = self.generalDict["name"] as? String
                                self.currentValuesDict["mac_address"] = self.generalDict["mac_address"] as? String
                                self.currentValuesDict["serial_number"] = self.generalDict["serial_number"] as? String
                                self.currentValuesDict["asset_tag"] = self.generalDict["asset_tag"] as? String
                                let currentSiteDict = self.generalDict["site"] as! [String:Any]
                                self.currentValuesDict["siteName"] = currentSiteDict["name"] as? String
                                // location info
                                self.locationDict = fullRecord["location"] as! [String:Any]
                                self.currentValuesDict["username"] = self.locationDict["username"] as? String
                                self.currentValuesDict["real_name"] = self.locationDict["real_name"] as? String
                                self.currentValuesDict["email_address"] = self.locationDict["email_address"] as? String
                                self.currentValuesDict["position"] = self.locationDict["position"] as? String
                                self.currentValuesDict["phone_number"] = self.locationDict["phone_number"] as? String
                                self.currentValuesDict["department"] = self.locationDict["department"] as? String
                                self.currentValuesDict["building"] = self.locationDict["building"] as? String
                                self.currentValuesDict["room"] = self.locationDict["room"] as? String
                                // extension attributes
                                self.extAttributesDict = fullRecord["extension_attributes"] as! [Dictionary<String, Any>]
//                                print("\nEAs: \(self.extAttributesDict.count)")
//                                print("EAs: \(self.extAttributesDict)")
                                for i in (0..<self.extAttributesDict.count) {
                                    let EaName = self.extAttributesDict[i]["name"] as! String
                                    let EaValue = self.extAttributesDict[i]["value"]
                                    if self.prevLowercaseEaHeaderArray.index(of: (EaName.lowercased())) != nil {
                                        self.currentEaValuesDict[EaName] = "\(EaValue ?? "")"
                                    }
//                                    self.lowercaseEaValuesDict[EaName.lowercased()] = EaName
                                }


                            // default is iOS
                            default:
                                print("iOS case")
                                let fullRecord = endpointJSON["mobile_device"] as! [String:Any]
                                // general info
                                self.generalDict = fullRecord["general"] as! [String:Any]
                                self.currentValuesDict["deviceName"] = self.generalDict["name"] as? String
                                self.currentValuesDict["wifi_mac_address"] = self.generalDict["wifi_mac_address"] as? String
                                self.currentValuesDict["serial_number"] = self.generalDict["serial_number"] as? String
                                self.currentValuesDict["asset_tag"] = self.generalDict["asset_tag"] as? String
                                let currentSiteDict = self.generalDict["site"] as! [String:Any]
                                self.currentValuesDict["siteName"] = currentSiteDict["name"] as? String
                                // location info
                                self.locationDict = fullRecord["location"] as! [String:Any]
                                self.currentValuesDict["username"] = self.locationDict["username"] as? String
                                self.currentValuesDict["real_name"] = self.locationDict["real_name"] as? String
                                self.currentValuesDict["email_address"] = self.locationDict["email_address"] as? String
                                self.currentValuesDict["position"] = self.locationDict["position"] as? String
                                self.currentValuesDict["phone_number"] = self.locationDict["phone_number"] as? String
                                self.currentValuesDict["department"] = self.locationDict["department"] as? String
                                self.currentValuesDict["building"] = self.locationDict["building"] as? String
                                self.currentValuesDict["room"] = self.locationDict["room"] as? String
                                // extension attributes
                                self.extAttributesDict = fullRecord["extension_attributes"] as! [Dictionary<String, Any>]
//                                print("\nEAs: \(self.extAttributesDict.count)")
//                                print("EAs: \(self.extAttributesDict)")
                                for i in (0..<self.extAttributesDict.count) {
                                    let EaName = self.extAttributesDict[i]["name"] as! String
                                    let EaValue = self.extAttributesDict[i]["value"]
                                    if self.prevLowercaseEaHeaderArray.index(of: (EaName.lowercased())) != nil {
                                        self.currentEaValuesDict[EaName] = "\(EaValue ?? "")"
                                    }
//                                    self.lowercaseEaValuesDict[EaName.lowercased()] = EaName
                                }
                            }   // switch - end
                        }   // if let serverEndpointJSON - end
                        
                    } catch {
                        print("[- debug -] Existing endpoints: error serializing JSON: \(error)\n")
                    }   // end do/catch
                    
                    if httpResponse.statusCode >= 199 && httpResponse.statusCode <= 299 {
                        //print(httpResponse.statusCode)
                        
                        completion(self.currentValuesDict)
                    } else {
                        // something went wrong
                        print("status code: \(httpResponse.statusCode)")
                        completion([:])
                        
                    }   // if httpResponse/else - end
                }   // if let httpResponse - end
                semaphore.signal()
                if error != nil {
                }
            })  // let task = destSession - end
            //print("GET")
            task.resume()
            //semaphore.wait()
        }   // theOpQ - end
//        return "some XML"
    }
    
    func addEaToTable(updateValues: Dictionary<String, Any>) -> String {
        var EaString = ""
        if currentEaValuesDict.count > 0 {
            EaString = "<tr>" +
                    "<th style=\"text-align:right\">Extension Attributes</th>" +
                    "</tr>"
            for (key, value) in currentEaValuesDict {
                let _key = "_" + key.lowercased()
                let newLine = "<tr>" +
                    "<td style=\"text-align:right\">" + key + ":</td>" +
                    
                    "<td>\(value)</td>" +
                    "<td>\(updateValues[_key] ?? "")</td>" +
                "</tr>"
                EaString.append(newLine)
            }
        }
        return EaString
    }

    func addTableRow(attribute: String, existing: String, update: String) -> String {
        var currentRow = ""
        if !(existing == "" && update == "") {
        currentRow = "<tr>" +
            "<td style=\"text-align:right\">\(attribute):</td>" +
            "<td>\(existing)</td>" +
            "\((existing == update) ? "<td>\(update)</td>":"<td style='color:red'>\(update)</td>")" +
            "</tr>"
        }
        
        return "\(currentRow)"
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}