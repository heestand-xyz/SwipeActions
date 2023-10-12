import SwiftUI

public struct SwipeAction: Identifiable, Equatable {
    
    public let id = UUID()
    
    public enum Content {
        case text(String)
        case icon(Image)
        case label(String, Image)
    }
    let content: Content
    
    public struct Style {
        let foregroundColor: Color
        let backgroundColor: Color
        public init(foregroundColor: Color = .white, backgroundColor: Color) {
            self.foregroundColor = foregroundColor
            self.backgroundColor = backgroundColor
        }
    }
    let style: Style
    
    let call: () -> ()
    
    public init(_ content: Content, style: Style, _ call: @escaping () -> ()) {
        self.content = content
        self.style = style
        self.call = call
    }
    
    public static func == (lhs: SwipeAction, rhs: SwipeAction) -> Bool {
        lhs.id == rhs.id
    }
}
