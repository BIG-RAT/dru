//
//  ViewController.swift
//  dru
//
//  Created by Leslie Helou on 8/7/17.
//  Copyright © 2017 jamf. All rights reserved.
//

import AppKit
import Cocoa
import CoreFoundation
import WebKit

class ViewController: NSViewController, URLSessionDelegate {

    @IBOutlet weak var window: NSWindow!
    
    @IBOutlet weak var jssURL_TextField: NSTextField!
    @IBOutlet weak var userName_TextField: NSTextField!
    @IBOutlet weak var userPass_TextField: NSSecureTextField!
    @IBOutlet weak var dataFile_PathControl: NSPathControl!
    @IBOutlet weak var spinner: NSProgressIndicator!
    @IBOutlet weak var hasHeader_Button: NSButtonCell!  // 0 - no header : 1 - header
    @IBOutlet weak var deviceType_Matrix: NSMatrix! // 0 - computers : 1 - iOS
    
    @IBOutlet weak var backup_button: NSButton!

    @IBOutlet weak var remaining_TextField: NSTextField!
    @IBOutlet weak var updated_TextField: NSTextField!
    @IBOutlet weak var created_TextField: NSTextField!
    @IBOutlet weak var failed_TextField: NSTextField!
    
    @IBAction func showVariables(_ sender: NSButton) {
        print("jss url: \(jssURL_TextField.stringValue)")
        print("login name: \(userName_TextField.stringValue)")
        print("login password: \(userPass_TextField.stringValue)")
        print("data file path: \(String(describing: dataFile_PathControl.url))")
        print("header: \(hasHeader_Button.integerValue)")
        print("device type: \(deviceType_Matrix.selectedRow)")
        print("sender: \(sender.title)")
    }
    
    var jssURL          = ""
    var userName        = ""
    var userPass        = ""
    var jamfBase64Creds = ""
    var xmlString       = [String]()
    var deviceType      = ""
    var recordId        = "serialnumber"
    
    var dataArray       = [String]()

    var pathToFile:URL?
    var theLineArray:[String] = []
    
    var firstDataLine = 0
    let headerArray = [String]()
    let knownHeadersArray = ["computer name", "display name", "serial number", "serial_number", "udid", "asset tag", "asset_tag", "full name", "username", "email address", "email_address", "building", "department","position", "room", "phone number", "user phone number", "device phone number", "phone", "site"]
    var safeHeaderArray = [String]()    // array for built in attributes
    var safeEaHeaderArray = [String]()  // array for extension attributes
    var headerCount = 0
    var local_newValuesDict = [String:String]()
    var dateTime = ""   // used to create unique, time based, folders for backups
    
    var valuesDict = [String:String]()
    
    var theOpQ = OperationQueue() // create operation queue for API calls
    var theUpdateQ = OperationQueue()   // queue to update counts
    var theBackupQ = DispatchQueue(label: "com.jamf.thebackupq")
    var totalRecords = 0
    var postCount = 1
    
    // computer record values - start
    var allRecordValuesArray = [[String:String]]()
    var theKey = ""
    // computer record values - end
    
    let fm = FileManager.default
    var format = PropertyListSerialization.PropertyListFormat.xml //format of the property list
    var plistData:[String:AnyObject] = [:]  // settings data
    let appSupportPath = (NSHomeDirectory() + "/Library/Application Support/dru/")
    let backupPath = (NSHomeDirectory() + "/Library/Application Support/dru/backups/")
    let defaultSettings = Bundle.main.path(forResource: "settings", ofType: "plist")!
    var backupFile = ""
    var backupFileHandle = FileHandle(forUpdatingAtPath: "")
    var writeHeader = true
    
