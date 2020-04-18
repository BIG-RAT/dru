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
    @IBOutlet weak var whichRecord_TextField: NSTextField!
    @IBOutlet weak var goTo_TextField: NSTextField!
    
    let vc = ViewController()
    
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
    
    @IBAction func goTo_Action(_ sender: Any) {
        DispatchQueue.main.async {
            self.currentRecord = Int(self.goTo_TextField.stringValue) ?? 0
            if self.currentRecord > 0 && self.currentRecord <= self.prevAllRecordValuesArray.count {
                self.webSpinner_ProgInd.startAnimation(self)
                self.currentRecord -= 1
                self.generatePage(recordNumber: self.currentRecord)
                self.whichRecord_TextField.stringValue = "\(self.currentRecord+1) of \(self.prevAllRecordValuesArray.count)"
            }
        }
    }
    
    @IBAction func prevRecord_Button(_ sender: Any) {
        DispatchQueue.main.async {
            self.webSpinner_ProgInd.startAnimation(self)
            self.goTo_TextField.stringValue = ""
            self.currentRecord -= 1
            self.currentRecord = (self.currentRecord < 0 ? self.prevAllRecordValuesArray.count-1:self.currentRecord)
            self.generatePage(recordNumber: self.currentRecord)
            self.whichRecord_TextField.stringValue = "\(self.currentRecord+1) of \(self.prevAllRecordValuesArray.count)"
        }
    }
    
    @IBAction func nextRecord_Button(_ sender: Any) {
        DispatchQueue.main.async {
            self.webSpinner_ProgInd.startAnimation(self)
            self.goTo_TextField.stringValue = ""
            self.currentRecord += 1
            self.currentRecord = (self.currentRecord > self.prevAllRecordValuesArray.count-1 ? 0:self.currentRecord)
            self.generatePage(recordNumber: self.currentRecord)
            self.whichRecord_TextField.stringValue = "\(self.currentRecord+1) of \(self.prevAllRecordValuesArray.count)"
        }
    }
    
    @IBAction func update_Button(_ sender: Any) {
        
        DispatchQueue.main.async {
            self.webSpinner_ProgInd.startAnimation(self)
        }
        switch self.previewDeviceType {
        case "computers":
                let Uid = "\(prevAllRecordValuesArray[currentRecord]["serial_number"] ?? "")"
                let updateDeviceXml = "\(vc.generateXml(deviceType: "computers", localRecordDict: prevAllRecordValuesArray[currentRecord]))"
                print("currentRecord: \(currentRecord)\nvaluesDict: \(prevAllRecordValuesArray[currentRecord])")
                //                    print("generateXml: \(generateXml(localRecordDict: prevAllRecordValuesArray[currentRecord]))")
                
                //                        send API command/data
                vc.update(DeviceType: "computers", endpointXML: updateDeviceXml, endpointCurrent: currentRecord+1, endpointCount: prevAllRecordValuesArray.count, action: "PUT", uniqueID: Uid) {
                    (result: Bool) in
                    //                        print("result: \(result)")
                    if result {
//                        successCount += 1
                        //                            print("successCount: \(successCount)\n")
                    } else {
//                        failCount += 1
                        //                            print("failCount: \(failCount)\n")
                    }
//                    remaining -= 1
//                    self.updateCounts(remaining: remaining, updated: successCount, created: 0, failed: failCount)
                    self.webSpinner_ProgInd.stopAnimation(self)
                    self.goTo_TextField.stringValue = "\(self.currentRecord+1)"
                    self.goTo_Action(self)
                    return true
                }
        case "mobiledevices":
                let Uid = "\(prevAllRecordValuesArray[currentRecord]["serial_number"] ?? "")"
                let updateDeviceXml = "\(vc.generateXml(deviceType: "mobiledevices", localRecordDict: prevAllRecordValuesArray[currentRecord]))"
                //                  print("valuesDict: \(prevAllRecordValuesArray[currentRecord])")
                //                  print("generateXml: \(generateXml(localRecordDict: prevAllRecordValuesArray[currentRecord]))")
                
                //                  send API command/data
                vc.update(DeviceType: "mobiledevices", endpointXML: updateDeviceXml, endpointCurrent: currentRecord+1, endpointCount: prevAllRecordValuesArray.count, action: "PUT", uniqueID: Uid) {
                    (result: Bool) in
                    //                        print("result: \(result)")
                    if result {
//                        successCount += 1
                        //                            print("sucessCount: \(successCount)\n")
                    } else {
//                        failCount += 1
                        //                            print("failCount: \(failCount)\n")
                    }
//                    remaining -= 1
//                    self.updateCounts(remaining: remaining, updated: successCount, created: 0, failed: failCount)
                    self.webSpinner_ProgInd.stopAnimation(self)
                    self.goTo_TextField.stringValue = "\(self.currentRecord+1)"
                    self.goTo_Action(self)
                    return true
                }
        default:
            break
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("[PreviewController: viewDidLoad]")
        self.view.window?.orderOut(self)
//        if prevAllRecordValuesArray.count > 0 {
        webSpinner_ProgInd.startAnimation(self)
        generatePage(recordNumber: 0)
        DispatchQueue.main.async {
            self.whichRecord_TextField.stringValue = "\(self.currentRecord+1) of \(self.prevAllRecordValuesArray.count)"
        }
    }
    
    func generatePage(recordNumber: Int) {
//        print("present values: \(prevAllRecordValuesArray[recordNumber])")
        if prevAllRecordValuesArray.count > 0 {
            let theDevice    = "\(prevAllRecordValuesArray[recordNumber]["deviceName"] ?? "")"
            let serialNumber = "\(prevAllRecordValuesArray[recordNumber]["serial_number"] ?? "")"
            let assetTag     = "\(prevAllRecordValuesArray[recordNumber]["asset_tag"] ?? "")"
            let site         = "\(prevAllRecordValuesArray[recordNumber]["siteName"] ?? "")"
            let username     = "\(prevAllRecordValuesArray[recordNumber]["username"] ?? "")"
            let realname     = "\(prevAllRecordValuesArray[recordNumber]["real_name"] ?? "")"
            let emailAddress = "\(prevAllRecordValuesArray[recordNumber]["email_address"] ?? "")"
            let phoneNumber  = "\(prevAllRecordValuesArray[recordNumber]["phone_number"] ?? "")"
            let position     = "\(prevAllRecordValuesArray[recordNumber]["position"] ?? "")"
            let department   = "\(prevAllRecordValuesArray[recordNumber]["department"] ?? "")"
            let building     = "\(prevAllRecordValuesArray[recordNumber]["building"] ?? "")"
            let room         = "\(prevAllRecordValuesArray[recordNumber]["room"] ?? "")"

            getEndpoint(id: serialNumber) {
                (result: Dictionary) in
    //            print("result: \(result)")
                let existingValuesDict = result
    //            print("bundle path: \(Bundle.main.bundlePath)")
                // old background: #619CC7
                self.previewPage = "<!DOCTYPE html>" +
                    "<html>" +
                    "<head>" +
                    "<style>" +
                    "body { color: white; background-color: #2F4254; }" +
                    "table, th, td {" +
                    "border: 0px solid black;padding-right: 3px;" +
                    "}" +
                    "#table1 { border-collapse: collapse; table-layout: fixed; margin: auto; }" +
                    "th, td { border-bottom: 1px solid #4C7A9B; }" +    //#ddd
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
                    self.addTableRow(attribute: "Department", existing: "\(existingValuesDict["department"] ?? "")", update: "\(department)") +
                    self.addTableRow(attribute: "Building", existing: "\(existingValuesDict["building"] ?? "")", update: "\(building)") +
                    self.addTableRow(attribute: "Room", existing: "\(existingValuesDict["room"] ?? "")", update: "\(room)") +

                    self.addEaToTable(updateValues: self.prevAllRecordValuesArray[recordNumber]) +

                    "</table>" +
                    "</body>" +
                "</html>"
    //        print("new test: \(previewPage)")
                self.preview_WebView.loadHTMLString(self.previewPage, baseURL: nil)
                self.webSpinner_ProgInd.stopAnimation(self)
                return [:]
            }
        } else {
            ViewController().alert_dialog("Attention", message: "No records found to lookup.")
            DispatchQueue.main.async {
                self.view.window?.orderOut(self)
                self.view.window?.close()
            }
//            return
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
//            print("serverRequest: \(serverRequest)")
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
                                    if self.prevLowercaseEaHeaderArray.firstIndex(of: (EaName.lowercased())) != nil {
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
                                    if self.prevLowercaseEaHeaderArray.firstIndex(of: (EaName.lowercased())) != nil {
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
                let newLine = addTableRow(attribute: key, existing: value, update: updateValues[_key] as! String)
                EaString.append(newLine)
            }
        }
        return EaString
    }

    func addTableRow(attribute: String, existing: String, update: String) -> String {
        var currentRow = ""
        var updateText = ""
        var existingText = "<td>\(existing)</td>"
        
//        print("\(attribute): \t existing: .\(existing). \t update: .\(update).")

        if existing != "" || update != "" {
            if ((existing != "" && update != "") && (existing != update)) {
                updateText = "<td style='color:yellow'>\(update)</td>"
            } else if (existing == "" && update != "") {
                updateText = "<td style='color:aqua'>\(update)</td>"
            } else {
                updateText = "<td>\(existing)</td>"
            }
            // mark attribute values getting removed
            if existing != "" && update == " " {
                existingText = "<td style='color:red'>\(existing)</td>"
            }
            currentRow = "<tr>" +
                "<td style=\"text-align:right\">\(attribute):</td>" +
                "\(existingText)" +
                "\(updateText)" +
            "</tr>"
        }
        return "\(currentRow)"
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}
