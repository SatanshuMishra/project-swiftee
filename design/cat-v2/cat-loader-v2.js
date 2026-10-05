/*
 * <cat-loader-v2 size="lg|sm" label="…" px="…" phase="0..1">
 * Rebuild of src/components/CatLoader: the cat from cat-icon.svg bent along the loader ring.
 * - Body + head are ONE path (ears, sides, flat rump) with a single outline -> no seams, no leaking outlines.
 * - Face, chest, paws and toe/tail lines use the icon's own geometry (0.8 scale), placed on the ring.
 * - Front features ride with the head, back paws + tail ride with the end of the body, the tummy stretches between.
 * - Choreography = CatLoader.css keyframes (2.74 s), smoothly interpolated.
 * - "sm" is a separate drawing tuned for the 80 px slot (heavier outline/whiskers, bigger eyes, no hairlines).
 */
(function () {
  const C = { dark: "#3B2F2F", cream: "#F5E5D4", belly: "#FBF0E6", eye: "#6FA8DC", pink: "#D4A0A0", line: "#EBE9E9" };
  const DUR = 2740;
  const RC = 90, HALF = 24;              // ring centreline + half body width (icon body 60 * 0.8 = 48)
  const K = 0.8;                         // icon units -> loader px
  const TH_EAR = -72, EAR_DIP = 4.6;     // front edge: ear tips at -72°, dip between them (icon: 9 units)
  const TH_DIP = TH_EAR + EAR_DIP;       // where icon y = 14 (the dip) lands
  const SPIN = { t: [0, .1, .2, .4, .5, .68, .9, 1], v: [0, -80, -180, -245, -250, -300, -560, -720], shift: -720 };
  const BODY = { t: [0, .1, .2, .4, .5, .65, .8, .9, 1], v: [180, 105.9, 38.7, -5.7, -5.7, 16.7, 72.6, 139.4, 180], shift: 0 };

  function spline({ t, v, shift }) {
    const n = t.length, T = [t[n - 2] - 1, ...t, t[1] + 1], V = [v[n - 2] - shift, ...v, v[1] + shift];
    const d = [], m = [];
    for (let k = 0; k < T.length - 1; k++) d.push((V[k + 1] - V[k]) / (T[k + 1] - T[k]));
    for (let k = 0; k < T.length; k++) m.push(k === 0 ? d[0] : k === T.length - 1 ? d[k - 1] : d[k - 1] * d[k] <= 0 ? 0 : (d[k - 1] + d[k]) / 2);
    for (let k = 0; k < d.length; k++) {
      if (d[k] === 0) { m[k] = 0; m[k + 1] = 0; continue; }
      const a = m[k] / d[k], b = m[k + 1] / d[k], s = a * a + b * b;
      if (s > 9) { const tau = 3 / Math.sqrt(s); m[k] = tau * a * d[k]; m[k + 1] = tau * b * d[k]; }
    }
    return (p) => {
      let k = 1; while (k < T.length - 2 && p > T[k + 1]) k++;
      const h = T[k + 1] - T[k], u = (p - T[k]) / h, u2 = u * u, u3 = u2 * u;
      return (2 * u3 - 3 * u2 + 1) * V[k] + (u3 - 2 * u2 + u) * h * m[k] + (-2 * u3 + 3 * u2) * V[k + 1] + (u3 - u2) * h * m[k + 1];
    };
  }
  const spin = spline(SPIN), bodyEnd = spline(BODY);

  const R2D = 180 / Math.PI;
  const f = (x) => (+x).toFixed(2);
  const pol = (r, a) => [120 + r * Math.cos(a / R2D), 120 + r * Math.sin(a / R2D)];
  const P = (r, a) => pol(r, a).map(f).join(" ");
  const arc = (r, a0, a1) => `M${P(r, a0)}A${r} ${r} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${P(r, a1)}`;
  const angY = (y) => TH_DIP + ((y - 14) * K / RC) * R2D;        // icon y on the head end -> ring angle
  const backA = (E, dy) => E + (dy * K / RC) * R2D;              // icon y relative to body end (141.5)
  // place an icon-space group so its centre-line sits on the ring at angle a; icon "down" = clockwise
  const place = (a, yA, s = K) => { const [x, y] = pol(RC, a); return `translate(${f(x)} ${f(y)}) rotate(${f(a)}) scale(${s}) translate(-43.5 ${-yA})`; };

  const front = (() => {
    let s = "";
    for (let i = 0; i <= 24; i++) {
      const r = RC + HALF - (2 * HALF * i) / 24, u = Math.abs(r - RC) / HALF;
      s += (i ? "L" : "M") + P(r, TH_EAR + EAR_DIP * Math.sin((Math.PI / 2) * (1 - u)));
    }
    return s;
  })();
  const silhouette = (E) => {
    const big = E - TH_EAR > 180 ? 1 : 0;
    return `${front}A${RC - HALF} ${RC - HALF} 0 ${big} 1 ${P(RC - HALF, E)}L${P(RC + HALF, E)}A${RC + HALF} ${RC + HALF} 0 ${big} 0 ${P(RC + HALF, TH_EAR)}Z`;
  };

  // icon geometry (cat-icon-v2.svg)
  const PAWS_FRONT = `<path d="M19.8 75H33.2V95C33.2 97.76 30.96 100 28.2 100H24.8C22.04 100 19.8 97.76 19.8 95V75Z"/><path d="M53.8 75H67.2V95C67.2 97.76 64.96 100 62.2 100H58.8C56.04 100 53.8 97.76 53.8 95V75Z"/>`;
  const PAWS_BACK = `<path d="M19.8 130H33.2V150C33.2 152.76 30.96 155 28.2 155H24.8C22.04 155 19.8 152.76 19.8 150V130Z"/><path d="M53.8 130H67.2V150C67.2 152.76 64.96 155 62.2 155H58.8C56.04 155 53.8 152.76 53.8 150V130Z"/>`;
  const V = {
    lg: {
      outline: 10,
      face: `<g stroke="${C.dark}" stroke-width="2" stroke-linecap="round"><path d="M68.5 31.5L92 23.5M68.5 35.5H93M68.5 39.5L92 47M18.5 31.5L-5 23.5M18.5 35.5H-6M18.5 39.5L-5 47"/></g>
        <circle cx="31" cy="32" r="3.5" fill="${C.eye}"/><circle cx="56" cy="32" r="3.5" fill="${C.eye}"/>
        <ellipse cx="43.5" cy="36" rx="8" ry="6" fill="${C.dark}"/>
        <circle cx="39.5" cy="41.5" r="3.5" stroke="${C.dark}" stroke-width="2" fill="none"/><circle cx="47.5" cy="41.5" r="3.5" stroke="${C.dark}" stroke-width="2" fill="none"/>`,
      toes: `<path d="M26.5 134V150M60.5 134V150" stroke="${C.line}" stroke-width="1.5" stroke-linecap="round"/>`,
      tailLine: true,
    },
    sm: {
      outline: 16,
      face: `<g stroke="${C.dark}" stroke-width="5" stroke-linecap="round"><path d="M70 31L84 26M70 39L84 43M17 31L3 26M17 39L3 43"/></g>
        <circle cx="30" cy="31" r="6" fill="${C.eye}"/><circle cx="57" cy="31" r="6" fill="${C.eye}"/>
        <ellipse cx="43.5" cy="38" rx="9.5" ry="7.5" fill="${C.dark}"/>`,
      toes: "",
      tailLine: false,
    },
  };

  let uid = 0;
  const markup = (v) => `
<svg viewBox="-30 -30 300 300" width="100%" height="100%" style="display:block;overflow:visible" aria-hidden="true">
  <g data-k="frame">
    <path data-k="sil" fill="${C.cream}" stroke="${C.dark}" stroke-width="${v.outline}" stroke-linejoin="miter" stroke-miterlimit="4" paint-order="stroke"/>
    <path data-k="tummy" fill="none" stroke="${C.belly}" stroke-width="${33 * K}" stroke-linecap="round"/>
    <circle cx="${f(pol(RC, angY(67))[0])}" cy="${f(pol(RC, angY(67))[1])}" r="${15 * K}" fill="${C.pink}"/>
    <g fill="${C.dark}" transform="${place(angY(87.5), 87.5)}">${PAWS_FRONT}</g>
    <g transform="${place(angY(36), 36)}">${v.face}</g>
    <g data-k="back"><g fill="${C.dark}">${PAWS_BACK}</g>${v.toes}</g>
    <path data-k="tail" fill="none" stroke="${C.dark}" stroke-width="${13 * K}" stroke-linecap="butt"/>
    <circle data-k="tip" r="${6.5 * K}" fill="${C.dark}"/>
    ${v.tailLine ? `<path data-k="tline" fill="none" stroke="${C.line}" stroke-width="${1.5 * K}" stroke-linecap="round"/>` : ""}
  </g>
</svg>`;

  class CatLoaderV2 extends HTMLElement {
    static get observedAttributes() { return ["size", "label", "px", "phase"]; }
    connectedCallback() {
      if (!this._built) this._build();
      this._t0 = performance.now();
      const loop = (now) => { this._frame(now); this._raf = requestAnimationFrame(loop); };
      this._raf = requestAnimationFrame(loop);
    }
    disconnectedCallback() { cancelAnimationFrame(this._raf); }
    attributeChangedCallback(name) {
      if (!this._built) return;
      if (name === "size") this._draw();
      this._layout(); this._frame(performance.now());
    }
    _build() {
      this._built = true; uid++;
      Object.assign(this.style, { display: "flex", flexDirection: "column", alignItems: "center", gap: "16px" });
      this.innerHTML = `<div data-k="box" style="display:flex;align-items:center;justify-content:center"><div data-k="art"></div></div><p data-k="label" style="margin:0;font-size:14px;line-height:20px;font-weight:500;color:var(--muted-foreground,#a1a1a1)"></p>`;
      this.$box = this.querySelector('[data-k="box"]'); this.$art = this.querySelector('[data-k="art"]'); this.$label = this.querySelector('[data-k="label"]');
      this._reduced = window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches;
      this._draw(); this._layout(); this._frame(performance.now());
    }
    _draw() {
      const v = this.getAttribute("size") === "sm" ? V.sm : V.lg;
      this.$art.innerHTML = markup(v);
      const q = (k) => this.$art.querySelector(`[data-k="${k}"]`);
      Object.assign(this, { $frame: q("frame"), $sil: q("sil"), $tummy: q("tummy"), $back: q("back"), $tail: q("tail"), $tip: q("tip"), $tline: q("tline") });
    }
    _layout() {
      const sm = this.getAttribute("size") === "sm", own = +this.getAttribute("px");
      const px = own || (sm ? 80 : 300);
      this.$art.style.width = this.$art.style.height = px + "px";
      this.$box.style.width = (own || sm ? px : 480) + "px";     // lg keeps CatLoader's 480x360 footprint
      this.$box.style.height = (own || sm ? px : 360) + "px";
      const label = this.getAttribute("label");
      this.$label.textContent = label || ""; this.$label.style.display = label ? "" : "none";
    }
    _frame(now) {
      const dur = this._reduced ? DUR * 2.5 : DUR, fixed = this.getAttribute("phase");
      const p = fixed != null && fixed !== "" ? (+fixed % 1) : ((((now - (this._t0 || now)) % dur) + dur) % dur) / dur;
      const S = spin(p), E = bodyEnd(p);
      this.$frame.setAttribute("transform", `rotate(${f(S)} 120 120)`);
      this.$sil.setAttribute("d", silhouette(E));
      const t0 = angY(67), t1 = backA(E, -17.5) - (16.5 * K / RC) * R2D;
      this.$tummy.setAttribute("d", t1 > t0 ? arc(RC, t0, t1) : `M${P(RC, t0)}Z`);
      this.$back.setAttribute("transform", place(backA(E, 1), 142.5));
      const tailEnd = backA(E, 174 - 141.5 - 6.5);
      this.$tail.setAttribute("d", arc(RC, backA(E, -1.5), tailEnd));
      const [tx, ty] = pol(RC, tailEnd); this.$tip.setAttribute("cx", f(tx)); this.$tip.setAttribute("cy", f(ty));
      if (this.$tline) this.$tline.setAttribute("d", arc(RC, backA(E, 3.5), backA(E, 27.5)));
    }
  }
  if (!customElements.get("cat-loader-v2")) customElements.define("cat-loader-v2", CatLoaderV2);
})();
