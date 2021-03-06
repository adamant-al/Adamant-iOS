//
//  AdamantAccountService.swift
//  Adamant
//
//  Created by Anokhov Pavel on 07.01.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation

class AdamantAccountService {
	
	// MARK: Dependencies
	
	var apiService: ApiService!
	var adamantCore: AdamantCore!
	var securedStore: SecuredStore! {
		didSet {
			securedStoreSemaphore.wait()
			defer {
				securedStoreSemaphore.signal()
			}
			
			if securedStore.get(.publicKey) != nil,
				securedStore.get(.privateKey) != nil,
				securedStore.get(.pin) != nil {
				hasStayInAccount = true
				
				_useBiometry = securedStore.get(.useBiometry) != nil
			} else {
				hasStayInAccount = false
				_useBiometry = false
			}
		}
	}
	
	
	// MARK: Properties
	
	private(set) var state: AccountServiceState = .notLogged
	private let stateSemaphore = DispatchSemaphore(value: 1)
	private let securedStoreSemaphore = DispatchSemaphore(value: 1)
	
	private(set) var account: Account?
	private(set) var keypair: Keypair?
	
	private func setState(_ state: AccountServiceState) {
		stateSemaphore.wait()
		self.state = state
		stateSemaphore.signal()
	}
	
	
	
	private(set) var hasStayInAccount: Bool = false
	
	private var _useBiometry: Bool = false
	var useBiometry: Bool {
		get {
			return _useBiometry
		}
		set {
			securedStoreSemaphore.wait()
			defer {
				securedStoreSemaphore.signal()
			}
			
			guard hasStayInAccount else {
				_useBiometry = false
				return
			}
			
			_useBiometry = newValue
			
			if newValue {
				securedStore.set(String(useBiometry), for: .useBiometry)
			} else {
				securedStore.remove(.useBiometry)
			}
		}
	}
}

// MARK: - Saved data
extension AdamantAccountService {
	func setStayLoggedIn(pin: String, completion: @escaping (AccountServiceResult) -> Void) {
		guard let account = account, let keypair = keypair else {
			completion(.failure(.userNotLogged))
			return
		}
		
		securedStoreSemaphore.wait()
		defer {
			securedStoreSemaphore.signal()
		}
		
		if hasStayInAccount {
			completion(.failure(.internalError(message: "Already has account", error: nil)))
			return
		}
		
		securedStore.set(pin, for: .pin)
		securedStore.set(keypair.publicKey, for: .publicKey)
		securedStore.set(keypair.privateKey, for: .privateKey)
		hasStayInAccount = true
		completion(.success(account: account))
	}
	
	func validatePin(_ pin: String) -> Bool {
		guard let savedPin = securedStore.get(.pin) else {
			return false
		}
		
		return pin == savedPin
	}
	
	private func getSavedKeypair() -> Keypair? {
		if let publicKey = securedStore.get(.publicKey), let privateKey = securedStore.get(.privateKey) {
			return Keypair(publicKey: publicKey, privateKey: privateKey)
		}
		
		return nil
	}
	
	func dropSavedAccount() {
		securedStoreSemaphore.wait()
		defer {
			securedStoreSemaphore.signal()
		}
		
		_useBiometry = false
		securedStore.remove(.pin)
		securedStore.remove(.publicKey)
		securedStore.remove(.privateKey)
		securedStore.remove(.useBiometry)
		hasStayInAccount = false
	}
}


// MARK: - AccountService
extension AdamantAccountService: AccountService {
	// MARK: Update logged account info
	func update() {
		stateSemaphore.wait()
		
		switch state {
		case .notLogged:
			fallthrough
		
		case .isLoggingIn:
			fallthrough
		
		case .updating:
			stateSemaphore.signal()
			return
			
		case .loggedIn:
			break
		}
		
		state = .updating
		stateSemaphore.signal()
		
		guard let loggedAccount = account else {
			return
		}
		
		apiService.getAccount(byPublicKey: loggedAccount.publicKey) { [weak self] result in
			switch result {
			case .success(let account):
				guard let acc = self?.account, acc.address == account.address else {
					// User has logged out, we not interested anymore
					self?.setState(.notLogged)
					return
				}
				
				if loggedAccount.balance != account.balance {
					self?.account = account
					NotificationCenter.default.post(name: Notification.Name.adamantAccountDataUpdated, object: nil)
				}
				
				self?.setState(.loggedIn)
				
			case .failure(let error):
				print("Error update account: \(String(describing: error))")
			}
		}
	}
}


