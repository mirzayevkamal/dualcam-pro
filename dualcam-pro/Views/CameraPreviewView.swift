import SwiftUI
import AVFoundation

/// UIViewRepresentable that hosts dual AVCaptureVideoPreviewLayers arranged by layout mode.
struct CameraPreviewView: UIViewRepresentable {
    let backPreviewLayer: AVCaptureVideoPreviewLayer
    let frontPreviewLayer: AVCaptureVideoPreviewLayer
    let layoutMode: LayoutMode
    let pipPosition: PiPPosition
    let pipShape: PiPShape
    let onTapBack: (CGPoint) -> Void
    let onTapFront: (CGPoint) -> Void
    let onLongPressBack: () -> Void
    let onLongPressFront: () -> Void
    let onPinchZoom: (CGFloat, Bool) -> Void // (scale, isFrontCamera)
    let onPiPPositionChanged: (CGRect) -> Void

    func makeUIView(context: Context) -> DualPreviewUIView {
        let view = DualPreviewUIView()
        view.backPreviewLayer = backPreviewLayer
        view.frontPreviewLayer = frontPreviewLayer
        view.onTapBack = onTapBack
        view.onTapFront = onTapFront
        view.onLongPressBack = onLongPressBack
        view.onLongPressFront = onLongPressFront
        view.onPinchZoom = onPinchZoom
        view.onPiPPositionChanged = onPiPPositionChanged
        view.setupLayers()
        view.setupGestures()
        return view
    }

    func updateUIView(_ uiView: DualPreviewUIView, context: Context) {
        let needsReset = uiView.layoutMode != layoutMode ||
                         uiView.pipPosition != pipPosition ||
                         uiView.pipShape != pipShape
        uiView.layoutMode = layoutMode
        uiView.pipPosition = pipPosition
        uiView.pipShape = pipShape
        if needsReset {
            uiView.resetCustomPosition()
        }
        uiView.updateLayout()
    }
}

/// Custom UIView hosting two preview layers with dynamic layouts.
final class DualPreviewUIView: UIView {
    var backPreviewLayer: AVCaptureVideoPreviewLayer?
    var frontPreviewLayer: AVCaptureVideoPreviewLayer?

    var layoutMode: LayoutMode = .pip
    var pipPosition: PiPPosition = .bottomRight
    var pipShape: PiPShape = .rectangle

    var onTapBack: ((CGPoint) -> Void)?
    var onTapFront: ((CGPoint) -> Void)?
    var onLongPressBack: (() -> Void)?
    var onLongPressFront: (() -> Void)?
    var onPinchZoom: ((CGFloat, Bool) -> Void)? // (scale, isFrontCamera)
    var onPiPPositionChanged: ((CGRect) -> Void)?

    // PiP dragging / resizing state
    private var pipOffset: CGPoint = .zero
    private var isDraggingPiP = false
    private var isResizingPiP = false
    private var customPiPFrame: CGRect? = nil

    // Zoom
    private var initialPinchZoom: CGFloat = 1.0

    func setupLayers() {
        guard let back = backPreviewLayer, let front = frontPreviewLayer else { return }

        back.videoGravity = .resizeAspectFill
        front.videoGravity = .resizeAspectFill

        layer.addSublayer(back)
        layer.addSublayer(front)

        backgroundColor = .black
    }

