// MacVital/Views/Shared/ResizableContainer.swift
//
// Generic drag-resizable wrapper for V2 section panes.
// Persists height/width to UserDefaults on drag-end.
// Keys: mv.resize.<id>.height and mv.resize.<id>.width
//
// Usage:
//   MyPane()
//       .resizable(id: "network-domains", default: CGSize(width: 0, height: 280),
//                  min: CGSize(width: 0, height: 120), max: CGSize(width: 0, height: 600))

import SwiftUI

// MARK: - Axis

enum ResizeAxis {
    case vertical
    case both
}

// MARK: - Container

struct ResizableContainer<Content: View>: View {

    let id: String
    let axis: ResizeAxis
    let defaultSize: CGSize
    let minSize: CGSize
    let maxSize: CGSize
    @ViewBuilder let content: () -> Content

    // Persisted dimensions (0 = unset, falls back to defaultSize)
    @State private var currentHeight: CGFloat
    @State private var currentWidth: CGFloat

    // Drag accumulator -- tracks gesture-relative delta from drag start
    @State private var dragStartHeight: CGFloat = 0
    @State private var dragStartWidth: CGFloat = 0

    // Hover state for handle fade
    @State private var handleHovered = false

    // Keyboard focus
    @FocusState private var isFocused: Bool

    init(
        id: String,
        axis: ResizeAxis = .vertical,
        defaultSize: CGSize,
        minSize: CGSize,
        maxSize: CGSize,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.id = id
        self.axis = axis
        self.defaultSize = defaultSize
        self.minSize = minSize
        self.maxSize = maxSize
        self.content = content

        let savedH = UserDefaults.standard.double(forKey: "mv.resize.\(id).height")
        let savedW = UserDefaults.standard.double(forKey: "mv.resize.\(id).width")
        _currentHeight = State(initialValue: savedH > 0 ? savedH : defaultSize.height)
        _currentWidth  = State(initialValue: savedW > 0 ? savedW : defaultSize.width)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content()
                .frame(
                    width:  axis == .both ? currentWidth  : nil,
                    height: currentHeight
                )

            // Bottom handle (always shown for .vertical and .both)
            bottomHandle

            // Right handle (only for .both)
            if axis == .both {
                rightHandle
            }
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
            handleKey(press.key)
        }
    }

    // MARK: - Bottom drag handle

    private var bottomHandle: some View {
        ResizeHandle(
            orientation: .horizontal,
            isHovered: handleHovered,
            id: id
        )
        .onHover { handleHovered = $0 }
        .gesture(verticalDrag)
        .frame(maxWidth: .infinity)
        .frame(alignment: .bottom)
    }

    // MARK: - Right drag handle

    private var rightHandle: some View {
        ResizeHandle(
            orientation: .vertical,
            isHovered: handleHovered,
            id: id
        )
        .onHover { handleHovered = $0 }
        .gesture(horizontalDrag)
        .frame(maxHeight: .infinity)
        .frame(alignment: .trailing)
    }

    // MARK: - Gestures

    private var verticalDrag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if value.translation.height != 0 && dragStartHeight == 0 {
                    dragStartHeight = currentHeight
                }
                let proposed = dragStartHeight + value.translation.height
                currentHeight = snap(proposed, lo: minSize.height, hi: maxSize.height)
            }
            .onEnded { _ in
                dragStartHeight = 0
                persist()
            }
    }

    private var horizontalDrag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if value.translation.width != 0 && dragStartWidth == 0 {
                    dragStartWidth = currentWidth
                }
                let proposed = dragStartWidth + value.translation.width
                currentWidth = snap(proposed, lo: minSize.width, hi: maxSize.width)
            }
            .onEnded { _ in
                dragStartWidth = 0
                persist()
            }
    }

    // MARK: - Keyboard

    private func handleKey(_ key: KeyEquivalent) -> KeyPress.Result {
        switch key {
        case .upArrow:
            currentHeight = snap(currentHeight - 8, lo: minSize.height, hi: maxSize.height)
            persist()
            return .handled
        case .downArrow:
            currentHeight = snap(currentHeight + 8, lo: minSize.height, hi: maxSize.height)
            persist()
            return .handled
        case .leftArrow where axis == .both:
            currentWidth = snap(currentWidth - 8, lo: minSize.width, hi: maxSize.width)
            persist()
            return .handled
        case .rightArrow where axis == .both:
            currentWidth = snap(currentWidth + 8, lo: minSize.width, hi: maxSize.width)
            persist()
            return .handled
        default:
            return .ignored
        }
    }

    // MARK: - Helpers

    /// Snap to nearest 8pt grid, clamped between lo and hi.
    private func snap(_ value: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
        let snapped = (value / 8).rounded() * 8
        return max(lo, min(hi, snapped))
    }

    private func persist() {
        UserDefaults.standard.set(Double(currentHeight), forKey: "mv.resize.\(id).height")
        if axis == .both {
            UserDefaults.standard.set(Double(currentWidth), forKey: "mv.resize.\(id).width")
        }
    }
}

// MARK: - Handle strip

private struct ResizeHandle: View {

    enum Orientation { case horizontal, vertical }

    let orientation: Orientation
    let isHovered: Bool
    let id: String

    private let thickness: CGFloat = 6

    var body: some View {
        ZStack {
            // Hairline base
            Rectangle()
                .fill(MV.hairline)

            // Accent overlay on hover
            Rectangle()
                .fill(MV.accentSage.opacity(isHovered ? 0.4 : 0))
                .animation(.easeInOut(duration: 0.18), value: isHovered)

            // Drag pip (3 dots)
            pip
        }
        .frame(
            width:  orientation == .vertical   ? thickness : nil,
            height: orientation == .horizontal ? thickness : nil
        )
        .cursor(orientation)
    }

    private var pip: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(MV.text4)
                    .frame(width: 3, height: 3)
            }
        }
        .rotationEffect(orientation == .vertical ? .degrees(90) : .zero)
        .opacity(isHovered ? 1 : 0.4)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
    }
}

// MARK: - Cursor helper

private extension View {
    @ViewBuilder
    func cursor(_ orientation: ResizeHandle.Orientation) -> some View {
        if orientation == .horizontal {
            self.onHover { inside in
                if inside {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
        } else {
            self.onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
}

// MARK: - View modifier

extension View {
    /// Wraps this view in a `ResizableContainer` with drag-resize handles.
    ///
    /// Example:
    /// ```swift
    /// MyPane()
    ///     .resizable(
    ///         id: "network-domains",
    ///         axis: .vertical,
    ///         default: CGSize(width: 0, height: 280),
    ///         min:     CGSize(width: 0, height: 120),
    ///         max:     CGSize(width: 0, height: 600)
    ///     )
    /// ```
    func resizable(
        id: String,
        axis: ResizeAxis = .vertical,
        default defaultSize: CGSize,
        min minSize: CGSize,
        max maxSize: CGSize
    ) -> some View {
        ResizableContainer(
            id: id,
            axis: axis,
            defaultSize: defaultSize,
            minSize: minSize,
            maxSize: maxSize
        ) {
            self
        }
    }
}
