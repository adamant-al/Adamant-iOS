//
//  AdamantUriTools.swift
//  Adamant
//
//  Created by Anokhov Pavel on 23.02.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation

enum AdamantUri {
	case passphrase(passphrase: String)
	case address(address: String, params: [AdamantAddressParam]?)
}

enum AdamantAddressParam {
	case label(String)
	
	init?(raw: String) {
		let keyValue = raw.split(separator: "=")
		if keyValue.count != 2 {
			return nil
		}
		
		switch keyValue[0] {
		case "label":
			self = AdamantAddressParam.label(keyValue[1].replacingOccurrences(of: "+", with: " "))
		
		default:
			return nil
		}
	}
	
	var encoded: String {
		switch self {
		case .label(let value):
			return "label=\(value.replacingOccurrences(of: " ", with: "+"))"
		}
	}
}

class AdamantUriTools {
	static let AdamantProtocol = "adm"
	
	static func encode(request: AdamantUri) -> String {
		switch request {
		case .passphrase(passphrase: let passphrase):
			return passphrase
			
		case .address(address: let address, params: let params):
			var uri = "\(AdamantProtocol):\(address)"
			
			if let encodedParams = params?.map({$0.encoded}).joined(separator: "&"), encodedParams.count > 0 {
				uri = "\(uri)?\(encodedParams)"
			}
			
			return uri
		}
	}
	
	static func decode(uri: String) -> AdamantUri? {
		if uri.count == 0 {
			return nil
		}
		
		if AdamantUtilities.validateAdamantPassphrase(passphrase: uri) {
			return AdamantUri.passphrase(passphrase: uri)
		}
		
		let request = uri.split(separator: ":")
		if request.count > 2 || request[0] != AdamantProtocol {
			return nil
		}
		
		let addressAndParams = request[1].split(separator: "?")
		guard let addressRaw = addressAndParams.first else {
			return nil
		}
		
		let address = String(addressRaw)
		guard AdamantUtilities.validateAdamantAddress(address: address) else {
			return nil
		}
		
		let params: [AdamantAddressParam]?
		if addressAndParams.count > 1 {
			var p = [AdamantAddressParam]()
			
			for param in addressAndParams[1].split(separator: "&").flatMap({AdamantAddressParam(raw: String($0))}) {
				p.append(param)
			}
			
			if p.count > 0 {
				params = p
			} else {
				params = nil
			}
		} else {
			params = nil
		}
		
		return AdamantUri.address(address: address, params: params)
	}
	
	private init() {}
}
