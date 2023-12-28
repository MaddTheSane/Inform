//
//  IFToolbar.swift
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

import Foundation


class IFToolbar: NSToolbar {
    @objc static let changedVisibility = Notification.Name("IFToolbarChangedVisibility")

    func setVisible(shown:Bool) {
        super.isVisible = shown

        NotificationCenter.default.post(name: IFToolbar.changedVisibility, object: self)
    }
}
