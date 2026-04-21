import SwiftUI

// MARK: - Design Tokens

private let accentAmber = Color(red: 0.93, green: 0.68, blue: 0.34)
private let accentAmberDark = Color(red: 0.82, green: 0.55, blue: 0.24)
private let textCream = Color(red: 0.96, green: 0.94, blue: 0.90)
private let mutedCream = Color(red: 0.96, green: 0.94, blue: 0.90).opacity(0.55)

// MARK: - Main Onboarding

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    @State private var pageAppeared = [false, false, false, false]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentPage) {
                HeroPage(isActive: pageAppeared[0], onNext: nextPage)
                    .tag(0)
                CustomizePage(isActive: pageAppeared[1], onNext: nextPage)
                    .tag(1)
                DragPage(isActive: pageAppeared[2], onNext: nextPage)
                    .tag(2)
                ExportPage(isActive: pageAppeared[3], onNext: { onComplete() })
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .onChange(of: currentPage) { _, newValue in
                withAnimation(.easeOut(duration: 0.3)) {
                    for i in 0..<4 {
                        pageAppeared[i] = (i == newValue)
                    }
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                    pageAppeared[0] = true
                }
            }
        }
        .statusBarHidden()
        .preferredColorScheme(.dark)
    }

    private func nextPage() {
        if currentPage < 3 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                currentPage += 1
            }
        } else {
            onComplete()
        }
    }
}

// MARK: - Screen 1: Hero

private struct HeroPage: View {
    let isActive: Bool
    let onNext: () -> Void
    @State private var phase = 0
    @State private var floatY: CGFloat = 0

    var body: some View {
        ZStack {
            // Rear camera feed
            SceneBackground(variant: .street)
                .opacity(phase >= 1 ? 1 : 0)
                .animation(.easeOut(duration: 0.8), value: phase)

            // Front camera bubble
            BubbleView(
                shape: .circle,
                width: 110, height: 110, cornerRadius: 55
            )
            .offset(y: floatY)
            .scaleEffect(phase >= 2 ? 1 : 0.3)
            .opacity(phase >= 2 ? 1 : 0)
            .position(x: UIScreen.main.bounds.width * 0.72,
                      y: UIScreen.main.bounds.height * (phase >= 2 ? 0.52 : 0.9))
            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: phase)

            // Text + CTA
            VStack(spacing: 0) {
                Spacer()
                OnboardingCopy(
                    title: "Record Both Sides.\nAt the Same Time.",
                    subtitle: "Capture the world and yourself in one shot — in stunning 4K.",
                    visible: phase >= 3
                )
                .padding(.bottom, 24)

                OnboardingCTA(
                    label: "Continue",
                    dotIndex: 0,
                    visible: phase >= 3,
                    action: onNext
                )
                .padding(.bottom, 44)
            }
            .padding(.horizontal, 24)
        }
        .onChange(of: isActive) { _, active in
            if active { runEntrance() } else { phase = 0 }
        }
        .onAppear {
            if isActive { runEntrance() }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatY = 6
            }
        }
    }

    private func runEntrance() {
        phase = 0
        withAnimation(.easeOut(duration: 0.8).delay(0.1)) { phase = 1 }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.5)) { phase = 2 }
        withAnimation(.easeOut(duration: 0.6).delay(1.0)) { phase = 3 }
    }
}

// MARK: - Screen 2: Customize (Shape Morphing)

private struct CustomizePage: View {
    let isActive: Bool
    let onNext: () -> Void
    @State private var visible = false
    @State private var shapeIndex = 0
    @State private var floatY: CGFloat = 0
    @State private var timerTask: Task<Void, Never>?

    private let shapes: [(String, CGFloat, CGFloat, CGFloat)] = [
        ("Circle",    110, 110, 55),
        ("Square",    120, 120, 22),
        ("Portrait",  100, 140, 20),
        ("Pill",      130,  90, 45),
    ]

    private let positions: [(CGFloat, CGFloat)] = [
        (0.72, 0.50),
        (0.28, 0.52),
        (0.30, 0.22),
        (0.72, 0.24),
    ]