// MARK: - Creating account
extension AdamantAccountService {
	// MARK: passphrase
	func createAccountWith(passphrase: String, completion: @escaping (AccountServiceResult) -> Void) {
		guard AdamantUtilities.validateAdamantPassphrase(passphrase: passphrase) else {
			completion(.failure(.invalidPassphrase))
			return
		}
		
		guard let publicKey = adamantCore.createKeypairFor(passphrase: passphrase)?.publicKey else {
			completion(.failure(.internalError(message: "Can't create key for passphrase", error: nil)))
			return
		}
		
		self.apiService.getAccount(byPublicKey: publicKey) { [weak self] result in
			switch result {
			case .success(_):
				completion(.failure(.wrongPassphrase))
				
			case .failure(_):
				if let apiService = self?.apiService {
					apiService.newAccount(byPublicKey: publicKey) { result in
						switch result {
						case .success(let account):
							completion(.success(account: account))
							
						case .failure(let error):
							completion(.failure(.apiError(error: error)))
						}
					}
				} else {
					completion(.failure(.internalError(message: "A bad thing happened", error: nil)))
				}
			}
		}
	}
}

// MARK: - Log In
extension AdamantAccountService {
	// MARK: Passphrase
	func loginWith(passphrase: String, completion: @escaping (AccountServiceResult) -> Void) {
		guard AdamantUtilities.validateAdamantPassphrase(passphrase: passphrase) else {
			completion(.failure(.invalidPassphrase))
			return
		}
		
		guard let keypair = adamantCore.createKeypairFor(passphrase: passphrase) else {
			completion(.failure(.internalError(message: "Failed to generate keypair for passphrase", error: nil)))
			return
		}
		
		if let savedKeypair = getSavedKeypair() {
			loginWith(keypair: keypair) { [weak self] result in
				switch result {
				case .success(_):
					if let newKeypair = self?.keypair, newKeypair != savedKeypair {
						self?.dropSavedAccount()
					}
					
				default:
					break
				}
				
				completion(result)
			}
		} else {
			loginWith(keypair: keypair, completion: completion)
		}
	}
	
	// MARK: Pincode
	func loginWith(pincode: String, completion: @escaping (AccountServiceResult) -> Void) {
		guard let storePin = securedStore.get(.pin) else {
			completion(.failure(.invalidPassphrase))
			return
		}
		
		guard storePin == pincode else {
			completion(.failure(.invalidPassphrase))
			return
		}
		
		loginWithStoredAccount(completion: completion)
	}
	
	// MARK: Biometry
	func loginWithStoredAccount(completion: @escaping (AccountServiceResult) -> Void) {
		guard let keypair = getSavedKeypair() else {
			completion(.failure(.invalidPassphrase))
			return
		}
		
		loginWith(keypair: keypair, completion: completion)
	}
	
	
	// MARK: Keypair
	private func loginWith(keypair: Keypair, completion: @escaping (AccountServiceResult) -> Void) {
		stateSemaphore.wait()
		switch state {
		case .isLoggingIn:
			stateSemaphore.signal()
			completion(.failure(.internalError(message: "Service is busy", error: nil)))
			return
			
		case .updating:
			fallthrough
			
		// Logout first
		case .loggedIn:
			logout(lockSemaphore: false)
			
		// Go login
		case .notLogged:
			break
		}
		
		state = .isLoggingIn
		stateSemaphore.signal()
		
		apiService.getAccount(byPublicKey: keypair.publicKey) { result in
			switch result {
			case .success(let account):
				self.account = account
				self.keypair = keypair
				
				let userInfo = [AdamantUserInfoKey.AccountService.loggedAccountAddress:account.address]
				NotificationCenter.default.post(name: Notification.Name.adamantUserLoggedIn, object: self, userInfo: userInfo)
				self.setState(.loggedIn)
				completion(.success(account: account))
				
			case .failure(let error):
				switch error {
				case .accountNotFound:
					completion(.failure(.wrongPassphrase))
					
				default:
					completion(.failure(.apiError(error: error)))
				}
			}
		}
	}
}


// MARK: - Log Out
extension AdamantAccountService {
	func logout() {
		logout(lockSemaphore: true)
	}
	
	private func logout(lockSemaphore: Bool) {
		dropSavedAccount()
		
		let wasLogged = account != nil
		account = nil
		keypair = nil
		
		if lockSemaphore {
			setState(.notLogged)
		} else {
			state = .notLogged
		}
		
		if wasLogged {
			NotificationCenter.default.post(name: Notification.Name.adamantUserLoggedOut, object: nil)
		}
	}
}


// MARK: - Secured Store
extension StoreKey {
	fileprivate struct accountService {
		static let publicKey = "accountService.publicKey"
		static let privateKey = "accountService.privateKey"
		static let pin = "accountService.pin"
		static let useBiometry = "accountService.useBiometry"
		
		private init() {}
	}
}

fileprivate enum Key {
	case publicKey
	case privateKey
	case pin
	case useBiometry
	
	var stringValue: String {
		switch self {
		case .publicKey: return StoreKey.accountService.publicKey
		case .privateKey: return StoreKey.accountService.privateKey
		case .pin: return StoreKey.accountService.pin
		case .useBiometry: return StoreKey.accountService.useBiometry
		}
	}
}

fileprivate extension SecuredStore {
	func set(_ value: String, for key: Key) {
		set(value, for: key.stringValue)
	}
	
	func get(_ key: Key) -> String? {
		return get(key.stringValue)
	}
	
	func remove(_ key: Key) {
		remove(key.stringValue)
	}
}
