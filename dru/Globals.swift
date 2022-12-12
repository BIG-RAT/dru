//
//  Globals.swift
//  dru
//
//  Created by Leslie Helou on 11/20/19.
//  Copyright © 2019 jamf. All rights reserved.
//

import Foundation

struct SourceServer {
    static var      url = ""
    static var    creds = ""
    static var username = ""
    static var password = ""
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

struct param {
    static var bundlePath       = Bundle.main.bundlePath
    static var fileManager      = FileManager.default
    
}
