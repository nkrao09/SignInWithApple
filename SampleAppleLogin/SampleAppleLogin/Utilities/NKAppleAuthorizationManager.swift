//
//  NKAppleAuthorizationManager.swift
//  SampleAppleLogin
//
//  Created by Karthik on 16/08/20.
//  Copyright © 2020 Karthik. All rights reserved.
//

import Foundation
import AuthenticationServices
import JWTDecode

/// Struct to hold information received from Apple SDK
public struct NKAppleUserAuthorizationInfo {
    var appleUserPersonalInfo: NKAppleUserPersonalInfo?
    var authCode: Data?
    var userIdentifier: String
    var identityToken: Data?
}

/// Struct to hold user personal information
public struct NKAppleUserPersonalInfo: Codable {
    var firstName: String?
    var lastName: String?
    var email: String?
}

/// Enum to represent Apple user credential status
public enum NKAppleCredentialStatus {
    case authorized
    case revoked
    case notFound
    case unknown
}

typealias NKAppleAuthorizationCompletionHandler = (_ result: Result<NKAppleUserAuthorizationInfo, Error>) -> Void
typealias NKAppleCredentialStateCompletionHandler = (_ credentialStatus: NKAppleCredentialStatus) -> Void

/// This extension will help to interact with AuthenticationServices framework to perfom Apple login
/// And also it saves information received from framework to keychain and couple of other operations
class NKAppleAuthorizationManager: NSObject, ASAuthorizationControllerDelegate {
    
    static let shared = NKAppleAuthorizationManager()
    var appleAuthorizationCompletion: NKAppleAuthorizationCompletionHandler?
    
    private override init() { }
    
    /// It initiates the authorization request with the given scope(fullName, email)
    /// - Parameters:
    ///     - storedCredentialsOnCloud: Boolean value to determine request from existing user credential or new credential request
    ///     - completion: McDAppleAuthorizationCompletionHandler - handler with status of authorization of type AppleAuthorizationStatus
    func authorize(using storedCredentialsOnCloud: Bool = false, on completion: @escaping NKAppleAuthorizationCompletionHandler) {
        if #available(iOS 13.0, *) {
            appleAuthorizationCompletion = completion
            if storedCredentialsOnCloud {
                requestAuthorizationUsingStoredCredentials()
            } else {
                requestAuthorization()
            }
        } else {
            completion(.failure(appleAuthorizationError()))
        }
    }
    
    private func requestAuthorization() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    private func requestAuthorizationUsingStoredCredentials() {
        // Prepare requests for both Apple ID and password providers.
        let requests = [ASAuthorizationAppleIDProvider().createRequest(),
                        ASAuthorizationPasswordProvider().createRequest()]
        // Create an authorization controller with the given requests.
        let authorizationController = ASAuthorizationController(authorizationRequests: requests)
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    @available(iOS 13.0, *)
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let completion = appleAuthorizationCompletion else { return }
        
        var appleUserAuthorizationInfo: NKAppleUserAuthorizationInfo
        
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let appleUserPersonalInfo = NKAppleUserPersonalInfo(firstName: appleIDCredential.fullName?.givenName,
                                                                lastName: appleIDCredential.fullName?.familyName,
                                                                email: appleIDCredential.email)
            
            appleUserAuthorizationInfo = NKAppleUserAuthorizationInfo(appleUserPersonalInfo: appleUserPersonalInfo,
                                                                      authCode: appleIDCredential.authorizationCode,
                                                                      userIdentifier: appleIDCredential.user,
                                                                      identityToken: appleIDCredential.identityToken)
            completion(.success(appleUserAuthorizationInfo))
        } else {
            completion(.failure(appleAuthorizationError()))
        }
        appleAuthorizationCompletion = nil
    }
    
    @available(iOS 13.0, *)
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let completion = appleAuthorizationCompletion {
            completion(.failure(appleAuthorizationError()))
            appleAuthorizationCompletion = nil
        }
    }
    
    /// This method checks the credential state of Apple User on coming to foreground or relaunch
    /// If the state is authorized, then it will retain the logged in user state
    /// otherwise, it will logout the user
    @available(iOS 13.0, *)
    func checkAppleCredentialState(with userIdentifier: String?, completion: @escaping NKAppleCredentialStateCompletionHandler) {
        guard let userIdentifier = userIdentifier else {
            completion(.notFound)
            return
        }
        var status: NKAppleCredentialStatus = .notFound
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        appleIDProvider.getCredentialState(forUserID: userIdentifier) { (credentialState, error) in
            switch credentialState {
            case .authorized:
                status = .authorized
            case .revoked,
                 .notFound,
                 .transferred:
                status = .revoked
            @unknown default:
                status = .unknown
            }
            completion(status)
        }
    }
    
    /// This method will return the error object when user cancels the Apple Native prompt during Login or SignUp flow
    /// - Returns: AccountError object with code '0' and description "Apple login cancelled"
    private func appleAuthorizationError() -> NSError {
        return NSError(domain: "",
                       code: 0,
                       userInfo: [NSLocalizedDescriptionKey: "apple_authorization_failed"])
    }
    
    /// This method will extract user email Id from IdToken
    /// - Parameter idToken: IdToken received from Apple
    ///
    /// - Returns: user 'email' on succefull decode otherwise 'nil'
    func extractEmailFromIdToken(_ idToken: Data?) -> String? {
        if let idToken = idToken,
            let encodedIdToken = String(data: idToken, encoding: .utf8),
            let decodedIdToken = try? decode(jwt: encodedIdToken),
            let email = decodedIdToken.claim(name: "email").string {
            
            return email
        } else {
            return nil
        }
    }
    
    /// This function registers notification to monitor Apple ID state change
    func registerNotificationObserverForAppIDStateChange(on viewController: UIViewController, selector: Selector) {
        NotificationCenter.default.addObserver(viewController, selector: selector, name: ASAuthorizationAppleIDProvider.credentialRevokedNotification, object: nil)
    }
    
    /// This function registers notification to monitor Apple ID state change
    func removeNotificationObserverForAppIDStateChange(on viewController: UIViewController, selector: Selector) {
        NotificationCenter.default.removeObserver(viewController, name: ASAuthorizationAppleIDProvider.credentialRevokedNotification, object: nil)
    }
}

extension NKAppleAuthorizationManager: ASAuthorizationControllerPresentationContextProviding {
    @available(iOS 13.0, *)
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return ((UIApplication.shared.delegate?.window)!)!
    }
}
