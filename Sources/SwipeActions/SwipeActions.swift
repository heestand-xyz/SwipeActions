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
    
    private enum ViewState: Equatable {
        
        case inactive
        case options
        case dragging(translation: CGFloat, location: CGFloat)
        case draggingAction
        case action
        
        var isDragging: Bool {
            switch self {
            case .dragging, .draggingAction:
                true
            default:
                false
            }
        }
        
        var isActionable: Bool {
            switch self {
            case .draggingAction, .action:
                true
            default:
                false
            }
        }
    }
    @State private var viewState: ViewState = .inactive
    
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
                return 1.0
            case .trailing:
                return -1.0
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
    @State private var side: Side?
    
    @State private var buttonWidths: [UUID: CGFloat] = [:]
    
    @State private var size: CGSize = .one
    
#if os(macOS)
    @State private var scrollTranslation: CGFloat = 0.0
#endif
    
    // MARK: Body
    
    var body: some View {
        ZStack {
            content()
                .offset(x: length * (side?.multiplier ?? 0.0))
            if let side: Side {
                actionsBody(side: side)
                    .layoutPriority(-1)
            }
        }
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
            willAction()
            Task {
                await action.call()
                didAction()
            }
        } label: {
            
            ZStack {
                
                action.style.backgroundColor
                
                let showLoadingIndicator: Bool = action.style.showLoadingIndicator && viewState == .action
                
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
                .opacity(showLoadingIndicator ? 0.0 : 1.0)
                .overlay {
                    if showLoadingIndicator {
                        ProgressView()
                            .scaleEffect(macOS ? 0.5 : 1.0)
                    }
                }
                .animation(.easeInOut, value: showLoadingIndicator)
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
    
    private var length: CGFloat {
        guard let side: Side else { return 0.0 }
        switch viewState {
        case .inactive:
            return 0.0
        case .options:
            return actionsOuterLength(side: side)
        case .dragging(let translation, _):
            switch side {
            case .leading:
                if leadingActions.isEmpty { return 0.0 }
            case .trailing:
                if trailingActions.isEmpty { return 0.0 }
            }
            return translation * side.multiplier
        case .draggingAction, .action:
            return size.width
        }
    }
    
    private var minLength: CGFloat? {
        guard let side: Side else { return 0.0 }
        switch viewState {
        case .inactive:
            return 0.0
        case .options:
            return nil
        case .dragging(let translation, _):
            switch side {
            case .leading:
                if leadingActions.isEmpty { return 0.0 }
            case .trailing:
                if trailingActions.isEmpty { return 0.0 }
            }
            return translation * side.multiplier
        case .draggingAction, .action:
            return nil
        }
    }
    
    private var paddingWidth: CGFloat {
        guard let minLength: CGFloat else {
            return style.padding.width * 2
        }
        return min(style.padding.width * 4, minLength) / 4
    }
    
    private func spacing(side: Side) -> CGFloat {
        guard let minLength: CGFloat else {
            return style.spacing * CGFloat(actions(side: side).count)
        }
        let spacing: CGFloat = min(style.spacing * CGFloat(actions(side: side).count) * 2, minLength)
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
        max(0.0, actionsOuterLength(side: side) - paddingWidth * 2.0)
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
            if !viewState.isDragging {
                gestureStart()
            }
            scrollTranslation += offset.x * Self.scrollMultiplier
            gestureUpdate(translation: scrollTranslation,
                          location: ...)
        })
    }
#else
    private var gesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !viewState.isDragging {
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
}

// MARK: Gesture Actions

extension SwipeActions {
    
    private func gestureStart() {}
    
    private func gestureUpdate(translation: CGFloat, location: CGFloat) {
        
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
        
        if draggingAction {
            if viewState != .draggingAction {
                withAnimation {
                    viewState = .draggingAction
                }
            }
        } else {
            // TODO: Animate on first call
            viewState = .dragging(translation: translation, location: location)
        }
        
        if side != .leading, translation > 0.0 {
            side = .leading
        } else if side != .trailing, translation < 0.0 {
            side = .trailing
        }
    }
    
    private func gestureEnd() {
        
        var canReset: Bool = false
        if case .dragging(let translation, _) = viewState {
            canReset = abs(translation) < size.width * Self.dragResetAbsoluteFraction
        }
        
        if viewState == .draggingAction {
            viewState = .action
        } else if canReset {
            withAnimation {
                reset()
            }
        } else {
            withAnimation {
                viewState = .options
            }
        }
    }
}

// MARK: Button Actions

extension SwipeActions {
    
    private func willAction() {
        viewState = .action
    }
    
    private func didAction() {
        withAnimation {
            reset()
        }
    }
}

// MARK: Reset

extension SwipeActions {
    
    func reset() {
        side = nil
        viewState = .inactive
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