    var body: some View {
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height
        let shape = shapes[shapeIndex]
        let pos = positions[shapeIndex]

        ZStack {
            SceneBackground(variant: .studio)
                .opacity(visible ? 1 : 0)
                .animation(.easeOut(duration: 0.6), value: visible)

            // Front camera bubble — morphs shape and position
            BubbleView(
                shape: shapeName(shapeIndex),
                width: shape.1, height: shape.2, cornerRadius: shape.3
            )
            .offset(y: floatY)
            .scaleEffect(visible ? 1 : 0.3)
            .opacity(visible ? 1 : 0)
            .position(x: screenW * pos.0, y: screenH * pos.1)
            .animation(.spring(response: 0.7, dampingFraction: 0.65), value: shapeIndex)
            .animation(.easeOut(duration: 0.6), value: visible)

            VStack(spacing: 0) {
                Spacer()

                // Shape picker chips
                HStack(spacing: 10) {
                    ForEach(0..<shapes.count, id: \.self) { i in
                        ShapeChip(
                            label: shapes[i].0,
                            shape: shapeName(i),
                            isSelected: i == shapeIndex
                        )
                    }
                }
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 10)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: visible)
                .padding(.bottom, 20)

                OnboardingCopy(
                    title: "Choose Your Style",
                    subtitle: "Morph the overlay to match your vibe. Four shapes. One tap.",
                    visible: visible
                )
                .padding(.bottom, 24)

                OnboardingCTA(
                    label: "Continue",
                    dotIndex: 1,
                    visible: visible,
                    action: onNext
                )
                .padding(.bottom, 44)
            }
            .padding(.horizontal, 24)
        }
        .onChange(of: isActive) { _, active in
            timerTask?.cancel()
            if active {
                shapeIndex = 0
                withAnimation(.easeOut(duration: 0.5).delay(0.25)) { visible = true }
                timerTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(1.8))
                        guard !Task.isCancelled else { break }
                        withAnimation { shapeIndex = (shapeIndex + 1) % shapes.count }
                    }
                }
            } else {
                visible = false
            }
        }
        .onDisappear { timerTask?.cancel() }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatY = 5
            }
        }
    }

    private func shapeName(_ index: Int) -> BubbleShape {
        [.circle, .square, .rectangle, .pill][index]
    }
}

// MARK: - Screen 3: Drag

private struct DragPage: View {
    let isActive: Bool
    let onNext: () -> Void
    @State private var visible = false
    @State private var bubblePos: CGPoint = .zero
    @State private var isDragging = false
    @State private var showHint = false
    @State private var floatY: CGFloat = 0
    @State private var dragTimer: Timer?

    private let screenW = UIScreen.main.bounds.width
    private let screenH = UIScreen.main.bounds.height

