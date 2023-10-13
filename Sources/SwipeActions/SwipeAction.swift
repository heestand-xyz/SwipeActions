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
        let showLoadingIndicator: Bool
        public init(foregroundColor: Color = .white,
                    backgroundColor: Color,
                    showLoadingIndicator: Bool = false) {
            self.foregroundColor = foregroundColor
            self.backgroundColor = backgroundColor
            self.showLoadingIndicator = showLoadingIndicator
        }
    }
    let style: Style
    
    let call: () async -> ()
    
    public init(_ content: Content, style: Style, _ call: @escaping () -> ()) {
        self.content = content
        self.style = style
        self.call = call
    }
    
    public static func == (lhs: SwipeAction, rhs: SwipeAction) -> Bool {
        lhs.id == rhs.id
    }
}
