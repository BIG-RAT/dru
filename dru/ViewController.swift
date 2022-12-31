//
//  ViewController.swift
//  dru
//
//  Created by Leslie Helou on 8/7/17.
//  Copyright © 2017 jamf. All rights reserved.
//

import AppKit
import Cocoa
import Foundation
//import CoreFoundation
//import WebKit

class ViewController: NSViewController, SendingLoginInfoDelegate, URLSessionDelegate, NSTextFieldDelegate {

    @IBOutlet weak var window: NSWindow!
    
    @IBOutlet weak var dataFile_PathControl: NSPathControl!
    @IBOutlet weak var spinner: NSProgressIndicator!

    @IBOutlet weak var deviceType_Matrix: NSMatrix! // 0 - computers : 1 - iOS
    
    @IBOutlet weak var backup_button: NSButton!

    @IBOutlet weak var remaining_TextField: NSTextField!
    @IBOutlet weak var updated_TextField: NSTextField!
    @IBOutlet weak var failed_TextField: NSTextField!
    @IBOutlet weak var connectedTo_TextField: NSTextField!
    
    var jssURL          = ""
    var userName        = ""
    var userPass        = ""
    var jamfBase64Creds = ""
    var xmlString       = [String]()
    var deviceType      = ""
    var recordId        = "serialnumber"
    var backupBtnState  = 1 // 1 - backup before updating, 0 - no backup
    var attributeArray  = [String]()
    var createdBackup   = false
    var authResult      = "failed"
    
    var buildingsDict   = [String:String]()
    var departmentsDict = [String:String]()
    
    @IBOutlet weak var fileOrDir_TextField: NSTextField!
    
    var dataArray       = [String]()

    var pathToFile:URL?
    var theLineArray:[String] = []
    
    var firstDataLine = 0
    let headerArray = [String]()
    let knownHeadersArray = ["computer name", "display name", "serial number", "serial_number", "udid", "asset tag", "asset_tag", "full name",
                             "username", "email address", "email_address", "building", "department","position", "room", "phone number",
                             "user phone number", "device phone number", "phone", "site"]
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
    var allXmlFilesArray = [String]()
    
    let fm = FileManager.default
    var format = PropertyListSerialization.PropertyListFormat.xml //format of the property list
    var plistData:[String:AnyObject] = [:]  // settings data
    let appSupportPath = (NSHomeDirectory() + "/Library/Application Support/dru/")
    let defaultSettings = Bundle.main.path(forResource: "settings", ofType: "plist")!
    var writeHeader = true
    
    @IBAction func f_backupBtnState(_ sender: NSButton) {
        DispatchQueue.main.async {
            self.backupBtnState = self.backup_button.state.rawValue
        }
    }
    
    // Delegate Method
    func sendLoginInfo(loginInfo: (String,String,String,Int)) {
        var saveCredsState: Int?
        (jamfProServer.source, jamfProServer.sourceUser, jamfProServer.sourcePwd,saveCredsState) = loginInfo
        let jamfUtf8Creds = "\(jamfProServer.sourceUser):\(jamfProServer.sourcePwd)".data(using: String.Encoding.utf8)
        jamfProServer.base64Creds["source"] = (jamfUtf8Creds?.base64EncodedString())!
        
        // check authentication, check version, set auth method - start
        WriteToLog().message(stringOfText: "[ViewController] Running dru v\(appInfo.version)")
        TokenDelegate().getToken(whichServer: "source", serverUrl: jamfProServer.source, base64creds: jamfProServer.base64Creds["source"]!) { [self]
            authResult in
            let (statusCode,theResult) = authResult
            if theResult == "success" {
                userDefaults.set(jamfProServer.source, forKey: "server")
                userDefaults.set(jamfProServer.sourceUser, forKey: "username")
                if saveCredsState == 1 {
                    Credentials2().save(service: "lastrun-\(jamfProServer.source.fqdnFromUrl)", account: jamfProServer.sourceUser, data: jamfProServer.sourcePwd)
                }
                connectedTo_TextField.stringValue = "Connected to: " + jamfProServer.source.fqdnFromUrl
            } else {
                DispatchQueue.main.async { [self] in
                    performSegue(withIdentifier: "loginView", sender: nil)
//                        working(isWorking: false)
                }
            }
        }
        // check authentication - stop
    }
    