    var body: some View {
        ZStack {
            SceneBackground(variant: .night)
                .opacity(visible ? 1 : 0)
                .animation(.easeOut(duration: 0.6), value: visible)

            // Ghost drop targets
            ForEach(0..<4, id: \.self) { i in
                let positions: [(CGFloat, CGFloat)] = [
                    (0.28, 0.24), (0.72, 0.24),
                    (0.28, 0.52), (0.72, 0.52),
                ]
                let p = positions[i]
                Circle()
                    .strokeBorder(accentAmber, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .frame(width: 110, height: 110)
                    .position(x: screenW * p.0, y: screenH * p.1)
                    .opacity(isDragging ? 0.35 : 0)
                    .animation(.easeOut(duration: 0.3), value: isDragging)
            }

            // Front camera bubble
            BubbleView(shape: .circle, width: 110, height: 110, cornerRadius: 55)
                .offset(y: isDragging ? 0 : floatY)
                .scaleEffect(visible ? (isDragging ? 1.05 : 1.0) : 0.3)
                .opacity(visible ? 1 : 0)
                .shadow(color: .black.opacity(isDragging ? 0.5 : 0.3),
                        radius: isDragging ? 30 : 15, y: isDragging ? 16 : 8)
                .position(bubblePos)
                .animation(isDragging
                    ? .interactiveSpring(response: 0.35, dampingFraction: 0.7)
                    : .spring(response: 0.9, dampingFraction: 0.6),
                    value: bubblePos)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isDragging)

            // Finger hint
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                .shadow(color: .white.opacity(0.2), radius: 3)
                .position(x: bubblePos.x + 28, y: bubblePos.y + 28)
                .opacity(showHint && isDragging ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: isDragging)
                .animation(isDragging
                    ? .interactiveSpring(response: 0.35, dampingFraction: 0.7)
                    : .spring(response: 0.9, dampingFraction: 0.6),
                    value: bubblePos)

            VStack(spacing: 0) {
                Spacer()
                OnboardingCopy(
                    title: "Move It Anywhere\nWhile Recording",
                    subtitle: "Drag. Release. Spring snaps it in place.",
                    visible: visible
                )
                .padding(.bottom, 24)

                OnboardingCTA(
                    label: "Continue",
                    dotIndex: 2,
                    visible: visible,
                    action: onNext
                )
                .padding(.bottom, 44)
            }
            .padding(.horizontal, 24)
        }
        .onChange(of: isActive) { _, active in
            if active {
                bubblePos = CGPoint(x: screenW * 0.72, y: screenH * 0.52)
                withAnimation(.easeOut(duration: 0.5).delay(0.25)) { visible = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { showHint = true }
                startDragSequence()
            } else {
                visible = false
                showHint = false
                dragTimer?.invalidate()
                dragTimer = nil
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatY = 5
            }
        }
    }

    private func startDragSequence() {
        let seq: [(TimeInterval, CGPoint, Bool)] = [
            (1.4, CGPoint(x: screenW * 0.72, y: screenH * 0.52), true),
            (2.0, CGPoint(x: screenW * 0.50, y: screenH * 0.40), true),
            (2.6, CGPoint(x: screenW * 0.28, y: screenH * 0.26), true),
            (3.0, CGPoint(x: screenW * 0.28, y: screenH * 0.24), false),
            (5.0, CGPoint(x: screenW * 0.28, y: screenH * 0.24), true),
            (5.5, CGPoint(x: screenW * 0.50, y: screenH * 0.40), true),
            (6.0, CGPoint(x: screenW * 0.72, y: screenH * 0.54), true),
            (6.4, CGPoint(x: screenW * 0.72, y: screenH * 0.52), false),
        ]

        for step in seq {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.0) { [self] in
                guard isActive else { return }
                isDragging = step.2
                bubblePos = step.1
            }
        }

        // Loop
        dragTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: true) { _ in
            guard isActive else { return }
            let loopSeq: [(TimeInterval, CGPoint, Bool)] = [
                (0.0, CGPoint(x: screenW * 0.72, y: screenH * 0.52), true),
                (0.6, CGPoint(x: screenW * 0.30, y: screenH * 0.26), true),
                (1.4, CGPoint(x: screenW * 0.28, y: screenH * 0.24), false),
                (3.0, CGPoint(x: screenW * 0.28, y: screenH * 0.24), true),
                (3.6, CGPoint(x: screenW * 0.72, y: screenH * 0.54), true),
                (4.4, CGPoint(x: screenW * 0.72, y: screenH * 0.52), false),
            ]
            for step in loopSeq {
                DispatchQueue.main.asyncAfter(deadline: .now() + step.0) {
                    guard isActive else { return }
                    isDragging = step.2
                    bubblePos = step.1
                }
            }
        }
    }
}

// MARK: - Screen 4: Export

private struct ExportPage: View {
    let isActive: Bool
    let onNext: () -> Void
    @State private var visible = false
    @State private var stage = 0 // 0: idle, 1: recording, 2: exporting, 3: done
    @State private var timer = 0
    @State private var progress: Double = 0
    @State private var floatY: CGFloat = 0
    @State private var loopTimer: Timer?

