//
//  File.swift
//  
//
//  Created by Heestand, Anton Norman | Anton | GSSD on 2023-10-11.
//

import Foundation
import CoreGraphics

public struct SwipeActionsStyle {
    public var spacing: CGFloat
    public var padding: CGSize
    public enum Shape {
        case rectangle
        case roundedRectangle(cornerRadius: CGFloat)
        case capsule
        func cornerRadius(height: CGFloat) -> CGFloat {
            switch self {
            case .rectangle:
                return 0.0
            case .roundedRectangle(let cornerRadius):
                return cornerRadius
            case .capsule:
                return height / 2
            }
        }
    }
    public var shape: Shape
    public init(spacing: CGFloat = 0.0, padding: CGSize = .zero, shape: Shape = .rectangle) {
        self.spacing = spacing
        self.padding = padding
        self.shape = shape
    }
}
