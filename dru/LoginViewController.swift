//
//  LoginViewController.swift
//  dru
//
//  Created by Leslie Helou on 01/17/22.
//  Copyright © 2022 Leslie Helou. All rights reserved.
//

import Cocoa
import Foundation

protocol SendingLoginInfoDelegate {
    func sendLoginInfo(loginInfo: (String,String,String,Int))
}

class LoginViewController: NSViewController {
    
    @IBOutlet var server_textfield: NSTextField!
    @IBOutlet var username_textfield: NSTextField!
    @IBOutlet var password_textfield: NSTextField!
    
    @IBOutlet var savePassword_Button: NSButton!
    
    var delegate: SendingLoginInfoDelegate? = nil
    
    let defaults = UserDefaults.standard
    
//    @IBAction func savePassword_Action(_ sender: Any) {
//        if savePassword_Button.state.rawValue == 1 {
//            self.defaults.set(1, forKey: "passwordButton")
//        } else {
//            self.defaults.set(0, forKey: "passwordButton")
//        }
//    }
    
    @IBAction func saveCreds_action(_ sender: NSButton) {
        userDefaults.set(sender.state.rawValue, forKey: "saveCreds")
        userDefaults.synchronize()
    }

    @IBAction func login_action(_ sender: Any) {
        let dataToBeSent = (server_textfield.stringValue, username_textfield.stringValue, password_textfield.stringValue,savePassword_Button.state.rawValue)
        delegate?.sendLoginInfo(loginInfo: dataToBeSent)
        dismiss(self)
    }
    
    @IBAction func quit_Action(_ sender: Any) {
        dismiss(self)
        NSApplication.shared.terminate(self)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        server_textfield.stringValue = defaults.string(forKey: "server") as? String ?? ""
        savePassword_Button.state    = NSControl.StateValue(userDefaults.integer(forKey: "saveCreds"))
        // read environment settings - start
        if let _ = userDefaults.string(forKey: "jamfProURL") {
            server_textfield.stringValue = userDefaults.string(forKey: "jamfProURL")!
            let regexKey = try! NSRegularExpression(pattern: "http(.*?)://", options:.caseInsensitive)
            let credKey  = regexKey.stringByReplacingMatches(in: server_textfield.stringValue, options: [], range: NSRange(0..<server_textfield.stringValue.utf16.count), withTemplate: "").replacingOccurrences(of: "?failover", with: "")
            let credentailArray = Credentials2().retrieve(service: "dru-"+credKey)
            if credentailArray.count == 2 {
                username_textfield.stringValue = credentailArray[0]
                password_textfield.stringValue = credentailArray[1]
            } else {
                username_textfield.stringValue = defaults.object(forKey: "username") as? String ?? ""
                password_textfield.stringValue = ""
            }
        } else {
            server_textfield.stringValue = "https://"
        }
        
        // bring app to foreground
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
}