    var body: some View {
        ZStack {
            SceneBackground(variant: .street)
                .opacity(visible && stage < 3 ? 1 : (stage >= 3 ? 0.3 : 0))
                .animation(.easeOut(duration: 0.8), value: stage)
                .animation(.easeOut(duration: 0.6), value: visible)

            // Front camera bubble (fades during export)
            BubbleView(shape: .circle, width: 110, height: 110, cornerRadius: 55)
                .offset(y: floatY)
                .scaleEffect(stage < 2 ? 1 : 0.6)
                .opacity(visible ? (stage < 2 ? 1 : 0) : 0)
                .position(x: UIScreen.main.bounds.width * 0.72,
                          y: UIScreen.main.bounds.height * 0.52)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: stage)

            // REC indicator
            if stage == 1 {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("REC \(String(format: "%02d:%02d", timer / 60, timer % 60))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.36, blue: 0.31))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.22))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 0.5))
                .position(x: UIScreen.main.bounds.width * 0.65, y: 58)
                .transition(.opacity)
            }

            // Export card
            if stage >= 2 {
                ExportCard(stage: stage, progress: progress)
                    .position(x: UIScreen.main.bounds.width / 2,
                              y: UIScreen.main.bounds.height * 0.38)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            // Success check
            if stage == 3 {
                ZStack {
                    Circle()
                        .fill(accentAmber)
                        .frame(width: 64, height: 64)
                        .shadow(color: accentAmber.opacity(0.4), radius: 20)
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(red: 0.1, green: 0.07, blue: 0.04))
                }
                .position(x: UIScreen.main.bounds.width / 2,
                          y: UIScreen.main.bounds.height * 0.18)
                .transition(.scale.combined(with: .opacity))
            }

            VStack(spacing: 0) {
                Spacer()
                OnboardingCopy(
                    title: "Fast Export.\nHD Quality.",
                    subtitle: "4K · 60fps · H.265. One tap to save or share.",
                    visible: visible
                )
                .padding(.bottom, 24)

                OnboardingCTA(
                    label: "Get Started",
                    dotIndex: 3,
                    visible: visible,
                    action: onNext
                )
                .padding(.bottom, 44)
            }
            .padding(.horizontal, 24)
        }
        .onChange(of: isActive) { _, active in
            if active {
                withAnimation(.easeOut(duration: 0.5).delay(0.25)) { visible = true }
                runExportSequence()
            } else {
                visible = false
                stage = 0; timer = 0; progress = 0
                loopTimer?.invalidate(); loopTimer = nil
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatY = 5
            }
        }
    }

    private func runSequenceOnce() {
        stage = 0; timer = 0; progress = 0

        // Record phase
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard isActive else { return }
            withAnimation { stage = 1 }
        }
        for i in 1...24 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + Double(i) * 0.09) {
                guard isActive else { return }
                timer = i
            }
        }
        // Export phase
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            guard isActive else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { stage = 2 }
        }
        for i in stride(from: 0, through: 100, by: 2) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.1 + Double(i) * 0.012) {
                guard isActive else { return }
                progress = Double(i)
            }
        }
        // Done
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            guard isActive else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { stage = 3 }
        }
    }

    private func runExportSequence() {
        runSequenceOnce()
        loopTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            guard isActive else { return }
            runSequenceOnce()
        }
    }
}

// MARK: - Export Card

private struct ExportCard: View {
    let stage: Int
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(stage == 3 ? "Saved to Photos" : "Exporting")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(textCream.opacity(0.55))
                .textCase(.uppercase)
                .tracking(0.3)
                .padding(.bottom, 8)

