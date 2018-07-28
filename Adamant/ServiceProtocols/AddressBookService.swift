//
//  AddressBookService.swift
//  Adamant
//
//  Created by Anton Boyarkin on 24/07/2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation

// MARK: - Notifications

extension Notification.Name {
	struct AddressBookService {
		/// Raised when user rename accounts in chat
		static let addressBookUpdated = Notification.Name("adamant.addressBookService.updated")
		
		private init() {}
	}
}


// MARK: - Result and Errors

enum AddressBookServiceResult {
	case success
	case failure(AddressBookServiceError)
}

enum AddressBookServiceError {
	case notLogged
	case notEnoughtMoney
	case apiServiceError(error: ApiServiceError)
	case internalError(message: String, error: Error?)
}

extension AddressBookServiceError: RichError {
	var message: String {
		switch self {
		case .notLogged:
			return String.adamantLocalized.sharedErrors.userNotLogged
			
		case .notEnoughtMoney:
			return NSLocalizedString("AddressBookService.Error.NotEnoughtMoney", comment: "AddressBookService: Not enought money to save address into blockchain")
			
		case .apiServiceError(let error): return error.message
		case .internalError(let message, _): return message
		}
	}
	
	var internalError: Error? {
		switch self {
		case .notLogged, .notEnoughtMoney: return nil
		case .apiServiceError(let error): return error.internalError
		case .internalError(_, let error): return error
		}
	}
	
	var level: ErrorLevel {
		switch self {
		case .notLogged, .notEnoughtMoney: return .warning
		case .apiServiceError(let error): return error.level
		case .internalError: return .error
		}
	}
}


// MARK: -
protocol AddressBookService: class {
	// MARK: Work with Address book
	func set(name: String, for: String)
    var addressBook: [String:String] { get }
	
	// MARK: Updating & saving
	func update()
	func update(_ completion: ((AddressBookServiceResult) -> Void)?)
	
	var hasChanges: Bool { get }
    func saveIfNeeded()
}