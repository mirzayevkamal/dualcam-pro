// Onboarding screens for Double Camera Pro
// All screens share a dark cinematic base with warm amber accent

const ACCENT = 'oklch(0.78 0.14 70)';
const ACCENT_SOFT = 'oklch(0.78 0.14 70 / 0.15)';
const BG = '#0a0908';
const TEXT = '#f5efe6';
const MUTED = 'rgba(245, 239, 230, 0.55)';

// ─────────────────────────────────────────────────────────────
// Simulated rear camera feed — a gradient-mesh "scene"
// Parallax moves the gradient a little as the phone moves
// ─────────────────────────────────────────────────────────────
function RearCameraFeed({ parallax = 0, variant = 'street' }) {
  const scenes = {
    street: {
      bg: 'radial-gradient(120% 80% at 30% 20%, #3a2418 0%, #1a0f09 40%, #050301 100%)',
      blobs: [
        { x: '20%', y: '30%', size: 280, color: 'rgba(255, 168, 89, 0.45)', blur: 80 },
        { x: '75%', y: '65%', size: 340, color: 'rgba(214, 92, 43, 0.35)', blur: 100 },
        { x: '55%', y: '15%', size: 180, color: 'rgba(255, 220, 150, 0.28)', blur: 60 },
      ],
    },
    studio: {
      bg: 'radial-gradient(100% 100% at 50% 40%, #2a1f18 0%, #120a05 50%, #000 100%)',
      blobs: [
        { x: '50%', y: '35%', size: 400, color: 'rgba(255, 200, 140, 0.35)', blur: 120 },
        { x: '20%', y: '80%', size: 220, color: 'rgba(180, 70, 40, 0.3)', blur: 80 },
      ],
    },
    night: {
      bg: 'radial-gradient(130% 90% at 70% 30%, #1a2438 0%, #0a0f1c 50%, #000 100%)',
      blobs: [
        { x: '70%', y: '25%', size: 300, color: 'rgba(120, 160, 255, 0.25)', blur: 100 },
        { x: '25%', y: '70%', size: 260, color: 'rgba(255, 140, 90, 0.3)', blur: 90 },
      ],
    },
  };

  const scene = scenes[variant] || scenes.street;

  return (
    <div style={{
      position: 'absolute', inset: 0, overflow: 'hidden',
      background: scene.bg,
      transform: `scale(1.08) translate(${parallax * -0.3}px, ${parallax * -0.2}px)`,
      transition: 'transform 0.8s cubic-bezier(0.22, 1, 0.36, 1)',
    }}>
      {scene.blobs.map((b, i) => (
        <div key={i} style={{
          position: 'absolute',
          left: b.x, top: b.y,
          width: b.size, height: b.size,
          borderRadius: '50%',
          background: b.color,
          filter: `blur(${b.blur}px)`,
          transform: 'translate(-50%, -50%)',
        }} />
      ))}
      {/* subtle grain */}
      <div style={{
        position: 'absolute', inset: 0,
        backgroundImage: `url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='200' height='200'><filter id='n'><feTurbulence baseFrequency='0.9' numOctaves='2'/></filter><rect width='200' height='200' filter='url(%23n)' opacity='0.4'/></svg>")`,
        opacity: 0.15,
        mixBlendMode: 'overlay',
      }} />
      {/* vignette */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'radial-gradient(100% 100% at 50% 50%, transparent 40%, rgba(0,0,0,0.5) 100%)',
      }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Front camera bubble — supports shape morphing
// ─────────────────────────────────────────────────────────────
function FrontCameraBubble({
  shape = 'circle', // circle | square | rectangle | pill
  x = '70%', y = '75%',
  scale = 1, opacity = 1,
  width, height, borderRadius,
  floating = false, floatPhase = 0,
  dragging = false,
  elevation = 1,
}) {
  const shapes = {
    circle: { w: 110, h: 110, r: 55 },
    square: { w: 120, h: 120, r: 22 },
    rectangle: { w: 100, h: 140, r: 20 },
    pill: { w: 130, h: 90, r: 45 },
  };
  const s = shapes[shape];
  const w = width ?? s.w;
  const h = height ?? s.h;
  const r = borderRadius ?? s.r;

  const floatY = floating ? Math.sin(floatPhase) * 4 : 0;
  const floatX = floating ? Math.cos(floatPhase * 0.7) * 2 : 0;

  return (
    <div style={{
      position: 'absolute', left: x, top: y,
      width: w, height: h,
      transform: `translate(-50%, -50%) scale(${scale}) translate(${floatX}px, ${floatY}px) ${dragging ? 'scale(1.05)' : ''}`,
      opacity,
      transition: dragging
        ? 'none'
        : 'width 0.7s cubic-bezier(0.34, 1.3, 0.5, 1), height 0.7s cubic-bezier(0.34, 1.3, 0.5, 1), border-radius 0.7s cubic-bezier(0.34, 1.3, 0.5, 1), left 0.9s cubic-bezier(0.34, 1.3, 0.5, 1), top 0.9s cubic-bezier(0.34, 1.3, 0.5, 1), opacity 0.6s ease, transform 0.6s cubic-bezier(0.34, 1.3, 0.5, 1)',
      zIndex: 10,
    }}>
      <div style={{
        width: '100%', height: '100%',
        borderRadius: r,
        overflow: 'hidden',
        background: 'radial-gradient(120% 110% at 40% 30%, #4a3a2e 0%, #1f1510 60%, #0a0605 100%)',
        boxShadow: `
          0 ${12 * elevation}px ${40 * elevation}px rgba(0,0,0,0.55),
          0 ${4 * elevation}px ${12 * elevation}px rgba(0,0,0,0.45),
          0 0 0 1.5px rgba(255,255,255,0.12) inset,
          0 0 0 0.5px rgba(255,255,255,0.25)
        `,
        transition: 'border-radius 0.7s cubic-bezier(0.34, 1.3, 0.5, 1)',
        position: 'relative',
      }}>
        {/* simulated face/selfie — warm gradient blob */}
        <div style={{
          position: 'absolute', inset: 0,
          background: 'radial-gradient(60% 55% at 50% 55%, rgba(255, 190, 140, 0.7) 0%, rgba(210, 130, 80, 0.4) 40%, transparent 75%)',
        }} />
        <div style={{
          position: 'absolute', left: '50%', top: '40%',
          width: '40%', height: '45%',
          transform: 'translate(-50%, -50%)',
          borderRadius: '50%',
          background: 'radial-gradient(circle at 45% 40%, rgba(255, 210, 170, 0.9), rgba(180, 110, 70, 0.3) 70%, transparent)',
        }} />
        {/* highlight */}
        <div style={{
          position: 'absolute', inset: 0,
          background: 'linear-gradient(135deg, rgba(255,255,255,0.15) 0%, transparent 40%)',
          borderRadius: 'inherit',
        }} />
        {/* grain */}
        <div style={{
          position: 'absolute', inset: 0,
          backgroundImage: `url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'><filter id='n'><feTurbulence baseFrequency='1.2' numOctaves='1'/></filter><rect width='100' height='100' filter='url(%23n)' opacity='0.5'/></svg>")`,
          opacity: 0.2,
          mixBlendMode: 'overlay',
        }} />
      </div>
      {/* LIVE dot */}
      {!dragging && (
        <div style={{
          position: 'absolute', top: 10, right: 10,
          width: 6, height: 6, borderRadius: '50%',
          background: '#ff3b30',
          boxShadow: '0 0 8px rgba(255, 59, 48, 0.8)',
          animation: 'livePulse 1.8s ease-in-out infinite',
        }} />
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Camera chrome (top controls + record button)
// ─────────────────────────────────────────────────────────────
function CameraChrome({ recording = false, progress = 0, showTimer = false, timerText = '00:00' }) {
  return (
    <>
      {/* top chrome */}
      <div style={{
        position: 'absolute', top: 52, left: 0, right: 0,
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        padding: '0 20px', zIndex: 30,
      }}>
        <div style={{
          padding: '6px 12px', borderRadius: 20,
          background: 'rgba(0,0,0,0.4)', backdropFilter: 'blur(20px)',
          WebkitBackdropFilter: 'blur(20px)',
          fontSize: 13, fontWeight: 600, color: '#fff',
          fontFamily: '-apple-system, system-ui',
          display: 'flex', alignItems: 'center', gap: 6,
          border: '0.5px solid rgba(255,255,255,0.15)',
        }}>
          <span style={{ fontSize: 10 }}>4K</span>
          <span style={{ opacity: 0.5 }}>·</span>
          <span>60</span>
        </div>
        {recording && (
          <div style={{
            padding: '6px 12px', borderRadius: 20,
            background: 'rgba(255, 59, 48, 0.22)',
            backdropFilter: 'blur(20px)',
            WebkitBackdropFilter: 'blur(20px)',
            fontSize: 13, fontWeight: 600, color: '#ff5c4f',
            fontFamily: '-apple-system, system-ui',
            display: 'flex', alignItems: 'center', gap: 6,
            border: '0.5px solid rgba(255, 59, 48, 0.4)',
          }}>
            <div style={{
              width: 8, height: 8, borderRadius: '50%',
              background: '#ff3b30',
              animation: 'livePulse 1.2s ease-in-out infinite',
            }} />
            <span>REC {timerText}</span>
          </div>
        )}
      </div>

      {/* progress bar at top */}
      {progress > 0 && (
        <div style={{
          position: 'absolute', top: 0, left: 0,
          height: 3, width: `${progress}%`,
          background: `linear-gradient(90deg, ${ACCENT}, #ffd89c)`,
          boxShadow: `0 0 12px ${ACCENT}`,
          zIndex: 40,
          transition: 'width 0.3s linear',
        }} />
      )}
    </>
  );
}

// ─────────────────────────────────────────────────────────────
// Screen title + subtitle with stagger animation
// ─────────────────────────────────────────────────────────────
function ScreenCopy({ title, subtitle, visible = true, delay = 0 }) {
  return (
    <div style={{
      position: 'absolute', bottom: 180, left: 0, right: 0,
      padding: '0 32px',
      zIndex: 20,
      textAlign: 'center',
      pointerEvents: 'none',
    }}>
      <div style={{
        fontFamily: '-apple-system, system-ui',
        fontSize: 30, fontWeight: 700, lineHeight: 1.12,
        letterSpacing: -0.8,
        color: TEXT,
        textWrap: 'balance',
        opacity: visible ? 1 : 0,
        transform: visible ? 'translateY(0)' : 'translateY(16px)',
        transition: `opacity 0.7s cubic-bezier(0.22,1,0.36,1) ${delay}ms, transform 0.7s cubic-bezier(0.22,1,0.36,1) ${delay}ms`,
        textShadow: '0 2px 20px rgba(0,0,0,0.5)',
      }}>
        {title}
      </div>
      {subtitle && (
        <div style={{
          marginTop: 10,
          fontFamily: '-apple-system, system-ui',
          fontSize: 15, fontWeight: 400, lineHeight: 1.4,
          color: MUTED, letterSpacing: -0.1,
          opacity: visible ? 1 : 0,
          transform: visible ? 'translateY(0)' : 'translateY(16px)',
          transition: `opacity 0.7s cubic-bezier(0.22,1,0.36,1) ${delay + 120}ms, transform 0.7s cubic-bezier(0.22,1,0.36,1) ${delay + 120}ms`,
          textShadow: '0 1px 10px rgba(0,0,0,0.5)',
        }}>
          {subtitle}
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Bottom CTA — Continue / Get Started
// ─────────────────────────────────────────────────────────────
function BottomCTA({ label = 'Continue', onClick, visible = true, variant = 'primary', dots, totalDots = 4 }) {
  return (
    <div style={{
      position: 'absolute', bottom: 44, left: 0, right: 0,
      padding: '0 24px',
      zIndex: 30,
      opacity: visible ? 1 : 0,
      transform: visible ? 'translateY(0)' : 'translateY(20px)',
      transition: 'opacity 0.6s cubic-bezier(0.22,1,0.36,1) 300ms, transform 0.6s cubic-bezier(0.22,1,0.36,1) 300ms',
    }}>
      {/* page dots */}
      {dots !== undefined && (
        <div style={{
          display: 'flex', justifyContent: 'center', gap: 6,
          marginBottom: 20,
        }}>
          {Array.from({ length: totalDots }).map((_, i) => (
            <div key={i} style={{
              width: i === dots ? 18 : 6,
              height: 6, borderRadius: 3,
              background: i === dots ? ACCENT : 'rgba(255,255,255,0.25)',
              transition: 'width 0.4s cubic-bezier(0.34, 1.3, 0.5, 1), background 0.4s ease',
            }} />
          ))}
        </div>
      )}
      <button
        onClick={onClick}
        style={{
          width: '100%', height: 54,
          borderRadius: 18,
          border: 'none', cursor: 'pointer',
          background: variant === 'primary'
            ? `linear-gradient(180deg, ${ACCENT} 0%, oklch(0.72 0.14 60) 100%)`
            : 'rgba(255,255,255,0.1)',
          backdropFilter: variant !== 'primary' ? 'blur(20px)' : undefined,
          WebkitBackdropFilter: variant !== 'primary' ? 'blur(20px)' : undefined,
          color: variant === 'primary' ? '#1a120a' : TEXT,
          fontFamily: '-apple-system, system-ui',
          fontSize: 17, fontWeight: 600, letterSpacing: -0.2,
          boxShadow: variant === 'primary'
            ? `0 8px 24px ${ACCENT_SOFT}, 0 2px 6px rgba(0,0,0,0.3), 0 0 0 0.5px rgba(255,255,255,0.2) inset`
            : '0 0 0 0.5px rgba(255,255,255,0.15) inset',
          transition: 'transform 0.15s ease',
        }}
        onMouseDown={(e) => e.currentTarget.style.transform = 'scale(0.97)'}
        onMouseUp={(e) => e.currentTarget.style.transform = 'scale(1)'}
        onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}
      >
        {label}
      </button>
    </div>
  );
}

Object.assign(window, {
  ACCENT, ACCENT_SOFT, BG, TEXT, MUTED,
  RearCameraFeed, FrontCameraBubble, CameraChrome, ScreenCopy, BottomCTA,
});