            Text(stage == 3 ? "Done." : "dual_clip_0421.mp4")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(textCream)
                .tracking(-0.4)
                .padding(.bottom, 16)

            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.08))
                    .frame(height: 6)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(
                            colors: [accentAmber, Color(red: 1.0, green: 0.85, blue: 0.61)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * (stage == 3 ? 1.0 : progress / 100))
                        .shadow(color: accentAmber.opacity(0.6), radius: 6)
                }
                .frame(height: 6)
            }
            .padding(.bottom, 10)

            HStack {
                Text("4K · 60fps · H.265")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(textCream.opacity(0.55))
                Spacer()
                Text(stage == 3 ? "✓ 24 MB" : "\(Int(progress))%")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(stage == 3 ? accentAmber : textCream.opacity(0.55))
            }
        }
        .padding(24)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(red: 0.08, green: 0.06, blue: 0.04).opacity(0.65))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(.white.opacity(0.12), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.6), radius: 30, y: 20)
    }
}

// MARK: - Shared Components

private struct OnboardingCopy: View {
    let title: String
    let subtitle: String
    let visible: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.8)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(textCream)
                .shadow(color: .black.opacity(0.5), radius: 10, y: 2)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 16)
                .animation(.easeOut(duration: 0.7), value: visible)

            Text(subtitle)
                .font(.system(size: 15, weight: .regular))
                .tracking(-0.1)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(textCream.opacity(0.55))
                .shadow(color: .black.opacity(0.5), radius: 5, y: 1)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 16)
                .animation(.easeOut(duration: 0.7).delay(0.12), value: visible)
        }
    }
}

private struct OnboardingCTA: View {
    let label: String
    let dotIndex: Int
    let visible: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i == dotIndex ? accentAmber : .white.opacity(0.25))
                        .frame(width: i == dotIndex ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: dotIndex)
                }
            }

            // Button
            Button(action: action) {
                Text(label)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(Color(red: 0.1, green: 0.07, blue: 0.04))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [accentAmber, accentAmberDark],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: accentAmber.opacity(0.15), radius: 12, y: 8)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 20)
        .animation(.easeOut(duration: 0.6).delay(0.3), value: visible)
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Front Camera Bubble

enum BubbleShape {
    case circle, square, rectangle, pill
}

private struct BubbleView: View {
    let shape: BubbleShape
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            // Background gradient (simulated selfie)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.29, green: 0.23, blue: 0.18),
                            Color(red: 0.12, green: 0.08, blue: 0.06),
                            Color(red: 0.04, green: 0.02, blue: 0.02),
                        ],
                        center: .init(x: 0.4, y: 0.3),
                        startRadius: 0,
                        endRadius: max(width, height) * 0.9
                    )
                )
                .frame(width: width, height: height)

            // Warm face blob
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.82, blue: 0.67).opacity(0.7),
                            Color(red: 0.82, green: 0.51, blue: 0.31).opacity(0.3),
                            .clear,
                        ],
                        center: .init(x: 0.5, y: 0.55),
                        startRadius: 0,
                        endRadius: min(width, height) * 0.5
                    )
                )
                .frame(width: width * 0.6, height: height * 0.55)
                .offset(y: -height * 0.05)

            // Highlight
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .clear],
                        startPoint: .topLeading, endPoint: .center
                    )
                )
                .frame(width: width, height: height)

            // LIVE dot
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
                .shadow(color: Color.red.opacity(0.8), radius: 4)
                .position(x: width - 10, y: 10)
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(.white.opacity(0.25), lineWidth: 0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(.white.opacity(0.12), lineWidth: 1.5)
                .padding(0.5)
        )
        .shadow(color: .black.opacity(0.45), radius: 20, y: 12)
        .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
    }
}

// MARK: - Shape Chip

private struct ShapeChip: View {
    let label: String
    let shape: BubbleShape
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            chipIcon
                .frame(width: 14, height: 14)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .tracking(-0.1)
        }
        .foregroundStyle(isSelected ? textCream : textCream.opacity(0.5))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial.opacity(isSelected ? 0.3 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(isSelected ? 0.3 : 0.1), lineWidth: 0.5)
                )
        )
        .animation(.easeOut(duration: 0.4), value: isSelected)
    }

    @ViewBuilder
    private var chipIcon: some View {
        switch shape {
        case .circle:
            Circle()
                .stroke(lineWidth: 1.5)
        case .square:
            RoundedRectangle(cornerRadius: 3)
                .stroke(lineWidth: 1.5)
        case .rectangle:
            RoundedRectangle(cornerRadius: 2)
                .stroke(lineWidth: 1.5)
                .frame(width: 10.5, height: 14)
        case .pill:
            Capsule()
                .stroke(lineWidth: 1.5)
                .frame(width: 16.8, height: 11.2)
        }
    }
}

