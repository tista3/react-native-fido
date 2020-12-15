import Foundation
import WebAuthnKit
import UIKit

struct Log: TextOutputStream {

    func write(_ string: String) {
        let fm = FileManager.default
        let log = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("fido2-log.txt")
        if let handle = try? FileHandle(forWritingTo: log) {
            handle.seekToEndOfFile()
            handle.write(string.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? string.data(using: .utf8)?.write(to: log)
        }
    }
}

var logger = Log()

@objc(RNFido2)
class RNFido2: NSObject {
    var nfcSessionStatus = false
    var accessorySessionStatus = false
    var webAuthnClient: WebAuthnClient?
    private var rpId: NSDictionary?
    private var user: NSDictionary?
    private var nfcSessionStateObservation: NSKeyValueObservation?
    private var accessorySessionStateObservation: NSKeyValueObservation?

    @objc
    func initialize(
      _ origin: String, 
      resolver resolve: @escaping RCTPromiseResolveBlock,
      rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
      let app = UIApplication.shared.delegate as! AppDelegate
      let rootViewController = app?.window??.rootViewController
      if (rootViewController != nil) {
        let userConsentUI = UserConsentUI(viewController: rootViewController)
        let authenticator = InternalAuthenticator(ui: userConsentUI)

        self.webAuthnClient = WebAuthnClient(
          origin: origin,
          authenticator: authenticator
        )
      }
    }

    @objc
    func setRpId(
      _ id: String,
      name: String,
      icon: String,
      resolver resolve: @escaping RCTPromiseResolveBlock,
      rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
      if id.isEmpty {
        reject("RpIdError", "ID not specified", nil)
      }

      if name.isEmpty {
        reject("RpIdError", "Name not specified", nil)
      }

      rpId = [
        "id": id,
        "name": name,
        "icon": icon
      ]

      resolve("RpId has been set successfully!")
    }

    @objc
    func setUser(
      _ identifier: String,
      name: String,
      displayName: String,
      icon: String,
      resolver resolve: @escaping RCTPromiseResolveBlock,
      rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
      if identifier.isEmpty {
        reject("RpIdError", "ID not specified", nil)
      }

      if name.isEmpty {
        reject("RpIdError", "Name not specified", nil)
      }

      if displayName.isEmpty {
        reject("RpIdError", "Display name not specified", nil)
      }

      user = [
        "id": identifier,
        "name": name,
        "displayName": name,
        "icon": icon
      ]

      resolve("User has been set successfully!")
    }

    func getEnumValue(value: String) -> Any {
      if (value == "direct") {
        return AttestationConveyancePreference.direct
      }

      if (value == "indirect") {
        return AttestationConveyancePreference.indirect
      }

      if (value == "none") {
        return AttestationConveyancePreference.none
      }

      if (value == "required") {
        return UserVerificationRequirement.required
      }

      if (value == "preferred") {
        return UserVerificationRequirement.preferred
      }

      if (value == "discouraged") {
        return UserVerificationRequirement.discouraged
      }

      return AttestationConveyancePreference.none
    }
    
    @objc
    func registerFido2(
        _ challenge: String,
        attestation: String? = "direct",
        timeoutNumber: NSNumber? = NSNumber(value: 60),
        requireResidentKey: Bool? = false,
        userVerification: String? = "discouraged",
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) -> Void {
        if self.webAuthnClient == nil {
          reject("RegisterError", "Please initialize the lib before performing any operation", nil)
          return
        }

        if challenge.isEmpty {
          reject("RegisterError", "Please specify a challenge", nil)
          return
        }

        if user == nil {
          reject("RegisterError", "Please use .setUser before calling the register function", nil)
          return
        }

        if rpId == nil {
          reject("RegisterError", "Please use .setRpId before calling the register function", nil)
          return
        }

        let timeout = timeoutNumber?.intValue ?? 60
        var options = PublicKeyCredentialCreationOptions()

        options.challenge = Bytes.fromHex(challenge) // must be Array<UInt8>
        options.user.id = Bytes.fromString(user["id"]) // must be Array<UInt8>
        options.user.name = user["name"]
        options.user.displayName = user["displayName"]
        options.user.icon = user["icon"]  // Optional
        options.rp.id = rpId["id"]
        options.rp.name = rpId["name"]
        options.rp.icon = rpId["icon"] // Optional
        options.attestation = getEnumValue(value: attestation)



        options.addPubKeyCredParam(alg: .es256)
        options.authenticatorSelection = AuthenticatorSelectionCriteria(
            requireResidentKey: requireResidentKey, // this flag is ignored by InternalAuthenticator
            userVerification: getEnumValue(value: userVerification) // (choose from .required, .preferred, .discouraged)
        )

        self.webAuthnClient.create(options).then { credential in
          // send parameters to your server

          // credential.id
          // credential.rawId
          // credential.response.attestationObject
          // credential.response.clientDataJSON

          let response: NSDictionary = [
            "id": credential.id,
            "rawId": credential.rawId,
            "attestationObject": credential.response.attestationObject,
            "clientDataJSON": credential.response.clientDataJSON
          ]

          resolve(response)
        }.catch { error in
          // error handling
          reject("WebAuthnCreateError", error, nil)
        }
    }
}
 
