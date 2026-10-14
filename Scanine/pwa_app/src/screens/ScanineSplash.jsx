import { useEffect, useRef } from 'react';

export default function ScanineSplash({ onFinished }) {
  const containerRef = useRef(null);

  useEffect(() => {
    let t0 = null;
    let reqId;

    const PACE = .7;
    const MOTION = 2.45;
    const HOLD_A = MOTION / PACE;
    const HOLD_B = HOLD_A + .5;
    const T = HOLD_B + .35;

    const BASE = 440, CX = 195;
    const X = 38, WT = 8, R = (X - WT) / 2, CY = -X / 2;
    const START = .25, STAG = .075, DUR = .42, LAG = .065;
    const SWEEP_A = 1.2, SWEEP_B = 2.06, SLIT = 7;

    const root = containerRef.current;
    if (!root) return;

    const $ = (id) => root.querySelector('#' + id);
    const clamp = (x) => Math.min(1, Math.max(0, x));
    const seg = (x, a, b) => clamp((x - a) / (b - a));
    const lerp = (a, b, p) => a + (b - a) * p;
    const outCubic = (x) => 1 - Math.pow(1 - x, 3);
    const inOutCubic = (x) => x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
    const inOutSine = (x) => -(Math.cos(Math.PI * x) - 1) / 2;
    const bezier = (x1, y1, x2, y2) => {
      return (x) => {
        if (x <= 0) return 0;
        if (x >= 1) return 1;
        let lo = 0, hi = 1, t = x;
        for (let i = 0; i < 22; i++) {
          t = (lo + hi) / 2;
          if (3 * x1 * t * (1 - t) * (1 - t) + 3 * x2 * t * t * (1 - t) + t * t * t < x) lo = t; else hi = t;
        }
        return 3 * y1 * t * (1 - t) * (1 - t) + 3 * y2 * t * t * (1 - t) + t * t * t;
      };
    };
    const settle = bezier(.3, 0, .1, 1);
    const draw = (x) => .4 * inOutCubic(x) + .6 * outCubic(x);
    const softBack = (x) => { let u = x - 1; return 1 + 2 * u * u * u + u * u; };
    const n = (v) => (+v).toFixed(2);
    const rad = (deg) => deg * Math.PI / 180;
    const NS = 'http://www.w3.org/2000/svg';
    const el = (name, attrs, parent) => {
      const e = document.createElementNS(NS, name);
      for (const k in attrs) e.setAttribute(k, attrs[k]);
      parent.appendChild(e);
      return e;
    };

    function buildLogo(g) {
      const strokes = [];
      let dot = null, x = 0;
      const boxes = [];
      let parent = null;

      function stroke(d, t0, dur) {
        const els = ['e1', 'e2', 'e3'].map((e) => el('path', { d: d, 'class': 'ls ' + e }, parent));
        const len = els[0].getTotalLength();
        els.forEach((p) => { p.setAttribute('stroke-dasharray', n(len) + ' ' + n(len + 4)); });
        strokes.push({ els: els, len: len, t0: t0, dur: dur });
      }
      function stem(sx, t0) { stroke('M' + n(sx) + ' 0 V' + (-X), t0, DUR * .8); }
      function nLetter(t0) {
        const sx = x + WT / 2, ra = 10.5, yc = -X + WT / 2 + ra;
        stem(sx, t0);
        stroke('M' + n(sx) + ' ' + n(yc) + ' A' + ra + ' ' + ra + ' 0 0 1 ' + n(sx + 2 * ra) + ' ' + n(yc) + ' V0', t0 + .08, DUR);
        return [2 * ra + WT, 6];
      }
      const letters = [
        function (t0) {
          const rx = 10.5, ry = (X - WT) / 4, cx = x + WT / 2 + rx, cu = -X + WT / 2 + ry, cl = -WT / 2 - ry;
          stroke('M' + n(cx + rx * Math.cos(rad(28))) + ' ' + n(cu - ry * Math.sin(rad(28))) +
            ' A' + rx + ' ' + ry + ' 0 1 0 ' + n(cx) + ' ' + n(cu + ry) +
            ' A' + rx + ' ' + ry + ' 0 1 1 ' + n(cx + rx * Math.cos(rad(208))) + ' ' + n(cl - ry * Math.sin(rad(208))), t0, DUR * 1.1);
          return [2 * rx + WT, 4];
        },
        function (t0) {
          const cx = x + WT / 2 + R, a = rad(42);
          stroke('M' + n(cx + R * Math.cos(a)) + ' ' + n(CY - R * Math.sin(a)) + ' A' + R + ' ' + R + ' 0 1 0 ' +
            n(cx + R * Math.cos(a)) + ' ' + n(CY + R * Math.sin(a)), t0, DUR);
          return [WT / 2 + R + R * Math.cos(a) + 2.7, 3];
        },
        function (t0) {
          const cx = x + WT / 2 + R;
          stroke('M' + n(cx + R) + ' ' + CY + ' A' + R + ' ' + R + ' 0 1 0 ' + n(cx - R) + ' ' + CY +
            ' A' + R + ' ' + R + ' 0 1 0 ' + n(cx + R) + ' ' + CY, t0 + .08, DUR);
          stem(cx + R, t0);
          return [2 * R + WT, 6];
        },
        nLetter,
        function (t0) {
          stem(x + WT / 2, t0);
          dot = { el: el('circle', { r: 5, 'class': 'dot' }, parent), cx: x + WT / 2, cy: -X - 9, t0: t0 + .22, dur: .22 };
          return [WT, 6];
        },
        nLetter,
        function (t0) {
          const cx = x + WT / 2 + R, a = rad(40);
          stroke('M' + n(cx - R) + ' ' + CY + ' H' + n(cx + R) + ' A' + R + ' ' + R + ' 0 1 0 ' +
            n(cx + R * Math.cos(a)) + ' ' + n(CY + R * Math.sin(a)), t0, DUR * 1.1);
          return [2 * R + WT, 0];
        }
      ];
      letters.forEach((make, i) => {
        parent = el('g', {}, g);
        const m = make(i === 0 ? -9 : START + (i - 1) * STAG);
        boxes.push({ g: parent, x0: x });
        x += m[0] + m[1];
      });

      function set(time) {
        strokes.forEach((s) => {
          const solid = draw(seg(time, s.t0 + 2 * LAG, s.t0 + 2 * LAG + s.dur));
          s.els.forEach((p, j) => {
            const prog = j === 2 ? solid : draw(seg(time, s.t0 + j * LAG, s.t0 + j * LAG + s.dur));
            p.setAttribute('visibility', prog <= .001 || (j < 2 && solid >= 1) ? 'hidden' : 'visible');
            p.setAttribute('stroke-dashoffset', n(s.len * (1 - prog)));
          });
        });
        const sc = softBack(seg(time, dot.t0, dot.t0 + dot.dur));
        dot.el.setAttribute('transform', 'translate(' + n(dot.cx) + ' ' + n(dot.cy) + ') scale(' + (time < dot.t0 ? 0 : sc).toFixed(4) + ')');
      }
      return { width: x, set: set, boxes: boxes };
    }

    const logoG = $('logo');
    const logo = buildLogo(logoG);
    const boxes = logo.boxes;
    const WX = CX - logo.width / 2;
    const SHIFT = boxes[1].x0 / 2;
    const X_R = WX - SHIFT + logo.width + 4;
    const X_L = WX - 8;
    boxes[0].g.setAttribute('clip-path', 'url(#sClip)');

    function render(time) {
      const m = Math.min(time, HOLD_A) * PACE;
      logo.set(m);
      const sweep = settle(seg(m, SWEEP_A, SWEEP_B));
      const vx = lerp(X_R, X_L, sweep);
      const on = seg(m, SWEEP_A, SWEEP_A + .06) * (1 - seg(m, SWEEP_B - .08, SWEEP_B));
      const lx = WX - SHIFT * (1 - settle(seg(m, 1.68, 2.12)));
      
      logoG.setAttribute('transform', 'translate(' + n(lx) + ' ' + BASE + ')');
      $('sClipR').setAttribute('x', n(vx - lx));
      $('coreBar').setAttribute('x', n(vx - 1)); $('coreBar').setAttribute('opacity', n(on));
      $('shineBar').setAttribute('x', n(vx + SLIT - 2)); $('shineBar').setAttribute('opacity', n(.85 * on));

      const ta = outCubic(seg(m, 2.1, 2.45));
      const tag = $('tag');
      tag.setAttribute('opacity', n(ta));
      tag.setAttribute('transform', 'translate(0 ' + n((1 - ta) * 6) + ')');

      $('scene').setAttribute('opacity', n(1 - inOutSine(seg(time, HOLD_B, T))));
    }

    function done() {
      if (onFinished) onFinished();
    }

    const reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const from = reduce ? HOLD_A : 0;
    
    function frame(now) {
      if (t0 === null) t0 = now;
      const t = Math.min(T, from + (now - t0) / 1000);
      render(t);
      if (t < T) reqId = requestAnimationFrame(frame); else done();
    }
    
    render(from);
    reqId = requestAnimationFrame(frame);

    return () => {
      cancelAnimationFrame(reqId);
    };
  }, [onFinished]);

  return (
    <div ref={containerRef} style={{ width: '100%', height: '100%', overflow: 'hidden' }}>
      <style>{`
        .scanine-splash-bg {
          width: 100%;
          height: 100%;
          background: #EEF2F7 radial-gradient(ellipse 72% 72% at 50% 49%, #F8FAFD 0%, #EEF2F7 50%, #E2E8F2 100%);
        }
        .scanine-splash-svg {
          display: block; width: 100%; height: 100%;
          --ink: #193863; --ink-2: #5F708A; --ink-3: #CDD5E2;
          --scan: #DCE3EE; --shine: #8E9CB2;
        }
        .scanine-splash-svg .e1 { stroke: var(--ink-3); }
        .scanine-splash-svg .e2 { stroke: var(--ink-2); }
        .scanine-splash-svg .e3 { stroke: var(--ink); }
        .scanine-splash-svg .ls { fill: none; stroke-width: 8; }
        .scanine-splash-svg .dot { fill: var(--ink); }
        .scanine-splash-svg .shine { --ink: var(--shine); }
        .scanine-splash-svg .core { --ink: var(--scan); }
        .scanine-splash-svg .s0 { stop-color: #fff; stop-opacity: 0; }
        .scanine-splash-svg .s1 { stop-color: #fff; stop-opacity: 1; }
        .scanine-splash-svg .tag { font-family: "Outfit", "Inter", system-ui, -apple-system, sans-serif; font-weight: 500; font-size: 17.85px; letter-spacing: .03em; fill: #5F708A; }
        .scanine-splash-svg .tag .sep { fill-opacity: .55; }
      `}</style>
      <div className="scanine-splash-bg">
        <svg id="stage" className="scanine-splash-svg" viewBox="0 0 390 844" preserveAspectRatio="xMidYMid meet" role="img" aria-label="scanine. scan, screen, care.">
          <defs>
            <linearGradient id="shineGrad"><stop offset="0" className="s1"/><stop offset="1" className="s0"/></linearGradient>
            <mask id="shineMask" maskUnits="userSpaceOnUse" x="0" y="0" width="390" height="844"><rect id="shineBar" y="0" height="844" width="84" fill="url(#shineGrad)"/></mask>
            <linearGradient id="coreGrad"><stop offset="0" className="s0"/><stop offset=".35" className="s1"/><stop offset=".65" className="s1"/><stop offset="1" className="s0"/></linearGradient>
            <mask id="coreMask" maskUnits="userSpaceOnUse" x="0" y="0" width="390" height="844"><rect id="coreBar" y="0" height="844" width="7" fill="url(#coreGrad)"/></mask>
            <clipPath id="sClip"><rect id="sClipR" y="-120" height="240" width="600"/></clipPath>
          </defs>
          <g id="scene">
            <g id="logo"></g>
            {/* a grey copy of the lettering, seen only in the soft wake behind the scan line */}
            <g mask="url(#shineMask)"><use href="#logo" className="shine"/></g>
            {/* the scan line itself: a white copy of the lettering seen through a narrow slit */}
            <g mask="url(#coreMask)"><use href="#logo" className="core"/></g>
            <g id="tag" opacity="0"><text className="tag" x="195" y="481" textAnchor="middle">scan<tspan className="sep">&#160;+&#160;</tspan>screen<tspan className="sep">&#160;+&#160;</tspan>care</text></g>
          </g>
        </svg>
      </div>
    </div>
  );
}
