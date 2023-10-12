import SwiftUI
import MultiViews
import CoreGraphicsExtensions

struct SwipeActions<Content: View>: View {
    
    static var dragResetAbsoluteLength: CGFloat { 100 }
    static var dragActionAbsoluteLength: CGFloat { 100 }
    static var dragActionRelativeFraction: CGFloat { 0.5 }

    let style: SwipeActionsStyle
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    let content: () -> Content
    
    private enum ViewState: String {
        case inactive
        case dragging
        case options
        case potentialAction
        case action
        var isActionable: Bool {
            [.potentialAction, .action].contains(self)
        }
    }
    @State private var viewState: ViewState = .inactive
    
    @State private var endTimer: Timer?

    struct Drag {
        var isActive: Bool = false
        var translation: CGFloat = 0.0
        var location: CGFloat = 0.0
        mutating func reset() {
            isActive = false
            translation = 0.0
            location = 0.0
        }
    }
    @State private var drag = Drag()
    
    enum Side {
        case leading
        case trailing
        var multiplier: CGFloat {
            switch self {
            case .leading:
                return -1.0
            case .trailing:
                return 1.0
            }
        }
    }
    @State var side: Side?
    
    private var offset: CGFloat {
        guard let side: Side else { return 0.0 }
        var offset: CGFloat = drag.translation
        switch side {
        case .leading:
            if leadingActions.isEmpty { return 0.0 }
            offset = max(0.0, offset)
        case .trailing:
            if trailingActions.isEmpty { return 0.0 }
            offset = min(0.0, offset)
        }
        return offset
    }
    
    private var actionOffset: CGFloat {
        viewState.isActionable ? (
            size.width * -(side?.multiplier ?? 0.0)
        ) : offset
    }
    
    private var length: CGFloat {
        abs(offset)
    }
    
    private var totalPaddingWidth: CGFloat {
        min(style.padding.width * 4, length)
    }
    
    private var paddingWidth: CGFloat {
        totalPaddingWidth / 4
    }
    
    private var totalLeadingSpacing: CGFloat {
        min(style.spacing * CGFloat(leadingActions.count) * 2, length)
    }
    
    private var leadingSpacing: CGFloat {
        totalLeadingSpacing / CGFloat(leadingActions.count) / 2
    }
    
    private var totalTrailingSpacing: CGFloat {
        min(style.spacing * CGFloat(trailingActions.count) * 2, length)
    }
    
    private var trailingSpacing: CGFloat {
        totalLeadingSpacing / CGFloat(trailingActions.count) / 2
    }
    
    @State var size: CGSize = .one
    
    var body: some View {
        ZStack {
            content()
                .offset(x: actionOffset)
                .animation(.easeOut(duration: 0.2),
                           value: viewState.isActionable)
            if let side: Side {
                actionsBody(side: side)
                    .layoutPriority(-1)
            }
            Text(viewState.rawValue)
                .opacity(0.25)
        }
        .readGeometry(size: $size)
        .gesture(gesture)
        .onChange(of: drag.translation) { newTranslation in
            if side != .leading, newTranslation > 0.0 {
                side = .leading
            } else if side != .trailing, newTranslation < 0.0 {
                side = .trailing
            }
        }
    }
    
    private func actionsBody(side: Side) -> some View {
        Group {
            switch side {
            case .leading:
                HStack(spacing: 0.0) {
                    leadingActionsBody
                    Spacer(minLength: 0.0)
                }
            case .trailing:
                HStack(spacing: 0.0) {
                    Spacer(minLength: 0.0)
                    trailingActionsBody
                }
            }
        }
        .padding(.horizontal, paddingWidth)
        .padding(.vertical, style.padding.height)
    }
    
    private var leadingActionsBody: some View {
        HStack(spacing: leadingSpacing) {
            ForEach(leadingActions) { action in
                button(action: action, side: .leading)
            }
        }
        .frame(width: length - paddingWidth * 2)
    }
    
    private var trailingActionsBody: some View {
        HStack(spacing: trailingSpacing) {
            ForEach(trailingActions) { action in
                button(action: action, side: .trailing)
            }
        }
        .frame(width: length - paddingWidth * 2)
    }
    
    private func button(action: SwipeAction, side: Side) -> some View {
        Button(action: action.call) {
            ZStack {
                action.style.backgroundColor
                Group {
                    if let icon: Image = action.icon {
                        icon
                    } else {
                        Text(action.text)
                    }
                }
                .fixedSize()
                .padding(.horizontal)
                .frame(minWidth: 0, alignment: side == .leading ? .trailing : .leading)
                .foregroundColor(action.style.foregroundColor)
                .frame(maxWidth: .infinity, alignment: side == .leading ? .leading : .trailing)
            }
        }
        .clipShape(.rect(cornerRadius: style.cornerRadius))
    }
    
    private var gesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !drag.isActive {
                    drag.isActive = true
                    viewState = .dragging
                    if let endTimer: Timer {
                        endTimer.invalidate()
                        self.endTimer = nil
                    }
                }
                drag.translation = value.translation.width
                drag.location = value.location.x
                
                
                
                var draggingAbsoluteAction: Bool {
                    guard let side: Side else { return false }
                    switch side {
                    case .leading:
                        return drag.location > (size.width - Self.dragActionAbsoluteLength)
                    case .trailing:
                        return drag.location < Self.dragActionAbsoluteLength
                    }
                }
                
                var draggingRelativeAction: Bool {
                    length > (size.width * Self.dragActionRelativeFraction)
                }
                
                var draggingAction: Bool {
                    draggingRelativeAction && draggingAbsoluteAction
                }
                
                viewState = draggingAction ? .potentialAction : .dragging
            }
            .onEnded { value in
                
                let isAtStart: Bool = abs(value.translation.width) < Self.dragResetAbsoluteLength
                
                if viewState == .potentialAction {
                    viewState = .action
                } else if isAtStart {
                    viewState = .inactive
                } else {
                    viewState = .options
                }
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    drag.translation = 0.0
                }
                
                endTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                    drag.reset()
                    side = nil
                    endTimer = nil
                }
            }
    }
}

extension View {
    public func swipeActions(style: SwipeActionsStyle = .init(),
                             leading leadingActions: [SwipeAction] = [],
                             trailing trailingActions: [SwipeAction] = []) -> some View {
        SwipeActions(style: style,
                     leadingActions: leadingActions,
                     trailingActions: trailingActions) {
            self
        }
    }
}

fileprivate func mock(named name: String) -> some View {
    Text(name)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Color.primary
                .opacity(0.1)
        }
}

#Preview {
    ScrollView {
        VStack(spacing: 1.0) {
            mock(named: "First")
                .swipeActions(trailing: [
                    SwipeAction(text: "Remove", style: .init(backgroundColor: .red)) {}
                ])
            mock(named: "Second")
                .swipeActions(leading: [
                    SwipeAction(text: "Add", style: .init(backgroundColor: .green)) {}
                ])
            mock(named: "Third")
                .swipeActions(style: SwipeActionsStyle(
                    spacing: 5,
                    padding: CGSize(width: 5, height: 5),
                    cornerRadius: 5
                ), leading: [
                    SwipeAction(text: "Add", style: .init(backgroundColor: .green)) {},
                    SwipeAction(text: "Move", style: .init(backgroundColor: .blue)) {}
                ], trailing: [
                    SwipeAction(text: "Remove", style: .init(backgroundColor: .red)) {}
                ])
        }
    }
}
