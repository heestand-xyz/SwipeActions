import SwiftUI
import MultiViews
import CoreGraphicsExtensions

// MARK: Modifier

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

// MARK: View

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
    
    @State private var buttonWidths: [UUID: CGFloat] = [:]
    
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
        
        var opposite: Side {
            switch self {
            case .leading:
                return .trailing
            case .trailing:
                return .leading
            }
        }
        
        var multiplier: CGFloat {
            switch self {
            case .leading:
                return -1.0
            case .trailing:
                return 1.0
            }
        }
        
        var alignment: Alignment {
            switch self {
            case .leading:
                return .leading
            case .trailing:
                return .trailing
            }
        }
    }
    @State var side: Side?
    
    @State var size: CGSize = .one
    
#if os(macOS)
    @State var scrollTranslation: CGFloat = 0.0
#endif
    
    // MARK: Body
    
    var body: some View {
        ZStack {
            content()
                .offset(x: actionOffset)
            if let side: Side {
                actionsBody(side: side)
                    .layoutPriority(-1)
            }
#if DEBUG
            Text(viewState.rawValue)
                .padding(5)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .colorInvert()
                        .opacity(0.5)
                }
#endif
        }
        .animation(.easeOut(duration: 0.25),
                   value: viewState.isActionable)
        .readGeometry(size: $size)
#if os(macOS)
        .background { interaction }
#else
        .gesture(gesture)
#endif
    }
}

// MARK: - Bodies

extension SwipeActions {
    
    private func actionsBody(side: Side) -> some View {
        
        HStack(spacing: viewState.isActionable ? 0.0 : spacing(side: side)) {
            
            ForEach(actions(side: side)) { action in
                
                let isPrimary: Bool = primaryAction(side: side) == action
                
                button(action: action, side: .leading)
                    .frame(width: {
                        if viewState.isActionable && isPrimary {
                            return actionsInnerLength(side: side)
                        } else if viewState == .options {
                            return buttonWidths[action.id]
                        }
                        return nil
                    }())
            }
        }
        .padding(.horizontal, paddingWidth)
        .padding(.vertical, style.padding.height)
        .frame(width: viewState == .options ? nil : actionsInnerLength(side: side))
        .frame(maxWidth: .infinity, alignment: side.alignment)
    }
}

// MARK: - Buttons

extension SwipeActions {
    
    private func button(action: SwipeAction, side: Side) -> some View {
        
        Button {
            self.side = nil
            action.call()
        } label: {
            
            ZStack {
                
                action.style.backgroundColor
                
                Group {
                    switch action.content {
                    case .text(let string):
                        Text(string)
                    case .icon(let image):
                        image
                    case .label(let string, let image):
                        Label(title: { Text(string) },
                              icon: { image })
                    }
                }
                .fixedSize()
                .padding(.horizontal)
                .readGeometry(size: Binding(get: { .zero }, set: { newSize in
                    buttonWidths[action.id] = newSize.width
                }))
                .frame(minWidth: 0, alignment: side == .leading ? .trailing : .leading)
                .foregroundColor(action.style.foregroundColor)
                .frame(maxWidth: .infinity, alignment: side == .leading ? .leading : .trailing)
            }
        }
        .clipShape(.rect(cornerRadius: style.cornerRadius))
        .buttonStyle(.plain)
    }
}

// MARK: Lengths

extension SwipeActions {
    
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
        if viewState.isActionable {
            return size.width * -(side?.multiplier ?? 0.0)
        } else if viewState == .options {
            guard let side: Side else { return 0.0 }
            return actionsOuterLength(side: side) * -side.multiplier
        }
        return offset
    }
    
    private var length: CGFloat {
        abs(offset)
    }
    
    private var paddingWidth: CGFloat {
        let padding: CGFloat = min(style.padding.width * 4, length)
        return padding / 4
    }
    
    private func spacing(side: Side) -> CGFloat {
        let spacing: CGFloat = min(style.spacing * CGFloat(actions(side: side).count) * 2, length)
        return spacing / CGFloat(leadingActions.count) / 2
    }
    
    private func actions(side: Side) -> [SwipeAction] {
        switch side {
        case .leading:
            return leadingActions
        case .trailing:
            return trailingActions
        }
    }
    
    private func primaryAction(side: Side) -> SwipeAction? {
        switch side {
        case .leading:
            return leadingActions.first
        case .trailing:
            return trailingActions.last
        }
    }
    
    private func actionsOuterLength(side: Side) -> CGFloat {
        if viewState.isActionable {
          return size.width
        } else if viewState == .options {
            let actions: [SwipeAction] = actions(side: side)
            if actions.isEmpty { return 0.0 }
            return actions
                .compactMap { action in
                    buttonWidths[action.id]
                }
                .reduce(0.0, +)
            + ( 0 ..< actions.count - 1 )
                .map { _ in
                    spacing(side: side)
                }
                .reduce(0.0, +)
            + paddingWidth * 2.0
        }
        return length
    }
    
    private func actionsInnerLength(side: Side) -> CGFloat {
        actionsOuterLength(side: side) - paddingWidth * 2.0
    }
}

// MARK: - Gestures

extension SwipeActions {
    
#if os(macOS)
    private var interaction: some View {
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
        
        if side != .leading, translation > 0.0 {
            side = .leading
        } else if side != .trailing, translation < 0.0 {
            side = .trailing
        }
        
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
            if viewState != .options {
                side = nil
            }
            endTimer = nil
        }
    }
}

// MARK: Mocks

fileprivate func mock(named name: String) -> some View {
    Text(name)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Color.primary
                .opacity(0.1)
        }
}

// MARK: Preview

#Preview {
    ScrollView {
        VStack(spacing: 1.0) {
            mock(named: "First")
                .swipeActions(trailing: [
                    SwipeAction(
                        .label("Remove", Image(systemName: "trash")),
                        style: .init(backgroundColor: .red)) {
                            print("Remove")
                        }
                ])
            mock(named: "Second")
                .swipeActions(leading: [
                    SwipeAction(
                        .icon(Image(systemName: "plus")),
                        style: .init(backgroundColor: .green)) {
                            print("Add")
                        }
                ])
            mock(named: "Third")
                .swipeActions(style: SwipeActionsStyle(
                    spacing: 5,
                    padding: CGSize(width: 5, height: 5),
                    cornerRadius: 5
                ), leading: [
                    SwipeAction(
                        .text("Add"),
                        style: .init(backgroundColor: .green)) {
                            print("Add")
                        },
                    SwipeAction(
                        .text("Move"),
                        style: .init(backgroundColor: .blue)) {
                            print("Move")
                        }
                ], trailing: [
                    SwipeAction(
                        .text("Remove"),
                        style: .init(backgroundColor: .red)) {
                            print("Remove")
                        }
                ])
        }
    }
}
