//
//  AdmWalletService+RichMessageProvider.swift
//  Adamant
//
//  Created by Anokhov Pavel on 27.09.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation
import MessageKit

extension AdmWalletService: RichMessageProvider {
    func richMessageTapped(message: MessageTransaction, in chat: ChatViewController) {
        print("tap!")
    }
    
    func cellSizeCalculator(for messagesCollectionViewFlowLayout: MessagesCollectionViewFlowLayout) -> CellSizeCalculator {
        let calculator = TransferMessageSizeCalculator(layout: messagesCollectionViewFlowLayout)
        calculator.font = UIFont.systemFont(ofSize: 24)
        return calculator
    }
    
    func cell(for message: MessageType, isFromCurrentSender: Bool, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UICollectionViewCell {
        guard case .custom(let raw) = message.kind, let richContent = raw as? [String:String] else {
            fatalError("ADM service tried to render wrong message kind: \(message.kind)")
        }
        
        guard let cell = messagesCollectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? TransferCollectionViewCell else {
            fatalError("Can't dequeue \(cellIdentifier) cell")
        }
        
        cell.currencyLogoImageView.image = AdmWalletService.currencyLogo
        cell.currencySymbolLabel.text = AdmWalletService.currencySymbol
        
        cell.amountLabel.text = richContent[RichContentKeys.transfer.amount] ?? "NaN"
        cell.dateLabel.text = message.sentDate.humanizedDateTime(withWeekday: false)
        
        cell.isAlignedRight = isFromCurrentSender
        
        return cell
    }
}
