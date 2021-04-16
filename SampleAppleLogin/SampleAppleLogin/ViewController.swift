//
//  ViewController.swift
//  SampleAppleLogin
//
//  Created by Karthik on 16/08/20.
//  Copyright © 2020 Karthik. All rights reserved.
//

import UIKit
import KeychainAccess
import AuthenticationServices

class ViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet weak var socialLoginsStackView: UIStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addAppleLoginButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
    }
    
    private func addAppleLoginButton() {
        let authorizationButton = ASAuthorizationAppleIDButton()
        authorizationButton.addTarget(self, action: #selector(handleAuthorizationAppleIDButtonPress), for: .touchUpInside)
        self.socialLoginsStackView.addArrangedSubview(authorizationButton)
    }
    
    @objc func handleAuthorizationAppleIDButtonPress() {
        NKAppleAuthorizationManager.shared.authorize { [weak self](result) in
            guard let `self` = self else { return }
            switch result {
            case .success(let authorizationInfo):
                self.onSuccessfulAuthorization(with: authorizationInfo)
            case .failure(let error):
                self.onFailedAuthorization(with: error)
            }
        }
    }
    
    private func onSuccessfulAuthorization(with authorizationInfo: NKAppleUserAuthorizationInfo?) {
        dump(authorizationInfo)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let homeViewController = storyboard.instantiateViewController(identifier: "HomeViewController") as? HomeViewController else {
            return
        }
        homeViewController.authorizationInfo = authorizationInfo
        self.navigationController?.pushViewController(homeViewController, animated: true)
    }
    
    private func onFailedAuthorization(with error: Error) {
        debugPrint("Authorization failed with error \(error.localizedDescription)")
    }
}

