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

class PreviewController: NSViewController, NSTextFieldDelegate, URLSessionDelegate {

    @IBOutlet weak var preview_WebView: WKWebView!
    var myQ = DispatchQueue(label: "com.jamf.current")
    
    @IBOutlet weak var webSpinner_ProgInd: NSProgressIndicator!
    @IBOutlet weak var whichRecord_TextField: NSTextField!
    @IBOutlet weak var goTo_TextField: NSTextField!
    @IBOutlet weak var find_TextField: NSTextField!
    
    let vc = ViewController()
    
    var newValues = String()
    var prevAllRecordValuesArray = [[String:String]]()
    var prevLowercaseEaHeaderArray = [String]()    // array of (lowercase) extension attributes to update
    var currentRecord           = 0
    
    var previewPage             = ""
    var previewPage2            = ""
    
    var previewDeviceType       = ""
    var previewRecordID         = ""
    var authResult              = ""
    
    var currentValuesDict       = [String:String]()
    var generalDict             = [String:Any]()
    var locationDict            = [String:Any]()
    var extAttributesDict       = [[String: Any]]()
    var currentEaValuesDict     = [String:String]()
    var lowercaseEaValuesDict   = [String:String]()   // array of EA names [lowercase name:original name]
    var recordBySerialNumber    = [String:Int]()
    
    var currentName             = ""
    var currentSerialnumber     = ""
    var currentDept             = ""
    
    @IBAction func closePreview(_ sender: NSButton) {
        view.window?.close()
    }
    
    @IBAction func goTo_Action(_ sender: Any) {
        DispatchQueue.main.async { [self] in
            currentRecord = Int(goTo_TextField.stringValue) ?? 0
            if currentRecord > 0 && currentRecord <= prevAllRecordValuesArray.count {
                webSpinner_ProgInd.startAnimation(self)
                currentRecord -= 1
                generatePage(recordNumber: currentRecord)
                whichRecord_TextField.stringValue = "\(currentRecord+1) of \(prevAllRecordValuesArray.count)"
            }
        }
    }
    
    @IBAction func prevRecord_Button(_ sender: Any) {
        DispatchQueue.main.async { [self] in
            webSpinner_ProgInd.startAnimation(self)
            goTo_TextField.stringValue = ""
            currentRecord -= 1
            currentRecord = (currentRecord < 0 ? prevAllRecordValuesArray.count-1:currentRecord)
            generatePage(recordNumber: currentRecord)
            whichRecord_TextField.stringValue = "\(currentRecord+1) of \(prevAllRecordValuesArray.count)"
        }
    }
    
