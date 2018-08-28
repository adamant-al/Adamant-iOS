//
//  AdmWalletRoutes.swift
//  Adamant
//
//  Created by Anokhov Pavel on 28.08.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation

extension AdamantScene.Wallets {
	struct Adamant {
		/// Wallet preview
		static let wallet = AdamantScene(identifier: "AdmWalletViewController") { r in
			let c = AdmWalletViewController(nibName: "WalletViewControllerBase", bundle: nil)
			c.dialogService = r.resolve(DialogService.self)
			return c
		}
		
		/// Send money
		static let transfer = AdamantScene(identifier: "AdmTransferViewController") { r in
			let c = AdmTransferViewController()
			c.dialogService = r.resolve(DialogService.self)
			return c
		}
		
		/// Transactions list
		static let transactionsList = AdamantScene(identifier: "TransactionsViewController", factory: { r in
			let c = ADMTransactionsViewController(nibName: "TransactionsViewController", bundle: nil)
			c.accountService = r.resolve(AccountService.self)
			c.transfersProvider = r.resolve(TransfersProvider.self)
			c.dialogService = r.resolve(DialogService.self)
			c.router = r.resolve(Router.self)
			c.stack = r.resolve(CoreDataStack.self)
			return c
		})
		
		/// Adamant transaction details
		static let transactionDetails = AdamantScene(identifier: "TransactionDetailsViewController", factory: { r in
			let c = ADMTransactionDetailsViewController()
			c.accountService = r.resolve(AccountService.self)
			c.dialogService = r.resolve(DialogService.self)
			c.transfersProvider = r.resolve(TransfersProvider.self)
			c.router = r.resolve(Router.self)
			return c
		})
		
		private init() {}
	}
}