    func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        addGestureRecognizer(longPress)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)
    }

    func resetCustomPosition() {
        customPiPFrame = nil
    }

    private func reportPiPPosition() {
        guard let front = frontPreviewLayer, bounds.width > 0, bounds.height > 0 else { return }
        let normalized = CGRect(
            x: front.frame.origin.x / bounds.width,
            y: front.frame.origin.y / bounds.height,
            width: front.frame.width / bounds.width,
            height: front.frame.height / bounds.height
        )
        onPiPPositionChanged?(normalized)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)

        if let front = frontPreviewLayer, front.frame.contains(point) {
            let converted = frontPreviewLayer?.captureDevicePointConverted(fromLayerPoint: point) ?? point
            onTapFront?(converted)
        } else {
            let converted = backPreviewLayer?.captureDevicePointConverted(fromLayerPoint: point) ?? point
            onTapBack?(converted)
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: self)

        if let front = frontPreviewLayer, front.frame.contains(point) {
            onLongPressFront?()
        } else {
            onLongPressBack?()
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard layoutMode == .pip || layoutMode == .reaction,
              let front = frontPreviewLayer else { return }

        let point = gesture.location(in: self)

        switch gesture.state {
        case .began:
            if front.frame.contains(point) {
                isDraggingPiP = true
                pipOffset = CGPoint(
                    x: point.x - front.frame.midX,
                    y: point.y - front.frame.midY
                )
            }
        case .changed:
            if isDraggingPiP {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                let pipSize = front.frame.size
                var newX = point.x - pipOffset.x - pipSize.width / 2
                var newY = point.y - pipOffset.y - pipSize.height / 2
                newX = max(8, min(bounds.width - pipSize.width - 8, newX))
                newY = max(8, min(bounds.height - pipSize.height - 8, newY))
                front.frame = CGRect(origin: CGPoint(x: newX, y: newY), size: pipSize)
                CATransaction.commit()
                customPiPFrame = front.frame
                reportPiPPosition()
            }
        case .ended, .cancelled:
            isDraggingPiP = false
        default:
            break
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let point = gesture.location(in: self)

        // Pinch on PiP → resize it
        if (layoutMode == .pip || layoutMode == .reaction),
           let front = frontPreviewLayer, front.frame.contains(point) {
            switch gesture.state {
            case .began:
                initialPinchZoom = gesture.scale
                isResizingPiP = true
            case .changed:
                let delta = gesture.scale / initialPinchZoom
                initialPinchZoom = gesture.scale
                resizePiP(by: delta)
            case .ended, .cancelled:
                isResizingPiP = false
            default:
                break
            }
        } else {
            // Pinch elsewhere → camera zoom
            let isFront = frontPreviewLayer?.frame.contains(point) ?? false
            switch gesture.state {
            case .began:
                initialPinchZoom = gesture.scale
            case .changed:
                let delta = gesture.scale / initialPinchZoom
                initialPinchZoom = gesture.scale
                onPinchZoom?(delta, isFront)
            default:
                break
            }
        }
    }

    private func resizePiP(by scaleDelta: CGFloat) {
        guard let front = frontPreviewLayer else { return }

        let center = CGPoint(x: front.frame.midX, y: front.frame.midY)
        let minSide: CGFloat = 60
        let maxW = bounds.width * 0.85
        let maxH = bounds.height * 0.85

        // Scale proportionally to maintain aspect ratio
        var newW = front.frame.width * scaleDelta
        var newH = front.frame.height * scaleDelta

        // Clamp while preserving aspect
        let aspect = front.frame.width / front.frame.height
        newW = max(minSide, min(maxW, newW))
        newH = newW / aspect
        if newH > maxH {
            newH = maxH
            newW = newH * aspect
        }
        if newH < minSide {
            newH = minSide
            newW = newH * aspect
        }

        let newSize = CGSize(width: newW, height: newH)
        let newX = max(8, min(bounds.width - newSize.width - 8, center.x - newSize.width / 2))
        let newY = max(8, min(bounds.height - newSize.height - 8, center.y - newSize.height / 2))

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        front.frame = CGRect(x: newX, y: newY, width: newSize.width, height: newSize.height)
        applyPiPStyle(to: front)
        CATransaction.commit()

        customPiPFrame = front.frame
        reportPiPPosition()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !isDraggingPiP, !isResizingPiP else { return }
        updateLayout()
    }

    func updateLayout() {
        guard !isDraggingPiP, !isResizingPiP else { return }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)

        // Clear any previous PiP styling for non-PiP layouts
        clearPiPStyle()

        switch layoutMode {
        case .pip:
            layoutPiP()
        case .splitHorizontal:
            layoutSplitHorizontal()
        case .splitVertical:
            layoutSplitVertical()
        case .reaction:
            layoutReaction()
        case .interview:
            layoutInterview()
        }

        CATransaction.commit()
    }

    // MARK: - PiP Layout

    private func layoutPiP() {
        guard let back = backPreviewLayer, let front = frontPreviewLayer else { return }

        back.frame = bounds
        back.cornerRadius = 0
        back.mask = nil

        if let custom = customPiPFrame {
            front.frame = custom
        } else {
            let pipSize = defaultPiPSize()
            let padding: CGFloat = 16

            let pipOrigin: CGPoint
            switch pipPosition {
            case .topLeft:
                pipOrigin = CGPoint(x: padding, y: padding + 60)
            case .topRight:
                pipOrigin = CGPoint(x: bounds.width - pipSize.width - padding, y: padding + 60)
            case .bottomLeft:
                pipOrigin = CGPoint(x: padding, y: bounds.height - pipSize.height - padding - 120)
            case .bottomRight:
                pipOrigin = CGPoint(x: bounds.width - pipSize.width - padding, y: bounds.height - pipSize.height - padding - 120)
            }

            front.frame = CGRect(origin: pipOrigin, size: pipSize)
        }

        applyPiPStyle(to: front)
        reportPiPPosition()
    }

    // MARK: - Split / Reaction / Interview Layouts

    private func layoutSplitHorizontal() {
        guard let back = backPreviewLayer, let front = frontPreviewLayer else { return }

        let halfW = bounds.width / 2
        back.frame = CGRect(x: 0, y: 0, width: halfW - 1, height: bounds.height)
        front.frame = CGRect(x: halfW + 1, y: 0, width: halfW - 1, height: bounds.height)

        resetLayerStyle(back)
        resetLayerStyle(front)
    }

    private func layoutSplitVertical() {
        guard let back = backPreviewLayer, let front = frontPreviewLayer else { return }

        let halfH = bounds.height / 2
        back.frame = CGRect(x: 0, y: 0, width: bounds.width, height: halfH - 1)
        front.frame = CGRect(x: 0, y: halfH + 1, width: bounds.width, height: halfH - 1)

        resetLayerStyle(back)
        resetLayerStyle(front)
    }

    private func layoutReaction() {
        guard let back = backPreviewLayer, let front = frontPreviewLayer else { return }

        back.frame = bounds
        back.cornerRadius = 0
        back.mask = nil

        if let custom = customPiPFrame {
            front.frame = custom
        } else {
            let pipSize = defaultPiPSize(scaleFactor: 1.3)
            let x = (bounds.width - pipSize.width) / 2
            let y = bounds.height - pipSize.height - 130
            front.frame = CGRect(x: x, y: y, width: pipSize.width, height: pipSize.height)
        }

        applyPiPStyle(to: front)
        reportPiPPosition()
    }

    private func layoutInterview() {
        guard let back = backPreviewLayer, let front = frontPreviewLayer else { return }

        let halfW = bounds.width / 2
        back.frame = CGRect(x: 0, y: 0, width: halfW - 1, height: bounds.height)
        front.frame = CGRect(x: halfW + 1, y: 0, width: halfW - 1, height: bounds.height)

        resetLayerStyle(back)
        resetLayerStyle(front)
    }

    private func resetLayerStyle(_ layer: CALayer) {
        layer.cornerRadius = 0
        layer.borderWidth = 0
        layer.mask = nil
        layer.masksToBounds = true
    }

    // MARK: - PiP Sizing

    /// Returns the default PiP size for the current shape.
    private func defaultPiPSize(scaleFactor: CGFloat = 1.0) -> CGSize {
        let w = bounds.width
        let h = bounds.height

        switch pipShape {
        case .rectangle:
            return CGSize(width: w * 0.32 * scaleFactor, height: h * 0.28 * scaleFactor)
        case .square:
            let side = min(w * 0.32, h * 0.28) * scaleFactor
            return CGSize(width: side, height: side)
        case .circle:
            let side = min(w * 0.32, h * 0.28) * scaleFactor
            return CGSize(width: side, height: side)
        case .pill:
            return CGSize(width: w * 0.22 * scaleFactor, height: h * 0.30 * scaleFactor)
        case .horizontalPill:
            return CGSize(width: w * 0.52 * scaleFactor, height: h * 0.12 * scaleFactor)
        }
    }

    // MARK: - PiP Styling

    private func clearPiPStyle() {
        frontPreviewLayer?.mask = nil
        frontPreviewLayer?.cornerRadius = 0
        frontPreviewLayer?.borderWidth = 0
        frontPreviewLayer?.borderColor = nil
    }

    private func applyPiPStyle(to layer: AVCaptureVideoPreviewLayer) {
        layer.mask = nil
        layer.masksToBounds = true
        layer.borderWidth = 2.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor

        switch pipShape {
        case .rectangle:
            layer.cornerRadius = min(layer.frame.width, layer.frame.height) * 0.08
        case .square:
            layer.cornerRadius = 0
        case .circle, .pill, .horizontalPill:
            layer.cornerRadius = min(layer.frame.width, layer.frame.height) / 2
        }
    }
}