    @IBAction func nextRecord_Button(_ sender: Any) {
        DispatchQueue.main.async { [self] in
            webSpinner_ProgInd.startAnimation(self)
            goTo_TextField.stringValue = ""
            currentRecord += 1
            currentRecord = (currentRecord > prevAllRecordValuesArray.count-1 ? 0:currentRecord)
            generatePage(recordNumber: currentRecord)
            whichRecord_TextField.stringValue = "\(currentRecord+1) of \(prevAllRecordValuesArray.count)"
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
                WriteToLog().message(stringOfText: "[PreviewController] currentRecord: \(currentRecord)\nvaluesDict: \(prevAllRecordValuesArray[currentRecord])")
                //                    WriteToLog().message(stringOfText: "[PreviewController] generateXml: \(generateXml(localRecordDict: prevAllRecordValuesArray[currentRecord]))")
                
                //                        send API command/data
                vc.update(DeviceType: "computers", endpointXML: updateDeviceXml, endpointCurrent: currentRecord+1, endpointCount: prevAllRecordValuesArray.count, action: "PUT", uniqueID: Uid) {
                    (result: Bool) in
                    //                        WriteToLog().message(stringOfText: "[PreviewController] result: \(result)")
                    if result {
//                        successCount += 1
                        //                            WriteToLog().message(stringOfText: "[PreviewController] successCount: \(successCount)\n")
                    } else {
//                        failCount += 1
                        //                            WriteToLog().message(stringOfText: "[PreviewController] failCount: \(failCount)\n")
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
                //                  WriteToLog().message(stringOfText: "[PreviewController] valuesDict: \(prevAllRecordValuesArray[currentRecord])")
                //                  WriteToLog().message(stringOfText: "[PreviewController] generateXml: \(generateXml(localRecordDict: prevAllRecordValuesArray[currentRecord]))")
                
                //                  send API command/data
                vc.update(DeviceType: "mobiledevices", endpointXML: updateDeviceXml, endpointCurrent: currentRecord+1, endpointCount: prevAllRecordValuesArray.count, action: "PUT", uniqueID: Uid) {
                    (result: Bool) in
                    //                        WriteToLog().message(stringOfText: "[PreviewController] result: \(result)")
                    if result {
//                        successCount += 1
                        //                            WriteToLog().message(stringOfText: "[PreviewController] sucessCount: \(successCount)\n")
                    } else {
//                        failCount += 1
                        //                            WriteToLog().message(stringOfText: "[PreviewController] failCount: \(failCount)\n")
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
    
    
    // selective list filter
    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            if textField.identifier!.rawValue == "search" {
                let filter = find_TextField.stringValue.lowercased()
//                print("filter: \(filter)")
                if filter != "" {
                    if recordBySerialNumber[filter] != nil {
                        goTo_TextField.stringValue = "\(String(describing: recordBySerialNumber[filter]!))"
                        goTo_Action(self)
                    }
                }
            }
        }
    }
    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            if textField.identifier!.rawValue == "search" {
                let filter = find_TextField.stringValue.lowercased()
//                print("filter: \(filter)")
                if filter != "" {
                    if recordBySerialNumber[filter] == nil {
                        Alert().display(header: "Attention", message: "The device was not found within the list of imported records.")
//                        find_TextField.stringValue = ""
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        print("\(#line)-[PreviewController] authResult: \(authResult)")
//        WriteToLog().message(stringOfText: "[PreviewController: viewDidLoad]")
        find_TextField.delegate = self
        self.view.window?.orderOut(self)
        if authResult == "failed" {
            DispatchQueue.main.async { [self] in
                self.view.window?.close()
            }
        } else {
            webSpinner_ProgInd.startAnimation(self)
            generatePage(recordNumber: 0)
            DispatchQueue.main.async { [self] in
                whichRecord_TextField.stringValue = "\(currentRecord+1) of \(prevAllRecordValuesArray.count)"
                for recordNumber in 0..<prevAllRecordValuesArray.count {
                    if prevAllRecordValuesArray[recordNumber]["serial_number"] != nil {
                        recordBySerialNumber["\(String(describing: prevAllRecordValuesArray[recordNumber]["serial_number"]!.lowercased()))"] = recordNumber+1
                    }
                }
            }
        }
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.title = (previewDeviceType == "computers") ? "Device Preview: Computer":"Device Preview: Mobile Device"
    }
    
    override func viewWillDisappear() {
        find_TextField.stringValue = ""
    }
    
    func generatePage(recordNumber: Int) {
//        WriteToLog().message(stringOfText: "[PreviewController] present values: \(prevAllRecordValuesArray[recordNumber])")
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

            getEndpoint(id: serialNumber) { [self]
                (result: Dictionary) in
    //            WriteToLog().message(stringOfText: "[PreviewController] result: \(result)")
                let existingValuesDict = result
    //            WriteToLog().message(stringOfText: "[PreviewController] bundle path: \(Bundle.main.bundlePath)")
                // old background: #619CC7
                previewPage = "<!DOCTYPE html>" +
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
                    "<th style='width: 25%'></th>" +
                    "<th style='text-align:left; width: 37%'>Current</th>" +
                "<th style='text-align:left; width: 1px'> </th>" +
                "<th style='text-align:left; width: 37%'>Update</th>" +
                "<th style='text-align:left; width: 10px'> </th>" +
                    "</tr>" +
                    "<tr>" +
                    "<td style=\"text-align:right\">Device Name:</td>" +
                    
                    "<td>\(existingValuesDict["deviceName"] ?? "")</td>" +
                    "<td> </td>" +
                    "<td>\(theDevice)</td><td> </td>" +
                    "</tr>" +
                    addTableRow(attribute: "Serial Number", existing: "\(existingValuesDict["serial_number"] ?? "")", update: "\(serialNumber)") +
                    addTableRow(attribute: "Asset Tag", existing: "\(existingValuesDict["asset_tag"] ?? "")", update: "\(assetTag)") +
//                    "<tr>" +
//                    "<td style=\"text-align:right\">Site:</td>" +
//
//                    "<td>\(existingValuesDict["siteName"] ?? "")</td>" +
//                    "<td>\(site)</td>" +
//                    "</tr>" +
                    addTableRow(attribute: "Site", existing: "\(existingValuesDict["siteName"] ?? "")", update: "\(site)") +
                    addTableRow(attribute: "Username", existing: "\(existingValuesDict["username"] ?? "")", update: "\(username)") +
                    addTableRow(attribute: "Realname", existing: "\(existingValuesDict["real_name"] ?? "")", update: "\(realname)") +
                    addTableRow(attribute: "Email Address", existing: "\(existingValuesDict["email_address"] ?? "")", update: "\(emailAddress)") +
                    addTableRow(attribute: "Phone Number", existing: "\(existingValuesDict["phone_number"] ?? "")", update: "\(phoneNumber)") +
                    addTableRow(attribute: "Position", existing: "\(existingValuesDict["position"] ?? "")", update: "\(position)") +
                    addTableRow(attribute: "Department", existing: "\(existingValuesDict["department"] ?? "")", update: "\(department)") +
                    addTableRow(attribute: "Building", existing: "\(existingValuesDict["building"] ?? "")", update: "\(building)") +
                    addTableRow(attribute: "Room", existing: "\(existingValuesDict["room"] ?? "")", update: "\(room)") +

                    addEaToTable(updateValues: prevAllRecordValuesArray[recordNumber]) +

                    "</table>" +
                    "</body>" +
                "</html>"
                preview_WebView.loadHTMLString(previewPage, baseURL: nil)
                webSpinner_ProgInd.stopAnimation(self)
                return [:]
            }
        } else {
            Alert().display(header: "Attention", message: "No records found to lookup.")
            DispatchQueue.main.async { [self] in
                view.window?.orderOut(self)
                view.window?.close()
            }
        }
        
    }
    
    func getEndpoint(id: String, completion: @escaping ([String: Any]) -> [String: Any]) {
        let safeCharSet = CharacterSet.alphanumerics
        let uniqueID = id.addingPercentEncoding(withAllowedCharacters: safeCharSet)!
        let semaphore = DispatchSemaphore(value: 0)
        myQ.async {
            var serverUrl = "\(jamfProServer.source)/JSSResource/\(self.previewDeviceType)/\(self.previewRecordID)/\(uniqueID)"
            serverUrl = serverUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
//            WriteToLog().message(stringOfText: "[PreviewController] serverUrl: \(serverUrl)")
            
            let serverEncodedURL = URL(string: serverUrl)
            let serverRequest = NSMutableURLRequest(url: serverEncodedURL! as URL)
//            WriteToLog().message(stringOfText: "[PreviewController] serverRequest: \(serverRequest)")
            serverRequest.httpMethod = "GET"
            let serverConf = URLSessionConfiguration.default
            serverConf.httpAdditionalHeaders = ["Authorization" : "\(String(describing: jamfProServer.authType["source"]!)) \(String(describing: jamfProServer.authCreds["source"]!))", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : appInfo.userAgentHeader]
            let serverSession = Foundation.URLSession(configuration: serverConf, delegate: self, delegateQueue: OperationQueue.main)
            let task = serverSession.dataTask(with: serverRequest as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                if let httpResponse = response as? HTTPURLResponse {
//                  WriteToLog().message(stringOfText: "[PreviewController] httpResponse: \(String(describing: response))")
                    do {
                        let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                        if let endpointJSON = json as? [String: Any] {
//                          WriteToLog().message(stringOfText: "[PreviewController] endpointJSON: \(endpointJSON)")
                            switch self.previewDeviceType.lowercased() {
                            case "computers":
                                WriteToLog().message(stringOfText: "[PreviewController] computer case")
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
//                                WriteToLog().message(stringOfText: "[PreviewController] \nEAs: \(self.extAttributesDict.count)")
//                                WriteToLog().message(stringOfText: "[PreviewController] EAs: \(self.extAttributesDict)")
                                for i in (0..<self.extAttributesDict.count) {
                                    let EaName = self.extAttributesDict[i]["name"] as! String
                                    let EaValue = self.extAttributesDict[i]["value"]
                                    if self.prevLowercaseEaHeaderArray.firstIndex(of: (EaName.lowercased())) != nil {
                                        self.currentEaValuesDict[EaName] = "\(EaValue ?? "")"
                                    }
//                                    self.lowercaseEaValuesDict[EaName.lowercased()] = EaName
                                }

                            case "mobiledevices":
                                WriteToLog().message(stringOfText: "[PreviewController] iOS case")
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
//                                WriteToLog().message(stringOfText: "[PreviewController] \nEAs: \(self.extAttributesDict.count)")
//                                WriteToLog().message(stringOfText: "[PreviewController] EAs: \(self.extAttributesDict)")
                                for i in (0..<self.extAttributesDict.count) {
                                    let EaName = self.extAttributesDict[i]["name"] as! String
                                    let EaValue = self.extAttributesDict[i]["value"]
                                    if self.prevLowercaseEaHeaderArray.firstIndex(of: (EaName.lowercased())) != nil {
                                        self.currentEaValuesDict[EaName] = "\(EaValue ?? "")"
                                    }
//                                    self.lowercaseEaValuesDict[EaName.lowercased()] = EaName
                                }
                            default:
                                break
                            }   // switch - end
                        }   // if let serverEndpointJSON - end
                        
                    } catch {
                        WriteToLog().message(stringOfText: "[PreviewController] Existing endpoints: error serializing JSON: \(error)\n")
                    }   // end do/catch
                    
                    if httpResponse.statusCode >= 199 && httpResponse.statusCode <= 299 {
                        //WriteToLog().message(stringOfText: httpResponse.statusCode)
                        
                        completion(self.currentValuesDict)
                    } else {
                        // something went wrong
                        WriteToLog().message(stringOfText: "[PreviewController] status code: \(httpResponse.statusCode)")
                        completion([:])
                        
                    }   // if httpResponse/else - end
                }   // if let httpResponse - end
                semaphore.signal()
                if error != nil {
                }
            })  // let task = destSession - end
            //WriteToLog().message(stringOfText: "[PreviewController] GET")
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
        
//        WriteToLog().message(stringOfText: "[PreviewController] \(attribute): \t existing: .\(existing). \t update: .\(update).")

        if existing != "" || update != "" {
            if ((existing != "" && update != "") && (existing != update)) {
                updateText = "<td style='color:yellow;font-style: italic'>\(update)</td><td>C</td>"
            } else if (existing == "" && update != "") {
                updateText = "<td style='color:aqua'>\(update)</td><td>A</td>"
            } else {
                updateText = "<td>\(existing)</td><td> </td>"
            }
            // mark attribute values getting removed
            if existing != "" && update == " " {
                existingText = "<td style='color:redfont-style: bold'>\(existing)</td><td> </td>"
            }
            currentRow = "<tr>" +
                "<td style=\"text-align:right\">\(attribute):</td>" +
                "\(existingText)" +
                "<td> </td>" +
                "\(updateText)" +
            "</tr>"
        }
        return "\(currentRow)"
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}
