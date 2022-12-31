//
//  AppDelegate.swift
//  dru
//
//  Created by Leslie Helou on 8/7/17.
//  Copyright © 2017 jamf. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    
    let fm = FileManager()
    let vc = ViewController()
    var isDir: ObjCBool = true
    
    // create blank data file - start
    @IBAction func blankDataFile(_ sender: NSMenuItem) {
        var theTemplate = ""
        var header:Data?

        let fileType = "\(sender.title)"
        switch fileType {
        case "iOS":
            theTemplate = "iOS_druTemplate.csv"
            header = "serial number,display name,asset tag,full name,username,email address,building,department,device phone number,site".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
        default:
            theTemplate = "macOS_druTemplate.csv"
            header = "serial number,computer name,asset tag,full name,username,email address,building,department,phone number,site".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
        }
        if !(fm.fileExists(atPath: NSHomeDirectory() + "/Downloads/\(theTemplate)")) {
            fm.createFile(atPath: NSHomeDirectory() + "/Downloads/\(theTemplate)", contents: nil, attributes: nil)
            let templateFileHandle = FileHandle(forUpdatingAtPath: (NSHomeDirectory() + "/Downloads/\(theTemplate)"))
            
            templateFileHandle?.write(header!)
            Alert().display(header: "Attention", message: "Template file, \(theTemplate), saved to Downloads.")
        } else {
            Alert().display(header: "Attention", message: "Template file, \(theTemplate), already exists in Downloads.")
        }
    }
    // create blank data file - end
    @IBAction func showBackups(_ sender: Any) {
        isDir = false
        if (FileManager().fileExists(atPath: backup.path, isDirectory: &isDir)) {
            NSWorkspace.shared.open(URL(fileURLWithPath: backup.path.appending("/.")))
        } else {
            Alert().display(header: "Alert", message: "There are currently no backup files to display.")
        }
    }
    
    @IBAction func showLogFolder(_ sender: Any) {
        isDir = false
        if (FileManager().fileExists(atPath: Log.path!.appending("/dru.log"), isDirectory: &isDir)) {
            let logFiles = [URL(fileURLWithPath: Log.path!.appending("/dru.log"))]
                    NSWorkspace.shared.activateFileViewerSelecting(logFiles)
        } else {
            Alert().display(header: "Alert", message: "There are currently no log files to display.")
        }
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {

    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application

    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    // quit the app if the window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return true
    }

}

