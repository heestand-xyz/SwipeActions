import SwiftUI
import MultiViews
import CoreGraphicsExtensions

struct SwipeActions<Content: View>: View {
    
    static var dragResetAbsoluteFraction: CGFloat { macOS ? 0.75 : 0.25 }
    static var dragActionAbsoluteFraction: CGFloat { macOS ? 0.75 : 0.25 }
    #if os(macOS)
    static var scrollMultiplier: CGFloat { 0.1 }
    #else
    static var dragActionRelativeFraction: CGFloat { 0.5 }
    #endif

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
    
    private var actionsLength: CGFloat {
        (viewState.isActionable ? size.width : length) - paddingWidth * 2
    }
    
    @State var size: CGSize = .one
    
    #if os(macOS)
    @State var scrollTranslation: CGFloat = 0.0
    #endif
    
    var body: some View {
        ZStack {
            content()
                .offset(x: actionOffset)
            if let side: Side {
                actionsBody(side: side)
                    .layoutPriority(-1)
            }
            Text(viewState.rawValue)
                .padding(5)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .colorInvert()
                }
                .offset(y: 20)
        }
        .animation(.easeOut(duration: 0.25),
                   value: viewState.isActionable)
        .readGeometry(size: $size)
#if os(macOS)
        .background {
            MVInteractView(interacted: { _ in
                gestureEnd()
                scrollTranslation = 0.0
            }, scrolling: { offset in
                if !drag.isActive {
                    gestureStart()
                }
                scrollTranslation += offset.x * Self.scrollMultiplier
                gestureUpdate(translation: scrollTranslation,
                              location: 0.0)
            })
        }
#else
        .gesture(gesture)
#endif
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
        HStack(spacing: viewState.isActionable ? 0.0 : leadingSpacing) {
            ForEach(leadingActions) { action in
                let isPrimary: Bool = leadingActions.first == action
                button(action: action, side: .leading)
                    .frame(width: viewState.isActionable && isPrimary ? actionsLength : nil)
            }
        }
        .frame(width: actionsLength)
    }
    
    private var trailingActionsBody: some View {
        HStack(spacing: viewState.isActionable ? 0.0 : trailingSpacing) {
            ForEach(trailingActions) { action in
                let isPrimary: Bool = trailingActions.last == action
                button(action: action, side: .trailing)
                    .frame(width: viewState.isActionable && isPrimary ? actionsLength : nil)
            }
        }
        .frame(width: actionsLength)
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
        .buttonStyle(.plain)
    }
    
    #if !os(macOS)
    private var gesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !drag.isActive {
                    gestureStart()
                }
                gestureUpdate(translation: value.translation.width,
                              location: value.location.x)
            }
            .onEnded { _ in
                gestureEnd()
            }
    }
    #endif
    
    private func gestureStart() {
        drag.isActive = true
        viewState = .dragging
        if let endTimer: Timer {
            endTimer.invalidate()
            self.endTimer = nil
        }
    }

    private func gestureUpdate(translation: CGFloat, location: CGFloat) {
        drag.translation = translation
        drag.location = location
        
        var draggingAbsoluteAction: Bool {
            guard let side: Side else { return false }
            switch side {
            case .leading:
                return location > (size.width - size.width * Self.dragActionAbsoluteFraction)
            case .trailing:
                return location < size.width * Self.dragActionAbsoluteFraction
            }
        }
        
        var draggingRelativeAction: Bool {
            #if os(macOS)
            return true
            #else
            return length > (size.width * Self.dragActionRelativeFraction)
            #endif
        }
        
        var draggingAction: Bool {
            draggingRelativeAction && draggingAbsoluteAction
        }
        
        viewState = draggingAction ? .potentialAction : .dragging
    }

    private func gestureEnd() {
        let isAtStart: Bool = abs(drag.translation) < size.width * Self.dragResetAbsoluteFraction
        
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