    @IBAction func loadFile_PathControl(_ sender: NSPathControl) {
        
//      ensure arrays are empty
        safeHeaderArray.removeAll()
        safeEaHeaderArray.removeAll()
        theLineArray.removeAll()
        allRecordValuesArray.removeAll()
        // parse header row, change lowercase start
        
        if let pathToFile = dataFile_PathControl.url {
            do {
                let dataFile =  try Data(contentsOf:pathToFile)
                let attibutedString = try NSAttributedString(data: dataFile, documentAttributes: nil)
                let fileText = attibutedString.string
                let allLines = fileText.components(separatedBy: CharacterSet.newlines)
                // create header array - start
                if hasHeader_Button.state.rawValue == 1 {
                    var safeHeaderIndex = 0
                    var safeEaHeaderIndex = 0
                    let headerArray = createFieldArray(theString: allLines[0])
                    firstDataLine = 1
                    headerCount = headerArray.count
//                    print("headerArray: \(headerArray)")
//                    print("headerCount: \(headerArray.count)")
                    for i in 0..<headerCount {
                        if knownHeadersArray.index(of: (headerArray[i] ).lowercased()) != nil {
                            let lowercaseHeader = "\(headerArray[i] )".lowercased()
                            safeHeaderArray.append(lowercaseHeader)
                            switch lowercaseHeader {
                            case "computer name", "display name":
                                safeHeaderArray[safeHeaderIndex] = "deviceName"
                            case "serial number":
                                safeHeaderArray[safeHeaderIndex] = "serial_number"
                            case "asset tag":
                                safeHeaderArray[safeHeaderIndex] = "asset_tag"
                            case "site":
                                safeHeaderArray[safeHeaderIndex] = "siteName"
                            case "full name":
                                safeHeaderArray[safeHeaderIndex] = "real_name"
                            case "email address":
                                safeHeaderArray[safeHeaderIndex] = "email_address"
                            case "phone number", "user phone number":
                                safeHeaderArray[safeHeaderIndex] = "phone_number"
                            default: break
                                // all good
                            }
                            safeHeaderIndex += 1
                        } else {
                            // load extension attribute headers - start
                            let lowercaseEaHeader = "\(headerArray[i] )".lowercased()
                            safeEaHeaderArray.append(lowercaseEaHeader)
                            safeHeaderArray.append("_" + lowercaseEaHeader)
//                            safeEaHeaderArray.append((headerArray[i] as AnyObject).lowercased)
//                            safeHeaderArray.append("_" + (headerArray[i] as AnyObject).lowercased)
                            safeHeaderIndex += 1
                            safeEaHeaderIndex += 1
                            // load extension attribute headers - end
                        }
                    }
//                    print("Built in Headers: \(safeHeaderArray)")
//                    print("EA Headers: \(safeEaHeaderArray)")
                }
                // create header array - end
                if safeHeaderArray.count == 0 {
                    alert_dialog("Warning", message: "Unable to identify any headers!")
                    return
                }
                // parse data - start
                for i in firstDataLine..<allLines.count {
                    if allLines[i] != "" {
                        allRecordValuesArray.append(xml(headerArray: safeHeaderArray , dataArray: createFieldArray(theString: allLines[i])))
                    }
                }
                // parse data - end
//                print("data: \(allRecordValuesArray)")
            } catch {
                print("file read error")
            }
        }
        
        totalRecords = allRecordValuesArray.count
        self.updateCounts(remaining: totalRecords, updated: 0, created: 0, failed: 0)
    }
    
    
    @IBAction func parseFile_Button(_ sender: Any) {
 
        if (sender as AnyObject).title == "Update" {
            
            deviceType_Matrix.selectedRow == 0 ? (deviceType = "computers") : (deviceType = "mobiledevices")
            var successCount = 0
            var failCount = 0
            var remaining = allRecordValuesArray.count
            
            dateTime = getDateTime(x: 1)
            backupFile = backupPath + dateTime + ".csv"
            createFileFolder(itemPath: backupFile, objectType: "file")
            backupFileHandle = FileHandle(forUpdatingAtPath: backupFile)
            writeHeader = true

            switch deviceType {
            case "computers":
                for i in 0..<allRecordValuesArray.count {
                    let Uid = "\(allRecordValuesArray[i]["serial_number"] ?? "")"
                    let updateDeviceXml = "\(generateXml(localRecordDict: allRecordValuesArray[i]))"
//                        print("valuesDict: \(allRecordValuesArray[i])")
//                    print("generateXml: \(generateXml(localRecordDict: allRecordValuesArray[i]))")

//                        send API command/data
                    update(DeviceType: "computers", endpointXML: updateDeviceXml, endpointCurrent: i+1, endpointCount: allRecordValuesArray.count, action: "PUT", uniqueID: Uid) {
                        (result: Bool) in
//                        print("result: \(result)")
                        if result {
                            successCount += 1
                            print("sucessCount: \(successCount)\n")
                        } else {
                            failCount += 1
                            print("failCount: \(failCount)\n")
                        }
                        remaining -= 1
                        self.updateCounts(remaining: remaining, updated: successCount, created: 0, failed: failCount)
                        return true
                    }
                }
            case "mobiledevices":
                for i in 0..<allRecordValuesArray.count {
                    let Uid = "\(allRecordValuesArray[i]["serial_number"] ?? "")"
                    let updateDeviceXml = "\(generateXml(localRecordDict: allRecordValuesArray[i]))"
//                  print("valuesDict: \(allRecordValuesArray[i])")
//                  print("generateXml: \(generateXml(localRecordDict: allRecordValuesArray[i]))")
                    
//                  send API command/data
                    update(DeviceType: "mobiledevices", endpointXML: updateDeviceXml, endpointCurrent: i+1, endpointCount: allRecordValuesArray.count, action: "PUT", uniqueID: Uid) {
                        (result: Bool) in
//                        print("result: \(result)")
                        if result {
                            successCount += 1
//                            print("sucessCount: \(successCount)\n")
                        } else {
                            failCount += 1
//                            print("failCount: \(failCount)\n")
                        }
                        remaining -= 1
                        self.updateCounts(remaining: remaining, updated: successCount, created: 0, failed: failCount)
                        return true
                    }
                }
                default:
                    break
            }
        } else {
//            print("preview:")

        }
    }
    
    
    @IBAction func QuitNow(_ sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }
    