    @IBAction func loadFile_PathControl(_ sender: NSPathControl) {
        spinner(isRunning: true)
        loadFileContents(theUrl: dataFile_PathControl.url!)
    }
    
    func loadFileContents(theUrl: URL) {
        DispatchQueue.global(qos: .background).async { [self] in
            //      ensure arrays are empty
            safeHeaderArray.removeAll()
            safeEaHeaderArray.removeAll()
            theLineArray.removeAll()
            allRecordValuesArray.removeAll()
            allXmlFilesArray.removeAll()
            // parse header row, change lowercase start
//            if let pathToFile = pathControl.url {
            DispatchQueue.main.async {
                let pathToFile = theUrl
            //                print("\(#line) self.dataFile_PathControl: \(self.dataFile_PathControl.url?.path)")
                let objPath: URL!

    //            if let pathOrDirectory = theUrl {
                let pathOrDirectory = theUrl
                WriteToLog().message(stringOfText: "fileOrPath: \(pathOrDirectory)")
                
                objPath = URL(string: "\(pathOrDirectory)")!
                var isDir : ObjCBool = false
                self.fileOrDir_TextField.stringValue = "--------"
                sleep(1)
                _ = self.fm.fileExists(atPath: objPath.path, isDirectory:&isDir)
                if isDir.boolValue {
                    self.fileOrDir_TextField.stringValue = "directory"
                    do {
                        let xmlFiles = try self.fm.contentsOfDirectory(atPath: objPath.path)
                        for xmlFile in xmlFiles {
                            let xmlFilePath: String = "\(objPath.path)\(xmlFile)"
                            self.allXmlFilesArray.append(xmlFilePath)
                        }
                        self.totalRecords = self.allXmlFilesArray.count
                    } catch {
                        Alert().display(header: "Warning", message: "Error reading directory")
                        WriteToLog().message(stringOfText: "Error reading directory")
                        self.spinner(isRunning: false)
                        return
                    }
                } else {
                    self.fileOrDir_TextField.stringValue = "file"
                    do {
                        let dataFile =  try Data(contentsOf:pathToFile)
                        let attibutedString = try NSAttributedString(data: dataFile, documentAttributes: nil)
                        let fileText = attibutedString.string
                        let allLines = fileText.components(separatedBy: CharacterSet.newlines)
                        // create header array - start
    //                            if self.hasHeader_Button.state.rawValue == 1 {
                        var safeHeaderIndex = 0
                        var safeEaHeaderIndex = 0
                        let headerArray = self.createFieldArray(theString: allLines[0])
                        self.firstDataLine = 1
                        self.headerCount = headerArray.count
                        //                    WriteToLog().message(stringOfText: "headerArray: \(headerArray)")
                        //                    WriteToLog().message(stringOfText: "headerCount: \(headerArray.count)")
                        for i in 0..<self.headerCount {
                            if self.knownHeadersArray.firstIndex(of: (headerArray[i] ).lowercased()) != nil {
                                let lowercaseHeader = "\(headerArray[i] )".lowercased()
                                self.safeHeaderArray.append(lowercaseHeader)
                                switch lowercaseHeader {
                                case "computer name", "display name":
                                    self.safeHeaderArray[safeHeaderIndex] = "deviceName"
                                case "serial number":
                                    self.safeHeaderArray[safeHeaderIndex] = "serial_number"
                                case "asset tag":
                                    self.safeHeaderArray[safeHeaderIndex] = "asset_tag"
                                case "site":
                                    self.safeHeaderArray[safeHeaderIndex] = "siteName"
                                case "full name":
                                    self.safeHeaderArray[safeHeaderIndex] = "real_name"
                                case "email address":
                                    self.safeHeaderArray[safeHeaderIndex] = "email_address"
                                case "phone number", "user phone number":
                                    self.safeHeaderArray[safeHeaderIndex] = "phone_number"
                                default: break
                                    // all good
                                }
                                safeHeaderIndex += 1
                            } else {
                                // load extension attribute headers - start
                                let lowercaseEaHeader = "\(headerArray[i] )".lowercased()
                                self.safeEaHeaderArray.append(lowercaseEaHeader)
                                self.safeHeaderArray.append("_" + lowercaseEaHeader)
                                //                            safeEaHeaderArray.append((headerArray[i] as AnyObject).lowercased)
                                //                            safeHeaderArray.append("_" + (headerArray[i] as AnyObject).lowercased)
                                safeHeaderIndex   += 1
                                safeEaHeaderIndex += 1
                                // load extension attribute headers - end
                            }
                        }
                            //                    WriteToLog().message(stringOfText: "Built in Headers: \(safeHeaderArray)")
                            //                    WriteToLog().message(stringOfText: "EA Headers: \(safeEaHeaderArray)")
    //                            }
                        // create header array - end
                        if self.safeHeaderArray.count == 0 {
                            Alert().display(header: "Warning", message: "Unable to identify any headers!")
                            self.spinner(isRunning: false)
                            return
                        }
                        // parse data - start
                        for i in self.firstDataLine..<allLines.count {
                            if allLines[i] != "" {
                                //                                    WriteToLog().message(stringOfText: "\(i): \(allLines[i])")
                                self.allRecordValuesArray.append(self.xml(headerArray: self.safeHeaderArray , dataArray: self.createFieldArray(theString: allLines[i])))
                            }
                        }
                        // parse data - end
                        //                WriteToLog().message(stringOfText: "data: \(allRecordValuesArray)")
                    } catch {
                        WriteToLog().message(stringOfText: "file read error")
                        self.spinner(isRunning: false)
                        return
                    }
                    self.totalRecords = self.allRecordValuesArray.count
                }
                        
    //                }
                    
    //            }
                self.updateCounts(remaining: self.totalRecords, updated: 0, created: 0, failed: 0)
                self.spinner(isRunning: false)
            }
            
        }
    }
    
    
    @IBAction func parseFile_Button(_ sender: Any) {
        // fetch existing buildings and departments - start
        buildingsDict.removeAll()
        existing.buildings.removeAll()
        departmentsDict.removeAll()
        self.authResult = "succeeded"
        Json().getRecord(theServer: "\(jamfProServer.source)", base64Creds: jamfProServer.base64Creds["source"]!, theEndpoint: "buildings") { [self]
            (result: [String:AnyObject]) in
            if result.count == 0 {
                // authentication failed
                self.authResult = "failed"
                DispatchQueue.main.async {
                    self.spinner(isRunning: false)
                }
                return
            }
            let existingBuildingArray = result["buildings"] as! [[String:Any]]
            for theBuilding in existingBuildingArray {
                if let _ = theBuilding["id"], let _ = theBuilding["name"] {
                    self.buildingsDict[(theBuilding["name"] as! String).lowercased()] = (theBuilding["name"] as! String)
                    existing.buildings[(theBuilding["name"] as! String).lowercased()] = (theBuilding["name"] as! String)
                }
            }
            WriteToLog().message(stringOfText: "[parseFile_Button] existing.buildings: \(existing.buildings)")
            deviceType_Matrix.selectedRow == 0 ? (deviceType = "computers") : (deviceType = "mobiledevices")
            if (sender as AnyObject).title == "Update" {
                if totalRecords > 0 {
                    // Fix - change this so it only writes with a successful auth
                    userDefaults.set("\(jamfProServer.source)", forKey: "jamfProURL")
                    
                    self.backupBtnState = self.backup_button.state.rawValue
                    
                    var successCount = 0
                    var failCount    = 0
                    var remaining    = allRecordValuesArray.count

                    self.spinner(isRunning: true)

                switch deviceType {
                    case "computers":
                        for i in 0..<allRecordValuesArray.count {
                            let Uid = "\(allRecordValuesArray[i]["serial_number"] ?? "")"
                            let updateDeviceXml = "\(generateXml(deviceType: "computers", localRecordDict: allRecordValuesArray[i]))"
                            WriteToLog().message(stringOfText: "valuesDict: \(allRecordValuesArray[i])")

                            update(DeviceType: "computers", endpointXML: updateDeviceXml, endpointCurrent: i+1, endpointCount: allRecordValuesArray.count, action: "PUT", uniqueID: Uid) {
                                    (result: Bool) in
                                    if result {
                                        successCount += 1
                                    } else {
                                        failCount += 1
                                    }
                                    remaining -= 1
                                    self.updateCounts(remaining: remaining, updated: successCount, created: 0, failed: failCount)
                                    return true
                                }
                            }
                        case "mobiledevices":
                            for i in 0..<allRecordValuesArray.count {
                                let Uid = "\(allRecordValuesArray[i]["serial_number"] ?? "")"
                                let updateDeviceXml = "\(generateXml(deviceType: "mobiledevices", localRecordDict: allRecordValuesArray[i]))"
                                
                                update(DeviceType: "mobiledevices", endpointXML: updateDeviceXml, endpointCurrent: i+1, endpointCount: allRecordValuesArray.count, action: "PUT", uniqueID: Uid) {
                                    (result: Bool) in
                                    if result {
                                        successCount += 1
                                    } else {
                                        failCount += 1
                                    }
                                    remaining -= 1
                                    self.updateCounts(remaining: remaining, updated: successCount, created: 0, failed: failCount)
                                    return true
                                }
                            }
                        default:
                            break
                    }   // switch deviceType - end
                } else {
                    Alert().display(header: "Attention:", message: "No records found to update, verify CSV file.")
                }
            } else {
                WriteToLog().message(stringOfText: "preview deviceType: \(deviceType)")
                performSegue(withIdentifier: "preview", sender: nil)
            }
        }
        // fetch existing buildings and departments - end
    }
    
    
    @IBAction func logout(_ sender: AnyObject) {
            DispatchQueue.main.async { [self] in
                performSegue(withIdentifier: "loginView", sender: nil)
                connectedTo_TextField.stringValue = ""
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
        
        //WriteToLog().message(stringOfText: "starting check")
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
                    //WriteToLog().message(stringOfText: "entered quoted field")
                    while QuotedField && charPosition < strLength {
                        charPosition += 1
                        index = theString.index(theString.startIndex, offsetBy: charPosition)
                        //WriteToLog().message(stringOfText: "quoted field: \(theString[index!])\tIndex: \(String(describing: index))")
                        currChar = "\(theString[index!])"
                        if prevChar == "\"" && currChar == "," && writeQuoteChar {
                            QuotedField = false
                            writeQuoteChar = true
                            
//                            WriteToLog().message(stringOfText: "end quoted field")
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
        WriteToLog().message(stringOfText: "fieldArray: \(fieldArray)")
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
        //        WriteToLog().message(stringOfText: "safeHeaderArray: \(safeHeaderArray)\t\t dataArray: \(dataArray)\t\t xmlKey: \(xmlKey)")
        
        //safeHeaderArray.contains(xmlKey) ? (theValue = dataArray[safeHeaderArray.index(of: xmlKey)] as! String) : (theValue = "")
        if safeHeaderArray.contains(xmlKey) {
            if safeHeaderArray.firstIndex(of: xmlKey)! < dataArray.count {
                theValue = dataArray[safeHeaderArray.firstIndex(of: xmlKey)!]
                theValue = xmlEncode(rawString: "\(theValue)")
            }
        }
        return theValue
    }
    
    func generateXml(deviceType: String, localRecordDict: [String: String]) -> String {
        var localDeviceName   = ""
        var localAssetTag     = ""
        var localSiteName     = ""
        var localUsername     = ""
        var localRealName     = ""
        var localEmailAddress = ""
        var localPosition     = ""
        var localPhone        = ""
        var localDepartment   = ""
        var localBuilding     = ""
        var localRoom         = ""
        var localEa           = ""
        var newValue          = ""
        
        var localDevice       = ""    // define device xml tag, computer or mobile_device
        
        for (key,value) in localRecordDict {
//            WriteToLog().message(stringOfText: "key: \(key)\t value: \(value)")
            // allow a single space to be used to remove an attribute
            switch value {
            case " ":
                newValue = ""
            default:
                newValue = value
            }
            switch key.lowercased() {
            case "deviceName":
                value == "" ? (localDeviceName = "") : (localDeviceName = "<name>\(newValue)</name>")
            case "asset_tag":
                value == "" ? (localUsername = "") : (localAssetTag = "<asset_tag>\(newValue)</asset_tag>")
            case "siteName":
                value == "" ? (localSiteName = "") : (localSiteName = "<site><name>\(newValue)</name></site>")
            case "username":
                value == "" ? (localUsername = "") : (localUsername = "<username>\(newValue)</username>")
            case "real_name":
                value == "" ? (localRealName = "") : (localRealName = "<real_name>\(newValue)</real_name>")
            case "email_address":
                value == "" ? (localEmailAddress = "") : (localEmailAddress = "<email_address>\(newValue)</email_address>")
            case "position":
                value == "" ? (localPosition = "") : (localPosition = "<position>\(newValue)</position>")
            case "phone_number":
                value == "" ? (localPhone = "") : (localPhone = "<phone>\(newValue)</phone>")
            case "department":
                value == "" ? (localDepartment = "") : (localDepartment = "<department>\(newValue)</department>")
            case "building":
                value == "" ? (localBuilding = "") : (localBuilding = "<building>\(newValue)</building>")
            case "room":
                value == "" ? (localRoom = "") : (localRoom.append("<room>\(newValue)</room>"))
            default:
                // handle extension attributes here
                if key.first == "_" {
                    var name = key
                    name.remove(at: name.startIndex)
//                    name.characters.dropFirst(1)
//                    WriteToLog().message(stringOfText: name)
                    value == "" ? (localEa.append("")) : (localEa.append("<extension_attribute><name>\(name)</name><value>\(newValue)</value></extension_attribute>"))
                }
            }
        }
        deviceType == "computers" ? (localDevice = "computer") : (localDevice = "mobile_device")
        var generatedXml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
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
        
        WriteToLog().message(stringOfText: "[ViewController] generatedXml: \(generatedXml)")
        
        // verify building and/or department exists (when needed) before returning
        if localRecordDict["building"] != nil && localRecordDict["building"] != "" {
            if existing.buildings[localRecordDict["building"]!.lowercased()] == nil {
                WriteToLog().message(stringOfText: "[ViewController-generateXML] [issue] device \(String(describing: localRecordDict["serial_number"]!)), need to create building: \(String(describing: localBuilding))")
                generatedXml = "issue"
            }
        }
        if localRecordDict["department"] != nil && localRecordDict["department"] != "" {
            if existing.departments[localRecordDict["department"]!.lowercased()] == nil {
                WriteToLog().message(stringOfText: "[ViewController-generateXML] [issue] device \(String(describing: localRecordDict["serial_number"]!)), need to create department: \(String(describing: localRecordDict["department"]!))")
                generatedXml = "issue"
            }
        }
        return "\(generatedXml)"
    }
    
    func update(DeviceType: String, endpointXML: String, endpointCurrent: Int, endpointCount: Int, action: String, uniqueID: String, completion: @escaping (Bool) -> Bool) {
        // this is where we create the new endpoint
        if endpointXML == "issue" {
            completion(false)
            return
        }
        let safeCharSet = CharacterSet.alphanumerics
//        jssURL = self.jamfProServer.source
        var DestURL = ""
        let Uid = "\(uniqueID)".addingPercentEncoding(withAllowedCharacters: safeCharSet)!
        
        DestURL = "\(jamfProServer.source)/JSSResource/\(DeviceType)/\(self.recordId)/\(Uid)"
        DestURL = DestURL.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
        
        theUpdateQ.maxConcurrentOperationCount = 3
        let semaphore = DispatchSemaphore(value: 0)
        let encodedXML = endpointXML.data(using: String.Encoding.utf8)
        
        theUpdateQ.addOperation {
            
//            WriteToLog().message(stringOfText: "processing device \(endpointCurrent)")
//            WriteToLog().message(stringOfText: "URL: \(DestURL)")
//            WriteToLog().message(stringOfText: "XML: \(endpointXML)\n")
            WriteToLog().message(stringOfText: "[update] DestURL: \(DestURL)")
            let encodedURL = URL(string: DestURL)
            let request = NSMutableURLRequest(url: encodedURL! as URL)
            
            // backup record here
            self.backupRecord(deviceUrl: DestURL, fn_deviceType: DeviceType) {
//                self.backupRecord(deviceId: Uid, fn_deviceType: self.deviceType) {
                (backupResult: Bool) in
                
//                WriteToLog().message(stringOfText: "returned from backup: \(Uid)")
                
                if action == "PUT" {
                    request.httpMethod = "PUT"
                } else {
                    request.httpMethod = "POST"
                }
                let configuration = URLSessionConfiguration.default
                configuration.httpAdditionalHeaders = ["Authorization" : "\(String(describing: jamfProServer.authType["source"]!)) \(String(describing: jamfProServer.authCreds["source"]!))", "Content-Type" : "application/xml", "Accept" : "application/xml", "User-Agent" : appInfo.userAgentHeader]
                request.httpBody = encodedXML!
                let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
                let task = session.dataTask(with: request as URLRequest, completionHandler: {
                    (data, response, error) -> Void in
                    if let httpResponse = response as? HTTPURLResponse {

                        if httpResponse.statusCode >= 199 && httpResponse.statusCode <= 299 {
//                            WriteToLog().message(stringOfText: "---------- Success ----------")
//                            WriteToLog().message(stringOfText: "\(endpointXML)")
                            WriteToLog().message(stringOfText: "[update] updated \(DeviceType) \(Uid)")
                            completion(true)
                        } else {
                            // http failed
                            // 401 - wrong username and/or password
                            // 409 - unable to create object; already exists or data missing or xml error
                            WriteToLog().message(stringOfText: "[update] failed to updated \(DeviceType) (\(Uid))")
                            WriteToLog().message(stringOfText: "[update] httpResponse: \(httpResponse)")
                            WriteToLog().message(stringOfText: "[update] statusCode: \(httpResponse.statusCode)")
                            WriteToLog().message(stringOfText: "[update] \(endpointXML)")
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
    
    
    func backupRecord(deviceUrl: String, fn_deviceType: String, completion: @escaping (_ backupResult: Bool) -> Void) {
//        func backupRecord(deviceId: String, fn_deviceType: String, completion: @escaping (_ backupResult: Bool) -> Void) {
        let semaphore = DispatchSemaphore(value: 1)
        
        if backupBtnState  == 1 {
            var fn_fullRecordDict = [String:Any]()
            var getResult = false
            var fn_currentRecordDict = [String:String]()
            var fn_generalDict = [String:Any]()
            var fn_locationDict = [String:Any]()
            var fn_extAttributesDict = [Dictionary<String, Any>]()
            var recordText = ""
            var xmlTag = ""
            
            if !createdBackup {
                dateTime = getDateTime(x: 1)
                backup.file = backup.path + dateTime + ".csv"
                createFileFolder(itemPath: backup.file, objectType: "file")
                backup.fileHandle = FileHandle(forUpdatingAtPath: backup.file)
                writeHeader = true
                createdBackup = true
            }
            
//                serverUrl = "\(jssURL)/JSSResource/\(fn_deviceType)/\(self.recordId)/\(deviceId)"
//                let serverUrl = deviceUrl   // serverUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
                //            WriteToLog().message(stringOfText: "serverUrl: \(serverUrl)")
            
                let serverEncodedURL = URL(string: deviceUrl)
                let serverRequest = NSMutableURLRequest(url: serverEncodedURL! as URL)
                //            print("serverRequest: \(serverRequest)")
                serverRequest.httpMethod = "GET"
//                WriteToLog().message(stringOfText: "getting: \(deviceUrl)")
            
                let configuration = URLSessionConfiguration.default
                configuration.httpAdditionalHeaders = ["Authorization" : "\(String(describing: jamfProServer.authType["source"]!)) \(String(describing: jamfProServer.authCreds["source"]!))", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : appInfo.userAgentHeader]
                //            fn_request.httpBody = encodedXML!
                let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
            
                self.theBackupQ.async {
                    let task = session.dataTask(with: serverRequest as URLRequest, completionHandler: {
                        (data, response, error) -> Void in
                        if let httpResponse = response as? HTTPURLResponse {
        //                    WriteToLog().message(stringOfText: "statusCode: ",httpResponse.statusCode)
        //                    WriteToLog().message(stringOfText: "httpResponse: ",httpResponse)
                            //WriteToLog().message(stringOfText: "POST XML-\(endpointCurrent): endpointType: \(endpointType)  endpointNumber: \(endpointCurrent)")
                            do {
                                let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                                if let endpointJSON = json as? [String: Any] {
                                    switch fn_deviceType {
                                    case "computers":
//                                        WriteToLog().message(stringOfText: "computer case")
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
        //                                WriteToLog().message(stringOfText: "\nEAs: \(fn_extAttributesDict.count)")
        //                                WriteToLog().message(stringOfText: "EAs: \(fn_extAttributesDict)")
                                        for i in (0..<fn_extAttributesDict.count) {
                                            let EaName = fn_extAttributesDict[i]["name"] as! String
                                            let EaValue = fn_extAttributesDict[i]["value"]
                                            fn_currentRecordDict[EaName] = (EaValue as! String)
                                        }
                                        
                                    // default is iOS
                                    default:
//                                        WriteToLog().message(stringOfText: "iOS case")
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
    //                                                                    WriteToLog().message(stringOfText: "\nEAs: \(fn_extAttributesDict.count)")
    //                                                                    WriteToLog().message(stringOfText: "EAs: \(fn_extAttributesDict)")
                                        for i in (0..<fn_extAttributesDict.count) {
                                            let EaName = fn_extAttributesDict[i]["name"] as! String
                                            let EaValue = fn_extAttributesDict[i]["value"]
                                            fn_currentRecordDict[EaName] = (EaValue as! String)
                                        }
                                    }   // switch - end
                                    
                                    for (key, value) in fn_currentRecordDict {
                                        fn_currentRecordDict[key] = self.quoteCommaInField(field: value)
//                                        WriteToLog().message(stringOfText: "\(key): \(String(describing: fn_currentRecordDict[key]!))")
                                        if self.attributeArray.count < fn_currentRecordDict.count {
                                            self.attributeArray.append(key)
                                        }
                                    }
                                    
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
    //                                    recordText = recordText.substring(to: recordText.index(before: recordText.endIndex))  //swift 3 code
                                        recordText = String(recordText[..<recordText.endIndex])
                                        self.writeToBackup(stringOfText: "\(recordText)\n")
                                        recordText = ""
                                        self.writeHeader = false
                                    }
                                   // for (_, value) in fn_currentRecordDict {
                                    for attribute in self.attributeArray {
//                                        recordText.append(value + ",")
                                        recordText.append("\(String(describing: fn_currentRecordDict[attribute]!))" + ",")
                                    }
    //                                recordText = recordText.substring(to: recordText.index(before: recordText.endIndex))  //swift 3 code
                                    recordText = String(recordText[..<recordText.endIndex])
                                    self.writeToBackup(stringOfText: "\(recordText)\n")
                                    recordText = ""

                                    
                                }   // if let serverEndpointJSON - end
                            } catch {
                                WriteToLog().message(stringOfText: "[- debug -] Existing endpoints: error serializing JSON: \(error)\n")
                            }   // end do/catch

                            if httpResponse.statusCode >= 199 && httpResponse.statusCode <= 299 {
        //                        WriteToLog().message(stringOfText: "\nbackup record: \(fn_fullRecordDict)\n")
                                getResult = true
                            } else {
                                // something failed
                                WriteToLog().message(stringOfText: "httpResponse[backupQ failed]: \(httpResponse)")
                                WriteToLog().message(stringOfText: "statusCode[backupQ failed]: \(httpResponse.statusCode)")
                                getResult = false
                            }
                        }
                        
                        semaphore.signal()
                        if error != nil {
                        }
                    })
                    task.resume()
                    semaphore.wait()
                }   // self.theBackupQ.async - end
                completion(getResult)
//            } else {
//                completion(true)
        } else {   // if backupBtnState - end
            completion(true)
        }
        
    }
    
    func quoteCommaInField(field: String) -> String {
        var newValue = field
        if field.contains(",") {
            newValue = "\"\(field)\""
        }
        return newValue
    }
    
    func createFileFolder(itemPath: String, objectType: String) {
        if !fm.fileExists(atPath: itemPath) {
//          try to create backup directory
            if objectType == "folder" {
                do {
                    try fm.createDirectory(atPath: itemPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    WriteToLog().message(stringOfText: "Problem creating \(itemPath) folder:  \(error)")
                }
            } else {
                do {
                    try fm.createFile(atPath: itemPath, contents: nil, attributes: nil)
                } catch {
                    WriteToLog().message(stringOfText: "Problem creating \(itemPath) folder:  \(error)")
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
            if segue.identifier == "loginView" {
                let loginVC: LoginViewController = segue.destinationController as! LoginViewController
                loginVC.delegate = self
            } else if segue.identifier == "preview" {
                WriteToLog().message(stringOfText: "number of records: \(totalRecords)")
                let previewVC: PreviewController = segue.destinationController as! PreviewController
                
                deviceType_Matrix.selectedRow == 0 ? (deviceType = "computers") : (deviceType = "mobiledevices")
                //        print("Selected device type: \(deviceType)")
                                
                previewVC.authResult        = authResult
                previewVC.previewDeviceType = deviceType
                previewVC.previewRecordID   = "serialnumber"  // what identifies the asset
                
                previewVC.prevAllRecordValuesArray   = allRecordValuesArray
                previewVC.prevLowercaseEaHeaderArray = safeEaHeaderArray
            }
    }
    
    func spinner(isRunning: Bool) {
        if isRunning {
            spinner.startAnimation(self)
        } else {
            spinner.stopAnimation(self)
        }
    }
    
    func updateCounts(remaining: Int, updated: Int, created: Int, failed: Int) {
//        WriteToLog().message(stringOfText: "remaining: \(remaining) \n updated: \(updated)\n created: \(created)\n failed: \(failed)")
        DispatchQueue.main.async { [self] in
            //self.mySpinner_ImageView.rotate(byDegrees: CGFloat(self.deg))
            remaining_TextField.stringValue = "\(remaining)"
            updated_TextField.stringValue   = "\(updated)"
            failed_TextField.stringValue    = "\(failed)"
            if remaining == 0 {
                backup.fileHandle?.closeFile()
                createdBackup  = false
                attributeArray = [String]()
                spinner(isRunning: false)
            } else if updated == 0 && created == 0 && failed == 0 {
                spinner(isRunning: false)
            }
        }
    }
    
    func writeToBackup(stringOfText: String) {
        backup.fileHandle?.seekToEndOfFile()
        let recordText = (stringOfText as NSString).data(using: String.Encoding.utf8.rawValue)
        backup.fileHandle?.write(recordText!)
    }
    
    func xmlEncode(rawString: String) -> String {
        var encodedString = rawString
        encodedString = encodedString.replacingOccurrences(of: "&", with: "&amp;")
        encodedString = encodedString.replacingOccurrences(of: "\"", with: "&quot;")
        encodedString = encodedString.replacingOccurrences(of: "'", with: "&apos;")
        encodedString = encodedString.replacingOccurrences(of: ">", with: "&gt;")
        encodedString = encodedString.replacingOccurrences(of: "<", with: "&lt;")
        return encodedString
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
//        self.view.layer?.backgroundColor = CGColor(red: 0x31/255.0, green:0x5B/255.0, blue:0x7E/255.0, alpha:0.5)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Create application support and backup folder
        createFileFolder(itemPath: backup.path, objectType: "folder")
        dataFile_PathControl.allowedTypes = ["csv", "txt"]
        
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
        
        let plistXML = fm.contents(atPath: appSupportPath + "settings.plist")!
        do{
            plistData = try PropertyListSerialization.propertyList(from: plistXML,
                                                                   options: .mutableContainersAndLeaves,
                                                                   format: &format)
                as! [String:AnyObject]
        }
        catch{
            WriteToLog().message(stringOfText: "Error reading plist: \(error), format: \(format)")
        }
        // read environment search settings - end
        
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()

        if showLoginWindow {
            performSegue(withIdentifier: "loginView", sender: nil)
            showLoginWindow = false
        }
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}

