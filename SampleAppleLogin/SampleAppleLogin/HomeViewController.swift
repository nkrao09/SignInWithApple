//
//  HomeViewController.swift
//  SampleAppleLogin
//
//  Created by Karthik on 16/08/20.
//  Copyright © 2020 Karthik. All rights reserved.
//

import UIKit
import KeychainAccess

class HomeViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var userInfoTextView: UITextView!
    var authorizationInfo: NKAppleUserAuthorizationInfo? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        showUserData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerAppleIDStateNotification()
    }
    
    // MARK: - UI Setup
    private func setupNavigationBar() {
        self.title = "Dashboard"
        self.navigationController?.navigationBar.isHidden = false
        self.navigationItem.hidesBackButton = true
        
        showRightBarbuttons()
    }
    
    private func showRightBarbuttons() {
        guard let authorizationInfo = authorizationInfo else {
            return
        }
        
        var rightBarButtonItems = [UIBarButtonItem]()
        
        let logoutButtom = UIBarButtonItem(title: "Logout", style: .done, target: self, action: #selector(logout))
        rightBarButtonItems.append(logoutButtom)
        
        if authorizationInfo.appleUserPersonalInfo?.email == nil {
            let emailExtractButton = UIBarButtonItem(title: "Ext", style: .done, target: self, action: #selector(extractEmail))
            rightBarButtonItems.append(emailExtractButton)
        }
        self.navigationItem.rightBarButtonItems = rightBarButtonItems
    }
    
    //MARK: - Notifications
    private func registerAppleIDStateNotification() {
        NKAppleAuthorizationManager.shared.registerNotificationObserverForAppIDStateChange(on: self, selector: #selector(appleIDStateChangeNotification(_:)))
    }
    
    @objc private func appleIDStateChangeNotification(_ notification: NSNotification) {
        /// Logout the user
        self.logout()
    }
    
    //MARK: - Other functional methods
    /// Populate user data
    private func showUserData(_ email: String? = nil) {
        guard let authorizationInfo = authorizationInfo else {
            return
        }
        DispatchQueue.main.async {
            self.titleLabel.text = ("Welcome, \(authorizationInfo.appleUserPersonalInfo?.firstName ?? "") \(authorizationInfo.appleUserPersonalInfo?.lastName ?? "")!")
            
            self.userInfoTextView.text = """
            
            First name: \(authorizationInfo.appleUserPersonalInfo?.firstName ?? "EMPTY")
            Last name: \(authorizationInfo.appleUserPersonalInfo?.lastName ?? "EMPTY")
            Email: \(authorizationInfo.appleUserPersonalInfo?.email ?? (email ?? "EMPTY"))
            
            User Identifier: \(authorizationInfo.userIdentifier)
            
            Auth Code: \(String(describing: String(data: authorizationInfo.authCode!, encoding: .utf8)))
            
            Identity Token: \(String(describing: String(data: authorizationInfo.identityToken!, encoding: .utf8)))
            """
        }
        
        saveUserIdentifier()
    }
    
    private func saveUserIdentifier() {
        guard let authorizationInfo = authorizationInfo else {
            return
        }
        let keychain = Keychain(service: "com.mcdonalds.gma.test.signin")
        keychain["userIdentifier"] = authorizationInfo.userIdentifier
        
        debugPrint("User Identifier: \(String(describing: keychain["userIdentifier"]))")
    }
    
    @objc private func logout() {
        DispatchQueue.main.async {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
    
    @objc private func extractEmail() {
        guard let authorizationInfo = authorizationInfo,
            let email = NKAppleAuthorizationManager.shared.extractEmailFromIdToken(authorizationInfo.identityToken) else {
                let alertController = UIAlertController(title: "Error", message: "Failed to extract email", preferredStyle: .alert)
                alertController.addAction(UIAlertAction.init(title: "Ok", style: .default, handler: nil))
                self.present(alertController, animated: true, completion: nil)
                
                return
        }
        
        showUserData(email)
        
        let alertController = UIAlertController(title: "Extracted email", message: email, preferredStyle: .alert)
        alertController.addAction(UIAlertAction.init(title: "Ok", style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
}