    // for preview window
    @IBAction func showPreviewWindow(_ sender: AnyObject) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let previewWindowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Preview Window Controller")) as! NSWindowController
        if let previewWindow = previewWindowController.window {
//            let previewViewController = previewWindow.contentViewController as! PreviewViewController
            let application = NSApplication.shared
            application.runModal(for: previewWindow)
            previewWindow.close()
        }
    }
    
    func createFieldArray(theString: String) -> [String] {
        
        var charPosition = 0
        var prevChar = ""
        var currChar = ""
        var QuotedField = false
        var writeQuoteChar = true
        var theField:String = ""
        var index:String.Index?
        
        //print("starting check")
        var fieldArray:[String] = []
        var fieldNumber = 0
        
        let strLength: Int = theString.distance(from: theString.startIndex, to: theString.endIndex)    //.distanceTo(range.startIndex)
        while charPosition < strLength {
            writeQuoteChar = true
            index = theString.index(theString.startIndex, offsetBy: charPosition)
            currChar = "\(theString[index!])"
            if !(currChar == "," || charPosition == (strLength-1)) {
                
                if prevChar == "," && currChar == "\"" && !QuotedField {
                    QuotedField = true
                    prevChar = ""
                    //print("entered quoted field")
                    while QuotedField && charPosition < strLength {
                        charPosition += 1
                        index = theString.index(theString.startIndex, offsetBy: charPosition)
                        //print("quoted field: \(theString[index!])\tIndex: \(String(describing: index))")
                        currChar = "\(theString[index!])"
                        if prevChar == "\"" && currChar == "," && writeQuoteChar {
                            QuotedField = false
                            writeQuoteChar = true
                            
//                            print("end quoted field")
                            //charPosition -= 1
                            fieldArray.append(theField)
                            theField = ""
                            fieldNumber += 1
                        } else if prevChar == "\"" && currChar == "\"" {
                            if writeQuoteChar {
                                theField.append("\(currChar)")
                                //currChar = ""
                            }
                            writeQuoteChar = !writeQuoteChar
                        } else if currChar != "\"" {
                            writeQuoteChar = true
                            
                            theField.append("\(currChar)")
                        }   // if currChar == "," && prevChar == "\"" - end
                        prevChar = currChar
                    }   // while QuotedField - end
                } else {
                    theField.append("\(currChar)")
                }   // if prevChar == "," && currChar - end
            } else {
                if currChar != "," {
                    theField.append("\(currChar)")
                }
                fieldArray.append(theField)
                theField = ""
                fieldNumber += 1
            }   // if !(currChar == "," || charPosition - end
            prevChar = currChar
            charPosition += 1
        }   // while charPosition - end
        print("fieldArray: \(fieldArray)")
//        return fieldArray
        return fieldArray as [String]
    }
    
    func xml(headerArray: [String], dataArray: [String]) -> Dictionary<String, String> {
        for theHeader in safeHeaderArray {
            valuesDict["\(theHeader)"] = setValue(safeHeaderArray: safeHeaderArray , dataArray: dataArray, xmlKey: "\(theHeader)")
        }
        return valuesDict
    }
    
    func setValue(safeHeaderArray: [String], dataArray: [String], xmlKey: String) -> String {
        var theValue = ""
        //        print("safeHeaderArray: \(safeHeaderArray)\t\t dataArray: \(dataArray)\t\t xmlKey: \(xmlKey)")
        
        //safeHeaderArray.contains(xmlKey) ? (theValue = dataArray[safeHeaderArray.index(of: xmlKey)] as! String) : (theValue = "")
        if safeHeaderArray.contains(xmlKey) {
            if safeHeaderArray.index(of: xmlKey)! < dataArray.count {
                theValue = dataArray[safeHeaderArray.index(of: xmlKey)!]
            }
        }
        return theValue
    }
    
    func generateXml(localRecordDict: Dictionary<String, String>) -> String {
        var localDeviceName = ""
        var localAssetTag = ""
        var localSiteName = ""
        var localUsername = ""
        var localRealName = ""
        var localEmailAddress = ""
        var localPosition = ""
        var localPhone = ""
        var localDepartment = ""
        var localBuilding = ""
        var localRoom = ""
        var localEa = ""
        
        var localDevice = ""    // define device xml tag, computer or mobile_device
        
        for (key,value) in localRecordDict {
//            print("key: \(key)\t value: \(value)")
            switch key {
            case "deviceName":
                value == "" ? (localDeviceName = "") : (localDeviceName = "<name>\(value)</name>")
            case "asset_tag":
                value == "" ? (localUsername = "") : (localAssetTag = "<asset_tag>\(value)</asset_tag>")
            case "siteName":
                value == "" ? (localSiteName = "") : (localSiteName = "<site><name>\(value)</name></site>")
            case "username":
                value == "" ? (localUsername = "") : (localUsername = "<username>\(value)</username>")
            case "real_name":
                value == "" ? (localRealName = "") : (localRealName = "<real_name>\(value)</real_name>")
            case "email_address":
                value == "" ? (localEmailAddress = "") : (localEmailAddress = "<email_address>\(value)</email_address>")
            case "position":
                value == "" ? (localPosition = "") : (localPosition = "<position>\(value)</position>")
            case "phone_number":
                value == "" ? (localPhone = "") : (localPhone = "<phone>\(value)</phone>")
            case "department":
                value == "" ? (localDepartment = "") : (localDepartment = "<department>\(value)</department>")
            case "building":
                value == "" ? (localBuilding = "") : (localBuilding = "<building>\(value)</building>")
            case "room":
                value == "" ? (localRoom = "") : (localRoom.append("<room>\(value)</room>"))
            default:
                // handle extension attributes here
                if key.first == "_" {
                    var name = key
                    name.remove(at: name.startIndex)
//                    name.characters.dropFirst(1)
//                    print(name)
                    value == "" ? (localEa.append("")) : (localEa = "<extension_attribute><name>\(name)</name><value>\(value)</value></extension_attribute>")
                }
                //                break
            }
            
        }
        self.deviceType == "computers" ? (localDevice = "computer") : (localDevice = "mobile_device")
        let generatedXml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
            "<\(localDevice)><general>" +
            "\(localDeviceName)\(localAssetTag)\(localSiteName)" +
            "</general>" +
            "<location>" +
            "\(localUsername)\(localRealName)\(localEmailAddress)\(localPosition)\(localPhone)\(localDepartment)\(localBuilding)\(localRoom)" +
            "</location>" +
            "<extension_attributes>" +
            localEa +
            "</extension_attributes>" +
        "</\(localDevice)>"
        
        print("generatedXml: \(generatedXml)")
        return "\(generatedXml)"
    }
    
    func update(DeviceType: String, endpointXML: String, endpointCurrent: Int, endpointCount: Int, action: String, uniqueID: String, completion: @escaping (Bool) -> Bool) {
        // this is where we create the new endpoint
        let safeCharSet = CharacterSet.alphanumerics
        var DestURL = ""
        let Uid = "\(uniqueID)".addingPercentEncoding(withAllowedCharacters: safeCharSet)!
        
        let jamfCreds = "\(userName_TextField.stringValue):\(userPass_TextField.stringValue)"
        let jamfUtf8Creds = jamfCreds.data(using: String.Encoding.utf8)
        jamfBase64Creds = (jamfUtf8Creds?.base64EncodedString())!
        
        theUpdateQ.maxConcurrentOperationCount = 1
        let semaphore = DispatchSemaphore(value: 0)
        let encodedXML = endpointXML.data(using: String.Encoding.utf8)
        
        theUpdateQ.addOperation {
            
            DestURL = "\(self.jssURL_TextField.stringValue)/JSSResource/\(self.deviceType)/\(self.recordId)/\(Uid)"
            DestURL = DestURL.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
            
//            print("processing device \(endpointCurrent)")
//            print("URL: \(DestURL)")
//            print("XML: \(endpointXML)\n")
            
            let encodedURL = NSURL(string: DestURL)
            let request = NSMutableURLRequest(url: encodedURL! as URL)
            
            // backup record here
            self.backup(deviceId: Uid, fn_deviceType: self.deviceType) {
                (backupResult: Bool) in
                
                print("returned from backup: \(Uid)")
                
                if action == "PUT" {
                    request.httpMethod = "PUT"
                } else {
                    request.httpMethod = "POST"
                }
                let configuration = URLSessionConfiguration.default
                configuration.httpAdditionalHeaders = ["Authorization" : "Basic \(self.jamfBase64Creds)", "Content-Type" : "text/xml", "Accept" : "text/xml"]
                request.httpBody = encodedXML!
                let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
                let task = session.dataTask(with: request as URLRequest, completionHandler: {
                    (data, response, error) -> Void in
                    if let httpResponse = response as? HTTPURLResponse {
                        //print(httpResponse.statusCode)
                        //print(httpResponse)
                        print("POST XML-endpointType: \(self.deviceType)")
                        DispatchQueue.main.async {
                            // http succeeded
                        }

                        if httpResponse.statusCode >= 199 && httpResponse.statusCode <= 299 {
                            print("\n\n---------- Success ----------")
                            print("\(encodedXML!)")
                            print("---------- Success ----------")
                            completion(true)
                        } else {
                            // http failed
                            // 401 - wrong username and/or password
                            // 409 - unable to create object; already exists or data missing or xml error
                            print("httpResponse: \(httpResponse)")
                            print("statusCode: \(httpResponse.statusCode)")
                            print("\(encodedXML!)")
                            completion(false)
                        }
                    }
                    
                    semaphore.signal()
                    if error != nil {
                    }
                })
                task.resume()
                semaphore.wait()
            
                
            }   // backup - end
        }   // theOpQ.addOperation - end
    }
    
    // func alert_dialog - start
    func alert_dialog(_ header: String, message: String) {
        let dialog: NSAlert = NSAlert()
        dialog.messageText = header
        dialog.informativeText = message
        dialog.alertStyle = NSAlert.Style.warning
        dialog.addButton(withTitle: "OK")
        dialog.runModal()
    }
    // func alert_dialog - end
    
    
    func backup(deviceId: String, fn_deviceType: String, completion: @escaping (_ backupResult: Bool) -> Void) {
        let semaphore = DispatchSemaphore(value: 1)
        if backup_button.state.rawValue == 1 {
            var fn_fullRecordDict = [String:Any]()
            var getResult = false
            var fn_currentRecordDict = [String:String]()
            var fn_generalDict = [String:Any]()
            var fn_locationDict = [String:Any]()
            var fn_extAttributesDict = [Dictionary<String, Any>]()
            var recordText = ""
            var xmlTag = ""
            
            theBackupQ.async {
    //        theUpdateQ.addOperation {
                var serverUrl = "\(self.jssURL_TextField.stringValue)/JSSResource/\(fn_deviceType)/\(self.recordId)/\(deviceId)"
                serverUrl = serverUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
                //            print("serverUrl: \(serverUrl)")
                
                let serverEncodedURL = NSURL(string: serverUrl)
                let serverRequest = NSMutableURLRequest(url: serverEncodedURL! as URL)
    //            print("serverRequest: \(serverRequest)")
                serverRequest.httpMethod = "GET"
                print("getting: \(fn_deviceType)")
                
                let configuration = URLSessionConfiguration.default
                configuration.httpAdditionalHeaders = ["Authorization" : "Basic \(self.jamfBase64Creds)", "Accept" : "application/json"]
    //            fn_request.httpBody = encodedXML!
                let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
                let task = session.dataTask(with: serverRequest as URLRequest, completionHandler: {
                    (data, response, error) -> Void in
                    if let httpResponse = response as? HTTPURLResponse {
    //                    print("statusCode: ",httpResponse.statusCode)
    //                    print("httpResponse: ",httpResponse)
                        //print("POST XML-\(endpointCurrent): endpointType: \(endpointType)  endpointNumber: \(endpointCurrent)")
                        do {
                            let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                            if let endpointJSON = json as? [String: Any] {
                                switch fn_deviceType {
                                case "computers":
                                    print("computer case")
                                    fn_fullRecordDict = endpointJSON["computer"] as! [String:Any]
                                    // general info
                                    fn_generalDict = fn_fullRecordDict["general"] as! [String:Any]
                                    fn_currentRecordDict["deviceName"] = fn_generalDict["name"] as? String
                                    fn_currentRecordDict["mac_address"] = fn_generalDict["mac_address"] as? String
                                    fn_currentRecordDict["serial_number"] = fn_generalDict["serial_number"] as? String
                                    fn_currentRecordDict["asset_tag"] = fn_generalDict["asset_tag"] as? String
                                    let currentSiteDict = fn_generalDict["site"] as! [String:Any]
                                    fn_currentRecordDict["siteName"] = currentSiteDict["name"] as? String
                                    // location info
                                    fn_locationDict = fn_fullRecordDict["location"] as! [String:Any]
                                    fn_currentRecordDict["username"] = fn_locationDict["username"] as? String
                                    fn_currentRecordDict["real_name"] = fn_locationDict["real_name"] as? String
                                    fn_currentRecordDict["email_address"] = fn_locationDict["email_address"] as? String
                                    fn_currentRecordDict["position"] = fn_locationDict["position"] as? String
                                    fn_currentRecordDict["phone_number"] = fn_locationDict["phone_number"] as? String
                                    fn_currentRecordDict["department"] = fn_locationDict["department"] as? String
                                    fn_currentRecordDict["building"] = fn_locationDict["building"] as? String
                                    fn_currentRecordDict["room"] = fn_locationDict["room"] as? String
                                    // extension attributes
                                    fn_extAttributesDict = fn_fullRecordDict["extension_attributes"] as! [Dictionary<String, Any>]
    //                                print("\nEAs: \(fn_extAttributesDict.count)")
    //                                print("EAs: \(fn_extAttributesDict)")
                                    for i in (0..<fn_extAttributesDict.count) {
                                        let EaName = fn_extAttributesDict[i]["name"] as! String
                                        let EaValue = fn_extAttributesDict[i]["value"]
                                        fn_currentRecordDict[EaName] = (EaValue as! String)
                                    }
                                    
                                // default is iOS
                                default:
                                    print("iOS case")
                                    fn_fullRecordDict = endpointJSON["mobile_device"] as! [String:Any]
                                    // general info
                                    fn_generalDict = fn_fullRecordDict["general"] as! [String:Any]
                                    fn_currentRecordDict["deviceName"] = fn_generalDict["name"] as? String
                                    fn_currentRecordDict["wifi_mac_address"] = fn_generalDict["wifi_mac_address"] as? String
                                    fn_currentRecordDict["serial_number"] = fn_generalDict["serial_number"] as? String
                                    fn_currentRecordDict["asset_tag"] = fn_generalDict["asset_tag"] as? String
                                    let currentSiteDict = fn_generalDict["site"] as! [String:Any]
                                    fn_currentRecordDict["siteName"] = currentSiteDict["name"] as? String
                                    // location info
                                    fn_locationDict = fn_fullRecordDict["location"] as! [String:Any]
                                    fn_currentRecordDict["username"] = fn_locationDict["username"] as? String
                                    fn_currentRecordDict["real_name"] = fn_locationDict["real_name"] as? String
                                    fn_currentRecordDict["email_address"] = fn_locationDict["email_address"] as? String
                                    fn_currentRecordDict["position"] = fn_locationDict["position"] as? String
                                    fn_currentRecordDict["phone_number"] = fn_locationDict["phone_number"] as? String
                                    fn_currentRecordDict["department"] = fn_locationDict["department"] as? String
                                    fn_currentRecordDict["building"] = fn_locationDict["building"] as? String
                                    fn_currentRecordDict["room"] = fn_locationDict["room"] as? String
                                    // extension attributes
                                    fn_extAttributesDict = fn_fullRecordDict["extension_attributes"] as! [Dictionary<String, Any>]
//                                                                    print("\nEAs: \(fn_extAttributesDict.count)")
//                                                                    print("EAs: \(fn_extAttributesDict)")
                                    for i in (0..<fn_extAttributesDict.count) {
                                        let EaName = fn_extAttributesDict[i]["name"] as! String
                                        let EaValue = fn_extAttributesDict[i]["value"]
                                        fn_currentRecordDict[EaName] = (EaValue as! String)
//                                        if self.prevLowercaseEaHeaderArray.index(of: (EaName.lowercased())) != nil {
//                                            self.currentEaValuesDict[EaName] = "\(EaValue ?? "")"
//                                        }
                                        //                                    self.lowercaseEaValuesDict[EaName.lowercased()] = EaName
                                    }
                                }   // switch - end
                                if self.writeHeader {
                                    for (tag, _) in fn_currentRecordDict {
                                        switch tag {
                                            case "deviceName":
                                                xmlTag = "computer name"
                                            case "siteName":
                                                xmlTag = "site"
                                            case "phone_number":
                                                xmlTag = "phone number"
                                            case "real_name":
                                                xmlTag = "full name"
                                            default:
                                                xmlTag = tag
                                        }
                                        recordText.append(xmlTag + ",")
                                    }
                                    recordText = recordText.substring(to: recordText.index(before: recordText.endIndex))
                                    self.writeToBackup(stringOfText: "\(recordText)\n")
                                    recordText = ""
                                    self.writeHeader = false
                                }
                                for (_, value) in fn_currentRecordDict {
                                    recordText.append(value + ",")
                                }
                                recordText = recordText.substring(to: recordText.index(before: recordText.endIndex))
                                self.writeToBackup(stringOfText: "\(recordText)\n")
                                recordText = ""

                                
                            }   // if let serverEndpointJSON - end
                        } catch {
                            print("[- debug -] Existing endpoints: error serializing JSON: \(error)\n")
                        }   // end do/catch

                        if httpResponse.statusCode >= 199 && httpResponse.statusCode <= 299 {
    //                        print("\nbackup record: \(fn_fullRecordDict)\n")
                            getResult = true
                        } else {
                            // something failed
                            print("httpResponse[failed]: \(httpResponse)")
                            print("statusCode[failed]: \(httpResponse.statusCode)")
                            getResult = false
                        }
                    }
                    
                    semaphore.signal()
                    if error != nil {
                    }
                })
                task.resume()
                semaphore.wait()
            }   // theOpQ.addOperation - end
            completion(getResult)
        } else {
            completion(true)
        }
    }
    
    func createFileFolder(itemPath: String, objectType: String) {
        if !fm.fileExists(atPath: itemPath) {
//          try to create backup directory
            if objectType == "folder" {
                do {
                    try fm.createDirectory(atPath: itemPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Problem creating \(itemPath) folder:  \(error)")
                }
            } else {
                do {
                    try fm.createFile(atPath: itemPath, contents: nil, attributes: nil)
                } catch {
                    print("Problem creating \(itemPath) folder:  \(error)")
                }
            }
        } // if !fm.fileExists -end
    }
    
    func getDateTime(x: Int8) -> String {
        let date = Date()
        let date_formatter = DateFormatter()
        if x == 1 {
            date_formatter.dateFormat = "YYYYMMdd_HHmmss"
        } else {
            date_formatter.dateFormat = "E d MMM yyyy HH:mm:ss"
        }
        let stringDate = date_formatter.string(from: date)
        
        return stringDate
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        let previewController: PreviewController = segue.destinationController as! PreviewController
        parseFile_Button(self)
        
        deviceType_Matrix.selectedRow == 0 ? (deviceType = "computers") : (deviceType = "mobiledevices")
//        print("Selected device type: \(deviceType)")
        
        let jamfCreds = "\(userName_TextField.stringValue):\(userPass_TextField.stringValue)"
        let jamfUtf8Creds = jamfCreds.data(using: String.Encoding.utf8)
        jamfBase64Creds = (jamfUtf8Creds?.base64EncodedString())!
        
        previewController.previewJssUrl = jssURL_TextField.stringValue
        previewController.previewJamfCreds = jamfBase64Creds
//        previewController.previewDeviceType = "computers"
        previewController.previewDeviceType = deviceType
        previewController.previewRecordID = "serialnumber"  // what identifies the asset
        
        previewController.prevAllRecordValuesArray = allRecordValuesArray
        previewController.prevLowercaseEaHeaderArray = safeEaHeaderArray
    }
    
    func updateCounts(remaining: Int, updated: Int, created: Int, failed: Int) {
        DispatchQueue.main.async {
            //self.mySpinner_ImageView.rotate(byDegrees: CGFloat(self.deg))
            self.remaining_TextField.stringValue = "\(remaining)"
            self.updated_TextField.stringValue = "\(updated)"
            self.failed_TextField.stringValue = "\(failed)"
            
        }
    }
    
    func writeToBackup(stringOfText: String) {
        self.backupFileHandle?.seekToEndOfFile()
        let recordText = (stringOfText as NSString).data(using: String.Encoding.utf8.rawValue)
        self.backupFileHandle?.write(recordText!)
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        self.view.layer?.backgroundColor = CGColor(red: 0x31/255.0, green:0x5B/255.0, blue:0x7E/255.0, alpha:0.5)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        jssURL_TextField.becomeFirstResponder()
        jssURL_TextField.window?.makeFirstResponder(jssURL_TextField)
        // Create application support and backup folder
        createFileFolder(itemPath: backupPath, objectType: "folder")
        
        // Create preference file if missing - start
        if !(fm.fileExists(atPath: appSupportPath + "settings.plist")) {
            do {
                try fm.copyItem(atPath: defaultSettings, toPath: appSupportPath + "settings.plist")
            }
            catch let error as NSError {
                NSLog("File copy failed! Something went wrong: \(error)")
            }
        }
        // Create preference file if missing - end
        
        // read environment settings - start
        let plistXML = fm.contents(atPath: appSupportPath + "settings.plist")!
        do{
            plistData = try PropertyListSerialization.propertyList(from: plistXML,
                                                                   options: .mutableContainersAndLeaves,
                                                                   format: &format)
                as! [String:AnyObject]
        }
        catch{
            NSLog("Error reading plist: \(error), format: \(format)")
        }
        if plistData["jamfProURL"] != nil {
            jssURL_TextField.stringValue = plistData["jamfProURL"] as! String
        }
        if plistData["username"] != nil {
            userName_TextField.stringValue = plistData["username"] as! String
        }
        // read environment search settings - end
        
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}

