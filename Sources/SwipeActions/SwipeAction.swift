import SwiftUI

public struct SwipeAction {
    
    let text: String
    let icon: Image?
    
    public struct Style {
        let foregroundColor: Color
        let backgroundColor: Color
        public init(foregroundColor: Color = .white, backgroundColor: Color) {
            self.foregroundColor = foregroundColor
            self.backgroundColor = backgroundColor
        }
    }
    let style: Style
    
    public init(text: String, icon: Image? = nil, style: Style, action: () -> ()) {
        self.text = text
        self.icon = icon
        self.style = style
    }
}
