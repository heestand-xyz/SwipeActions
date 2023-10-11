//
//  File.swift
//  
//
//  Created by Heestand, Anton Norman | Anton | GSSD on 2023-10-11.
//

import Foundation

public struct SwipeActionsStyle {
    public var spacing: CGFloat = 0.0
    public var padding: CGSize = .zero
    public var cornerRadius: CGFloat = 0.0
    public init(spacing: CGFloat = 0.0, padding: CGSize = .zero, cornerRadius: CGFloat = 0.0) {
        self.spacing = spacing
        self.padding = padding
        self.cornerRadius = cornerRadius
    }
}
