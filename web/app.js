"use strict";

(() => {
  const $ = (id) => document.getElementById(id);

  // Same defaults as Settings.swift in the app.
  const state = { armed: true, volume: 0.6, fireOnRepeat: false, fireOnModifiers: false, rounds: 0 };

  const MODIFIER_KEYS = new Set(["Shift", "Control", "Alt", "Meta", "CapsLock"]);

  const AudioCtx = window.AudioContext || window.webkitAudioContext;
  let ctx = null;
  let gain = null;
  let blast = null;
  let loading = null;

  function loadSound() {
    if (loading) return loading;
    if (!AudioCtx) return Promise.reject(new Error("Web Audio unavailable"));
    ctx = new AudioCtx();
    gain = ctx.createGain();
    gain.gain.value = state.volume;
    gain.connect(ctx.destination);
    loading = fetch("/shotgun.wav")
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.arrayBuffer();
      })
      .then((data) => new Promise((resolve, reject) => ctx.decodeAudioData(data, resolve, reject)))
      .then((buffer) => {
        blast = buffer;
        return buffer;
      });
    loading.catch(() => {
      $("audio-error").hidden = false;
    });
    return loading;
  }

  // A fresh source node per shot lets rapid shots overlap, like the app's
  // pool of eight players.
  function fire() {
    if (!ctx) return;
    if (ctx.state === "suspended") ctx.resume();
    if (!blast) return;
    const source = ctx.createBufferSource();
    source.buffer = blast;
    source.connect(gain);
    source.start();
    recoil();
    playhead(source);
  }

  const demo = $("demo");
  const icon = $("menubar-icon");

  function recoil() {
    state.rounds += 1;
    $("rounds").textContent = state.rounds;
    $("rounds-word").textContent = state.rounds === 1 ? "round" : "rounds";
    for (const el of [demo, icon]) {
      const cls = el === demo ? "is-recoil" : "is-firing";
      el.classList.remove(cls);
      void el.offsetWidth;
      el.classList.add(cls);
    }
  }

  // Menu

  function setPressed(button, on) {
    button.setAttribute("aria-pressed", String(on));
    button.querySelector(".menu__check").textContent = on ? "✓" : "";
  }

  function renderArmed() {
    const btn = $("toggle-armed");
    setPressed(btn, state.armed);
    $("toggle-armed-label").textContent = state.armed ? "🕊️ Ceasefire" : "🔫 Declare War";
    icon.textContent = state.armed ? "🔫" : "🕊️";
    icon.classList.toggle("is-dim", !state.armed);
  }

  $("toggle-armed").addEventListener("click", () => {
    loadSound().catch(() => {});
    state.armed = !state.armed;
    renderArmed();
    if (state.armed) fire();
  });

  $("test-fire").addEventListener("click", () => {
    loadSound().then(fire, () => {});
  });

  const volume = $("volume");
  volume.addEventListener("input", () => {
    state.volume = Number(volume.value) / 100;
    $("volume-value").textContent = `${volume.value}%`;
    if (gain) gain.gain.value = state.volume;
  });
  volume.addEventListener("change", () => {
    loadSound().then(fire, () => {});
  });

  $("toggle-repeat").addEventListener("click", (e) => {
    state.fireOnRepeat = !state.fireOnRepeat;
    setPressed(e.currentTarget, state.fireOnRepeat);
  });

  $("toggle-modifiers").addEventListener("click", (e) => {
    state.fireOnModifiers = !state.fireOnModifiers;
    setPressed(e.currentTarget, state.fireOnModifiers);
  });

  // Typing range: mirrors AppDelegate.handleTap.

  const field = $("range");
  field.addEventListener("focus", () => loadSound().catch(() => {}), { once: true });
  field.addEventListener("keydown", (e) => {
    loadSound().catch(() => {});
    if (!state.armed) return;
    if (MODIFIER_KEYS.has(e.key)) {
      if (state.fireOnModifiers && !e.repeat) fire();
      return;
    }
    if (e.repeat && !state.fireOnRepeat) return;
    fire();
  });

  // Waveform

  const canvas = $("wave");
  let peaks = null;
  let playStart = 0;
  let playing = false;

  function computePeaks(buffer, columns) {
    const data = buffer.getChannelData(0);
    const step = Math.max(1, Math.floor(data.length / columns));
    const out = new Float32Array(columns * 2);
    for (let c = 0; c < columns; c++) {
      let min = 1;
      let max = -1;
      const end = Math.min(data.length, (c + 1) * step);
      for (let i = c * step; i < end; i++) {
        const v = data[i];
        if (v < min) min = v;
        if (v > max) max = v;
      }
      out[c * 2] = min;
      out[c * 2 + 1] = max;
    }
    return out;
  }

  function drawWave(progress) {
    if (!blast) return;
    const dpr = window.devicePixelRatio || 1;
    const width = canvas.clientWidth;
    const height = canvas.clientHeight;
    if (!width) return;
    if (canvas.width !== Math.round(width * dpr)) {
      canvas.width = Math.round(width * dpr);
      canvas.height = Math.round(height * dpr);
      peaks = null;
    }
    const g = canvas.getContext("2d");
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, width, height);

    const columns = Math.floor(width / 2);
    if (!peaks || peaks.length !== columns * 2) peaks = computePeaks(blast, columns);

    const mid = height / 2;
    g.fillStyle = "#cfc8ba";
    g.fillRect(0, mid, width, 1);

    const cut = progress == null ? -1 : progress * columns;
    for (let c = 0; c < columns; c++) {
      const top = mid - peaks[c * 2 + 1] * (mid - 4);
      const bottom = mid - peaks[c * 2] * (mid - 4);
      g.fillStyle = c <= cut ? "#d9481c" : "#171512";
      g.fillRect(c * 2, top, 1.25, Math.max(1, bottom - top));
    }
  }

  function playhead() {
    if (playing) {
      playStart = ctx.currentTime;
      return;
    }
    playing = true;
    playStart = ctx.currentTime;
    const tick = () => {
      const p = (ctx.currentTime - playStart) / blast.duration;
      if (p >= 1) {
        playing = false;
        drawWave(null);
        return;
      }
      drawWave(p);
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }

  $("wave-play").addEventListener("click", () => {
    loadSound().then(fire, () => {});
  });

  let resizeTimer = 0;
  window.addEventListener("resize", () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => drawWave(null), 100);
  });

  // Decoding doesn't need a user gesture, only playback does, so draw the
  // waveform as soon as the file arrives.
  loadSound().then(() => drawWave(null), () => {});

  // Copy buttons

  for (const button of document.querySelectorAll(".copy")) {
    button.addEventListener("click", () => {
      const text = button.parentElement.querySelector("code").textContent;
      navigator.clipboard.writeText(text).then(
        () => {
          button.textContent = "Copied";
          setTimeout(() => { button.textContent = "Copy"; }, 1500);
        },
        () => {
          button.textContent = "Select & copy";
        },
      );
    });
  }

  renderArmed();
})();