// MARK: - Scene Background

private enum SceneVariant {
    case street, studio, night
}

private struct SceneBackground: View {
    let variant: SceneVariant

    var body: some View {
        ZStack {
            // Base gradient
            baseGradient

            // Warm blobs
            ForEach(Array(blobs.enumerated()), id: \.offset) { _, blob in
                Circle()
                    .fill(blob.color)
                    .frame(width: blob.size, height: blob.size)
                    .blur(radius: blob.blur)
                    .position(x: UIScreen.main.bounds.width * blob.x,
                              y: UIScreen.main.bounds.height * blob.y)
            }

            // Vignette
            RadialGradient(
                colors: [.clear, .black.opacity(0.5)],
                center: .center,
                startRadius: UIScreen.main.bounds.width * 0.4,
                endRadius: UIScreen.main.bounds.width * 0.9
            )
        }
        .ignoresSafeArea()
    }

    private var baseGradient: some View {
        switch variant {
        case .street:
            return AnyView(
                RadialGradient(
                    colors: [
                        Color(red: 0.23, green: 0.14, blue: 0.09),
                        Color(red: 0.10, green: 0.06, blue: 0.04),
                        .black,
                    ],
                    center: .init(x: 0.3, y: 0.2),
                    startRadius: 0,
                    endRadius: UIScreen.main.bounds.height * 0.8
                )
            )
        case .studio:
            return AnyView(
                RadialGradient(
                    colors: [
                        Color(red: 0.17, green: 0.12, blue: 0.09),
                        Color(red: 0.07, green: 0.04, blue: 0.02),
                        .black,
                    ],
                    center: .init(x: 0.5, y: 0.4),
                    startRadius: 0,
                    endRadius: UIScreen.main.bounds.height * 0.7
                )
            )
        case .night:
            return AnyView(
                RadialGradient(
                    colors: [
                        Color(red: 0.10, green: 0.14, blue: 0.22),
                        Color(red: 0.04, green: 0.06, blue: 0.11),
                        .black,
                    ],
                    center: .init(x: 0.7, y: 0.3),
                    startRadius: 0,
                    endRadius: UIScreen.main.bounds.height * 0.8
                )
            )
        }
    }

    private struct Blob {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let color: Color
        let blur: CGFloat
    }

    private var blobs: [Blob] {
        switch variant {
        case .street:
            return [
                Blob(x: 0.20, y: 0.30, size: 280, color: Color(red: 1.0, green: 0.66, blue: 0.35).opacity(0.45), blur: 80),
                Blob(x: 0.75, y: 0.65, size: 340, color: Color(red: 0.84, green: 0.36, blue: 0.17).opacity(0.35), blur: 100),
                Blob(x: 0.55, y: 0.15, size: 180, color: Color(red: 1.0, green: 0.86, blue: 0.59).opacity(0.28), blur: 60),
            ]
        case .studio:
            return [
                Blob(x: 0.50, y: 0.35, size: 400, color: Color(red: 1.0, green: 0.78, blue: 0.55).opacity(0.35), blur: 120),
                Blob(x: 0.20, y: 0.80, size: 220, color: Color(red: 0.71, green: 0.27, blue: 0.16).opacity(0.30), blur: 80),
            ]
        case .night:
            return [
                Blob(x: 0.70, y: 0.25, size: 300, color: Color(red: 0.47, green: 0.63, blue: 1.0).opacity(0.25), blur: 100),
                Blob(x: 0.25, y: 0.70, size: 260, color: Color(red: 1.0, green: 0.55, blue: 0.35).opacity(0.30), blur: 90),
            ]
        }
    }
}
