// Individual onboarding screens

// ─────────────────────────────────────────────────────────────
// SCREEN 1 — HERO
// Rear camera fades in, front bubble scales+slides in with float
// ─────────────────────────────────────────────────────────────
function HeroScreen({ active, onNext, floatPhase }) {
  const [phase, setPhase] = React.useState(0);
  // 0: nothing, 1: rear visible, 2: bubble in, 3: text in

  React.useEffect(() => {
    if (!active) { setPhase(0); return; }
    const t1 = setTimeout(() => setPhase(1), 100);
    const t2 = setTimeout(() => setPhase(2), 600);
    const t3 = setTimeout(() => setPhase(3), 1100);
    return () => { clearTimeout(t1); clearTimeout(t2); clearTimeout(t3); };
  }, [active]);

  return (
    <div style={{ position: 'absolute', inset: 0, background: '#000', overflow: 'hidden' }}>
      {/* rear feed */}
      <div style={{
        position: 'absolute', inset: 0,
        opacity: phase >= 1 ? 1 : 0,
        transition: 'opacity 0.8s cubic-bezier(0.22,1,0.36,1)',
      }}>
        <RearCameraFeed variant="street" parallax={Math.sin(floatPhase * 0.3) * 6} />
      </div>

      {/* camera chrome fades in with rear */}
      <div style={{
        opacity: phase >= 1 ? 1 : 0,
        transition: 'opacity 0.8s ease 0.2s',
      }}>
        <CameraChrome />
      </div>

      {/* front bubble — scales + slides from below */}
      <FrontCameraBubble
        shape="circle"
        x="72%"
        y={phase >= 2 ? '70%' : '110%'}
        scale={phase >= 2 ? 1 : 0.3}
        opacity={phase >= 2 ? 1 : 0}
        floating={phase >= 3}
        floatPhase={floatPhase}
      />

      <ScreenCopy
        title={<>Record Both Sides.<br/>At the Same Time.</>}
        subtitle="Capture the world and yourself in one shot — in stunning 4K."
        visible={phase >= 3}
      />

      <BottomCTA
        label="Continue"
        onClick={onNext}
        visible={phase >= 3}
        dots={0}
      />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// SCREEN 2 — CUSTOMIZATION (shape morphing)
// ─────────────────────────────────────────────────────────────
function CustomizeScreen({ active, onNext, floatPhase }) {
  const shapes = ['circle', 'square', 'rectangle', 'pill'];
  const positions = [
    { x: '72%', y: '68%' },
    { x: '28%', y: '70%' },
    { x: '30%', y: '28%' },
    { x: '72%', y: '30%' },
  ];
  const [idx, setIdx] = React.useState(0);
  const [visible, setVisible] = React.useState(false);

  React.useEffect(() => {
    if (!active) { setVisible(false); setIdx(0); return; }
    const tV = setTimeout(() => setVisible(true), 250);
    const interval = setInterval(() => {
      setIdx(i => (i + 1) % shapes.length);
    }, 1800);
    return () => { clearTimeout(tV); clearInterval(interval); };
  }, [active]);

  const shapeLabels = {
    circle: 'Circle',
    square: 'Square',
    rectangle: 'Portrait',
    pill: 'Pill',
  };

  return (
    <div style={{ position: 'absolute', inset: 0, background: '#000', overflow: 'hidden' }}>
      <div style={{
        position: 'absolute', inset: 0,
        opacity: visible ? 1 : 0,
        transition: 'opacity 0.6s ease',
      }}>
        <RearCameraFeed variant="studio" parallax={Math.sin(floatPhase * 0.3) * 4} />
      </div>

      <div style={{ opacity: visible ? 1 : 0, transition: 'opacity 0.6s ease' }}>
        <CameraChrome />
      </div>

      <FrontCameraBubble
        shape={shapes[idx]}
        x={positions[idx].x}
        y={positions[idx].y}
        scale={visible ? 1 : 0.3}
        opacity={visible ? 1 : 0}
        floating
        floatPhase={floatPhase}
      />

      {/* shape picker chips */}
      <div style={{
        position: 'absolute', bottom: 300, left: 0, right: 0,
        display: 'flex', justifyContent: 'center', gap: 10,
        zIndex: 25,
        opacity: visible ? 1 : 0,
        transform: visible ? 'translateY(0)' : 'translateY(10px)',
        transition: 'opacity 0.6s ease 0.4s, transform 0.6s ease 0.4s',
      }}>
        {shapes.map((s, i) => (
          <div key={s} style={{
            padding: '8px 14px',
            borderRadius: 14,
            background: i === idx ? 'rgba(255,255,255,0.18)' : 'rgba(255,255,255,0.06)',
            backdropFilter: 'blur(20px)',
            WebkitBackdropFilter: 'blur(20px)',
            border: `0.5px solid ${i === idx ? 'rgba(255,255,255,0.3)' : 'rgba(255,255,255,0.1)'}`,
            fontSize: 12, fontWeight: 600,
            color: i === idx ? TEXT : MUTED,
            fontFamily: '-apple-system, system-ui',
            letterSpacing: -0.1,
            transition: 'all 0.4s cubic-bezier(0.22,1,0.36,1)',
            display: 'flex', alignItems: 'center', gap: 6,
          }}>
            <ShapeIcon shape={s} active={i === idx} />
            {shapeLabels[s]}
          </div>
        ))}
      </div>

      <ScreenCopy
        title="Choose Your Style"
        subtitle="Morph the overlay to match your vibe. Four shapes. One tap."
        visible={visible}
      />

      <BottomCTA
        label="Continue"
        onClick={onNext}
        visible={visible}
        dots={1}
      />
    </div>
  );
}

function ShapeIcon({ shape, active }) {
  const c = active ? '#f5efe6' : 'rgba(245,239,230,0.5)';
  const sz = 14;
  if (shape === 'circle') return <div style={{ width: sz, height: sz, border: `1.5px solid ${c}`, borderRadius: '50%' }} />;
  if (shape === 'square') return <div style={{ width: sz, height: sz, border: `1.5px solid ${c}`, borderRadius: 3 }} />;
  if (shape === 'rectangle') return <div style={{ width: sz * 0.75, height: sz, border: `1.5px solid ${c}`, borderRadius: 2 }} />;
  if (shape === 'pill') return <div style={{ width: sz * 1.2, height: sz * 0.8, border: `1.5px solid ${c}`, borderRadius: sz }} />;
}

// ─────────────────────────────────────────────────────────────
// SCREEN 3 — DRAG / MOVEMENT
// Simulated drag with spring release
// ─────────────────────────────────────────────────────────────
function DragScreen({ active, onNext, floatPhase }) {
  const [visible, setVisible] = React.useState(false);
  const [pos, setPos] = React.useState({ x: '72%', y: '70%' });
  const [dragging, setDragging] = React.useState(false);
  const [showHint, setShowHint] = React.useState(false);

  // simulated drag path
  React.useEffect(() => {
    if (!active) {
      setVisible(false);
      setPos({ x: '72%', y: '70%' });
      setDragging(false);
      setShowHint(false);
      return;
    }
    const tV = setTimeout(() => setVisible(true), 250);
    const tH = setTimeout(() => setShowHint(true), 700);

    // scripted drag sequence
    const seq = [
      { t: 1400, action: () => { setDragging(true); setPos({ x: '72%', y: '70%' }); } },
      { t: 1900, action: () => setPos({ x: '50%', y: '55%' }) },
      { t: 2400, action: () => setPos({ x: '28%', y: '35%' }) },
      { t: 2900, action: () => setPos({ x: '28%', y: '30%' }) },
      { t: 3200, action: () => { setDragging(false); setPos({ x: '28%', y: '30%' }); } }, // spring release
      { t: 5000, action: () => { setDragging(true); setPos({ x: '28%', y: '30%' }); } },
      { t: 5400, action: () => setPos({ x: '50%', y: '55%' }) },
      { t: 5800, action: () => setPos({ x: '72%', y: '72%' }) },
      { t: 6100, action: () => { setDragging(false); setPos({ x: '72%', y: '70%' }); } },
    ];
    const timers = seq.map(s => setTimeout(s.action, s.t));

    // loop
    const loop = setInterval(() => {
      setDragging(true);
      setPos({ x: '72%', y: '70%' });
      setTimeout(() => setPos({ x: '30%', y: '32%' }), 600);
      setTimeout(() => { setDragging(false); setPos({ x: '28%', y: '30%' }); }, 1400);
      setTimeout(() => {
        setDragging(true);
        setPos({ x: '28%', y: '30%' });
      }, 3000);
      setTimeout(() => setPos({ x: '72%', y: '72%' }), 3600);
      setTimeout(() => { setDragging(false); setPos({ x: '72%', y: '70%' }); }, 4400);
    }, 7000);

    return () => {
      clearTimeout(tV); clearTimeout(tH);
      timers.forEach(clearTimeout);
      clearInterval(loop);
    };
  }, [active]);

  return (
    <div style={{ position: 'absolute', inset: 0, background: '#000', overflow: 'hidden' }}>
      <div style={{
        position: 'absolute', inset: 0,
        opacity: visible ? 1 : 0,
        transition: 'opacity 0.6s ease',
      }}>
        <RearCameraFeed variant="night" parallax={Math.sin(floatPhase * 0.3) * 5} />
      </div>

      <div style={{ opacity: visible ? 1 : 0, transition: 'opacity 0.6s ease' }}>
        <CameraChrome />
      </div>

      {/* ghost drop-target zones */}
      <div style={{
        position: 'absolute', inset: 0,
        opacity: dragging ? 1 : 0,
        transition: 'opacity 0.3s ease',
        pointerEvents: 'none',
      }}>
        {[
          { x: '28%', y: '30%' },
          { x: '72%', y: '30%' },
          { x: '28%', y: '70%' },
          { x: '72%', y: '70%' },
        ].map((p, i) => (
          <div key={i} style={{
            position: 'absolute', left: p.x, top: p.y,
            transform: 'translate(-50%, -50%)',
            width: 110, height: 110,
            borderRadius: '50%',
            border: `1.5px dashed ${ACCENT}`,
            opacity: 0.35,
          }} />
        ))}
      </div>

      <FrontCameraBubble
        shape="circle"
        x={pos.x}
        y={pos.y}
        scale={visible ? 1 : 0.3}
        opacity={visible ? 1 : 0}
        floating={!dragging && visible}
        floatPhase={floatPhase}
        dragging={dragging}
        elevation={dragging ? 2.2 : 1}
      />

      {/* finger hint */}
      <div style={{
        position: 'absolute',
        left: pos.x, top: pos.y,
        transform: `translate(-50%, -50%) translate(28px, 28px)`,
        transition: dragging
          ? 'transform 0.5s cubic-bezier(0.22,1,0.36,1), left 0.5s cubic-bezier(0.22,1,0.36,1), top 0.5s cubic-bezier(0.22,1,0.36,1)'
          : 'transform 0.9s cubic-bezier(0.34, 1.3, 0.5, 1), left 0.9s cubic-bezier(0.34, 1.3, 0.5, 1), top 0.9s cubic-bezier(0.34, 1.3, 0.5, 1)',
        zIndex: 15,
        opacity: showHint && dragging ? 1 : 0,
        pointerEvents: 'none',
      }}>
        <div style={{
          width: 36, height: 36, borderRadius: '50%',
          background: 'rgba(255,255,255,0.9)',
          boxShadow: '0 0 0 6px rgba(255,255,255,0.2), 0 8px 24px rgba(0,0,0,0.4)',
        }} />
      </div>

      <ScreenCopy
        title={<>Move It Anywhere<br/>While Recording</>}
        subtitle="Drag. Release. Spring snaps it in place."
        visible={visible}
      />

      <BottomCTA
        label="Continue"
        onClick={onNext}
        visible={visible}
        dots={2}
      />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// SCREEN 4 — EXPORT & QUALITY
// Recording → progress → complete
// ─────────────────────────────────────────────────────────────
function ExportScreen({ active, onNext, floatPhase }) {
  const [visible, setVisible] = React.useState(false);
  const [stage, setStage] = React.useState(0);
  // 0: idle, 1: recording, 2: exporting, 3: done
  const [timer, setTimer] = React.useState(0);
  const [progress, setProgress] = React.useState(0);

  React.useEffect(() => {
    if (!active) {
      setVisible(false);
      setStage(0);
      setTimer(0);
      setProgress(0);
      return;
    }
    const tV = setTimeout(() => setVisible(true), 250);

    const run = () => {
      setStage(0);
      setTimer(0);
      setProgress(0);

      // record phase
      setTimeout(() => setStage(1), 800);
      const recTicks = [];
      for (let i = 1; i <= 24; i++) {
        recTicks.push(setTimeout(() => setTimer(i), 800 + i * 90));
      }
      // export phase
      setTimeout(() => setStage(2), 3100);
      const expTicks = [];
      for (let i = 0; i <= 100; i += 2) {
        expTicks.push(setTimeout(() => setProgress(i), 3100 + i * 12));
      }
      // done
      setTimeout(() => setStage(3), 4500);
    };
    run();
    const loop = setInterval(run, 8000);

    return () => { clearTimeout(tV); clearInterval(loop); };
  }, [active]);

  const mm = String(Math.floor(timer / 60)).padStart(2, '0');
  const ss = String(timer % 60).padStart(2, '0');
  const timerText = `${mm}:${ss}`;

  return (
    <div style={{ position: 'absolute', inset: 0, background: '#000', overflow: 'hidden' }}>
      <div style={{
        position: 'absolute', inset: 0,
        opacity: visible && stage < 3 ? 1 : stage >= 3 ? 0.3 : 0,
        transition: 'opacity 0.8s cubic-bezier(0.22,1,0.36,1)',
      }}>
        <RearCameraFeed variant="street" parallax={Math.sin(floatPhase * 0.3) * 4} />
      </div>

      <div style={{ opacity: visible && stage < 3 ? 1 : 0, transition: 'opacity 0.5s ease' }}>
        <CameraChrome recording={stage === 1} timerText={timerText} />
      </div>

      {/* front bubble — visible during record, fades on export */}
      <FrontCameraBubble
        shape="circle"
        x="72%"
        y="70%"
        scale={stage < 2 ? 1 : 0.6}
        opacity={visible ? (stage < 2 ? 1 : 0) : 0}
        floating={stage === 1}
        floatPhase={floatPhase}
      />

      {/* export / progress card */}
      <div style={{
        position: 'absolute', left: '50%', top: '44%',
        transform: `translate(-50%, -50%) scale(${stage >= 2 ? 1 : 0.8})`,
        opacity: stage >= 2 ? 1 : 0,
        transition: 'opacity 0.5s cubic-bezier(0.22,1,0.36,1), transform 0.6s cubic-bezier(0.34, 1.3, 0.5, 1)',
        width: 260,
        zIndex: 20,
      }}>
        <div style={{
          padding: 24,
          borderRadius: 28,
          background: 'rgba(20, 15, 10, 0.65)',
          backdropFilter: 'blur(30px) saturate(180%)',
          WebkitBackdropFilter: 'blur(30px) saturate(180%)',
          border: '0.5px solid rgba(255,255,255,0.12)',
          boxShadow: '0 20px 60px rgba(0,0,0,0.6), inset 0 0 0 0.5px rgba(255,255,255,0.08)',
        }}>
          {/* label */}
          <div style={{
            fontFamily: '-apple-system, system-ui',
            fontSize: 13, fontWeight: 500, color: MUTED,
            letterSpacing: 0.3, textTransform: 'uppercase',
            marginBottom: 8,
          }}>
            {stage === 3 ? 'Saved to Photos' : 'Exporting'}
          </div>
          {/* title */}
          <div style={{
            fontFamily: '-apple-system, system-ui',
            fontSize: 22, fontWeight: 700, color: TEXT,
            letterSpacing: -0.4,
            marginBottom: 16,
          }}>
            {stage === 3 ? 'Done.' : 'dual_clip_0421.mp4'}
          </div>

          {/* progress bar */}
          <div style={{
            height: 6, borderRadius: 3,
            background: 'rgba(255,255,255,0.08)',
            overflow: 'hidden', position: 'relative',
            marginBottom: 10,
          }}>
            <div style={{
              height: '100%',
              width: `${stage === 3 ? 100 : progress}%`,
              background: stage === 3
                ? `linear-gradient(90deg, ${ACCENT}, #ffd89c)`
                : `linear-gradient(90deg, ${ACCENT}, #ffd89c)`,
              borderRadius: 3,
              boxShadow: `0 0 12px ${ACCENT}`,
              transition: 'width 0.2s linear',
            }} />
          </div>

          {/* footer */}
          <div style={{
            display: 'flex', justifyContent: 'space-between',
            fontFamily: '-apple-system, "SF Mono", ui-monospace, monospace',
            fontSize: 12, color: MUTED,
          }}>
            <span>4K · 60fps · H.265</span>
            <span style={{ color: stage === 3 ? ACCENT : MUTED }}>
              {stage === 3 ? '✓ 24 MB' : `${progress}%`}
            </span>
          </div>
        </div>

        {/* success glow */}
        {stage === 3 && (
          <div style={{
            position: 'absolute', inset: -40,
            background: `radial-gradient(circle at 50% 50%, ${ACCENT_SOFT} 0%, transparent 60%)`,
            opacity: 0.8,
            pointerEvents: 'none',
            animation: 'successGlow 1.2s ease-out',
            zIndex: -1,
          }} />
        )}
      </div>

      {/* success check — appears briefly when done */}
      {stage === 3 && (
        <div style={{
          position: 'absolute', left: '50%', top: '22%',
          transform: 'translate(-50%, -50%)',
          width: 64, height: 64, borderRadius: '50%',
          background: ACCENT,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: `0 0 40px ${ACCENT_SOFT}, 0 0 0 8px rgba(255,180,100,0.1)`,
          animation: 'successPop 0.6s cubic-bezier(0.34, 1.6, 0.5, 1)',
          zIndex: 25,
        }}>
          <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
            <path d="M6 14l5 5 11-11" stroke="#1a120a" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </div>
      )}

      <ScreenCopy
        title={<>Fast Export.<br/>HD Quality.</>}
        subtitle="4K · 60fps · H.265. One tap to save or share."
        visible={visible}
      />

      <BottomCTA
        label="Get Started"
        onClick={onNext}
        visible={visible}
        dots={3}
      />
    </div>
  );
}

Object.assign(window, {
  HeroScreen, CustomizeScreen, DragScreen, ExportScreen,
});
