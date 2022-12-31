//
//  Globals.swift
//  dru
//
//  Created by Leslie Helou on 11/20/19.
//  Copyright © 2019 jamf. All rights reserved.
//

import Foundation

let httpSuccess            = 200...299
var refreshInterval:UInt32 = 20*60  // 20 minutes
var runComplete            = false
var showLoginWindow = true
var startTime       = Date()
let userDefaults    = UserDefaults.standard

struct appInfo {
    static let dict            = Bundle.main.infoDictionary!
    static let version         = dict["CFBundleShortVersionString"] as! String
    static let name            = dict["CFBundleExecutable"] as! String
    static let userAgentHeader = "\(String(describing: name.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!))/\(appInfo.version)"
}

//let backupPath
//var backupFile 
//var backupFileHandle
struct backup {
    static let path = (NSHomeDirectory() + "/Library/Application Support/dru/backups/")
    static var file = ""
    static var fileHandle = FileHandle(forUpdatingAtPath: "")
}

struct jamfProServer {
    static var majorVersion = 0
    static var minorVersion = 0
    static var patchVersion = 0
    static var version      = ["source":"", "destination":""]
    static var build        = ""
    static var source       = ""
    static var destination  = ""
    static var whichServer  = ""
    static var sourceUser   = ""
    static var destUser     = ""
    static var sourcePwd    = ""
    static var destPwd      = ""
    static var storeCreds   = 0
    static var toSite       = false
    static var destSite     = ""
    static var importFiles  = 0
    static var authCreds    = ["source":"", "destination":""]
    static var authExpires  = ["source":"", "destination":""]
    static var authType     = ["source":"Bearer", "destination":"Bearer"]
    static var base64Creds  = ["source":"", "destination":""]
    static var validToken   = ["source":false, "destination":false]
    static var tokenCreated = [String:Date?]()
    static var pkgsNotFound = 0
    static var sessionCookie = [HTTPCookie]()
    static var stickySession = false
}

struct existing {
    static var   buildings = [String:String]()
    static var departments = [String:String]()
}

struct Log {
    static var path: String? = (NSHomeDirectory() + "/Library/Logs/dru/")
    static var file  = "dru.log"
    static var maxFiles = 10
    static var maxSize  = 500000 // 5MB
}

struct LogLevel {
    static var debug = false
}

struct param {
    static var bundlePath       = Bundle.main.bundlePath
    static var fileManager      = FileManager.default
    
}

func dateTime() -> String {
    let current = Date()
    let localCalendar = Calendar.current
    let dateObjects: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
    let dateTime = localCalendar.dateComponents(dateObjects, from: current)
    let currentMonth  = leadingZero(value: dateTime.month!)
    let currentDay    = leadingZero(value: dateTime.day!)
    let currentHour   = leadingZero(value: dateTime.hour!)
    let currentMinute = leadingZero(value: dateTime.minute!)
    let currentSecond = leadingZero(value: dateTime.second!)
    let stringDate = "\(dateTime.year!)\(currentMonth)\(currentDay)_\(currentHour)\(currentMinute)\(currentSecond)"
    return stringDate
}

// add leading zero to single digit integers
func leadingZero(value: Int) -> String {
    var formattedValue = ""
    if value < 10 {
        formattedValue = "0\(value)"
    } else {
        formattedValue = "\(value)"
    }
    return formattedValue
}

public func timeDiff(forWhat: String) -> (Int,Int,Int) {
    var components:DateComponents?
    switch forWhat {
    case "runTime":
        components = Calendar.current.dateComponents([.second, .nanosecond], from: startTime, to: Date())
    case "sourceTokenAge","destTokenAge":
        let whichServer = (forWhat == "sourceTokenAge") ? "source":"dsstination"
        components = Calendar.current.dateComponents([.second, .nanosecond], from: (jamfProServer.tokenCreated[whichServer] ?? Date())!, to: Date())
    default:
        break
    }
    
    let timeDifference = Int(components?.second! ?? 0)
    let (h,r) = timeDifference.quotientAndRemainder(dividingBy: 3600)
    let (m,s) = r.quotientAndRemainder(dividingBy: 60)
    return(h,m,s)
}

extension String {
    var fqdnFromUrl: String {
        get {
            var fqdn = ""
            let nameArray = self.components(separatedBy: "://")
            if nameArray.count > 1 {
                fqdn = nameArray[1]
            } else {
                fqdn =  self
            }
            if fqdn.contains(":") {
                let fqdnArray = fqdn.components(separatedBy: ":")
                fqdn = fqdnArray[0]
            }
            return fqdn
        }
    }
    var dropVersion: String {
        get {
            var newName = self
            let nameArray = self.components(separatedBy: " ")
            if nameArray.count > 3 {
                if nameArray[1] == "App" && nameArray[2] == "-" {
                    newName = nameArray.dropLast().joined(separator: " ")
//                    newName = nameArray.joined(separator: " ")
                }
            }
            return newName
        }
    }
    var urlFix: String {
        get {
            var fixedUrl = self.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
            fixedUrl = fixedUrl.replacingOccurrences(of: "/?failover", with: "")
            return fixedUrl
        }
    }
}
