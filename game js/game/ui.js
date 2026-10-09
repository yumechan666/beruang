import assetsManifest from "../assets.json";
import { AREA_DATA, SKINS } from "./data.js";

function drawContained(ctx, image, frame, width, height) {
  if (!image || !frame) return;
  const crop = frame.content || frame.source;
  const scale = Math.min(width / crop.w, height / crop.h) * 0.88;
  const drawW = crop.w * scale;
  const drawH = crop.h * scale;
  ctx.drawImage(image, crop.x, crop.y, crop.w, crop.h, (width - drawW) / 2, height - drawH, drawW, drawH);
}

export function createUI(mount, assets) {
  const shell = document.createElement("section");
  shell.className = "ursa-shell";
  shell.innerHTML = `
    <header class="hud-row ursa-hud">
      <div class="hud-cluster">
        <button class="hud-menu-btn" type="button" aria-label="Buka menu">☰</button>
        <canvas class="stance-icon" width="44" height="44" aria-hidden="true"></canvas>
        <div class="hud-copy"><strong class="area-label">1 · MUSIM SEMI</strong><span class="stance-label">MERANGKAK</span></div>
      </div>
      <div class="hud-cluster hud-center">
        <span class="chance-label">3×</span>
        <div class="pip-row" aria-label="Tiga kesempatan"></div>
        <span class="food-badge">● 0</span>
        <span class="claw-badge">≋ 0/20</span>
      </div>
      <div class="meter-wrap" hidden><span class="meter-label">DINGIN</span><i class="meter-track"><b class="meter-fill"></b></i></div>
    </header>
    <div class="playfield">
      <canvas class="game-canvas" aria-label="Permainan platformer URSA"></canvas>
      <div class="chapter-toast" aria-live="polite"></div>
      <div class="game-overlay" hidden>
        <div class="overlay-panel">
          <p class="overlay-kicker">SIKLUS LENGKAP</p>
          <h2>Dua tahun liar terlewati.</h2>
          <p class="overlay-result"></p>
          <button class="overlay-button control-btn" type="button"><span class="control-label">Mulai tahun baru</span></button>
        </div>
      </div>
    </div>
    <footer class="controls-row ursa-controls">
      <div class="move-controls">
        <button class="control-btn move-btn" data-control="left" type="button" aria-label="Bergerak ke kiri"><span class="control-label">◀</span></button>
        <button class="control-btn move-btn" data-control="right" type="button" aria-label="Bergerak ke kanan"><span class="control-label">▶</span></button>
      </div>
      <div class="action-controls">
        <button class="control-btn action-btn" data-control="jump" type="button"><span class="control-label">LOMPAT</span></button>
        <button class="control-btn shift-btn" data-control="shift" type="button"><span class="control-label">SHIFT</span></button>
        <button class="control-btn action-btn" data-control="action" type="button"><span class="control-label">CAKAR</span></button>
      </div>
    </footer>
    <div class="start-menu" hidden>
      <div class="menu-backdrop" aria-hidden="true"></div>
      <div class="menu-panel">
        <header class="menu-brand">
          <p>20 AREA · 3 SKIN · 3 KESEMPATAN</p>
          <h1>URSA</h1>
          <span>Satu Tahun Liar</span>
        </header>
        <nav class="menu-tabs" aria-label="Pilihan permainan">
          <button class="menu-tab active" data-menu-tab="levels" type="button">LEVEL</button>
          <button class="menu-tab" data-menu-tab="skins" type="button">SKIN</button>
        </nav>
        <section class="menu-pane level-pane" data-menu-pane="levels">
          <div class="level-grid" aria-label="Pilih level"></div>
        </section>
        <section class="menu-pane skin-pane" data-menu-pane="skins" hidden>
          <div class="skin-grid" aria-label="Pilih skin"></div>
        </section>
        <footer class="menu-footer">
           <div class="menu-selection"><strong class="selected-level"></strong><span class="selected-skin"></span><span class="menu-coins"></span></div>
          <button class="menu-start control-btn" type="button"><span class="control-label">MULAI</span></button>
        </footer>
      </div>
    </div>
  `;
  mount.replaceChildren(shell);

  const controls = {};
  shell.querySelectorAll("[data-control]").forEach((button) => {
    controls[button.dataset.control] = button;
  });

  const elements = {
    shell,
    canvas: shell.querySelector(".game-canvas"),
    stanceCanvas: shell.querySelector(".stance-icon"),
    area: shell.querySelector(".area-label"),
    stance: shell.querySelector(".stance-label"),
    chance: shell.querySelector(".chance-label"),
    pips: shell.querySelector(".pip-row"),
    food: shell.querySelector(".food-badge"),
    claw: shell.querySelector(".claw-badge"),
    meter: shell.querySelector(".meter-wrap"),
    meterLabel: shell.querySelector(".meter-label"),
    meterFill: shell.querySelector(".meter-fill"),
    toast: shell.querySelector(".chapter-toast"),
    overlay: shell.querySelector(".game-overlay"),
    overlayResult: shell.querySelector(".overlay-result"),
    overlayButton: shell.querySelector(".overlay-button"),
    actionButton: controls.action,
    menuButton: shell.querySelector(".hud-menu-btn"),
    menu: shell.querySelector(".start-menu"),
    menuBackdrop: shell.querySelector(".menu-backdrop"),
    levelGrid: shell.querySelector(".level-grid"),
    skinGrid: shell.querySelector(".skin-grid"),
    selectedLevel: shell.querySelector(".selected-level"),
    selectedSkin: shell.querySelector(".selected-skin"),
    menuCoins: shell.querySelector(".menu-coins"),
    menuStart: shell.querySelector(".menu-start"),
  };

  AREA_DATA.forEach((level, index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "level-choice";
    button.dataset.level = String(index);
    const url = assets?.get(level.bg) || assetsManifest[level.bg];
    button.style.backgroundImage = `linear-gradient(rgba(8,16,13,.12), rgba(8,16,13,.72)), url("${url}")`;
     button.innerHTML = `<strong>${String(index + 1).padStart(2, "0")}</strong><span>${level.name}</span><i class="level-lock" aria-hidden="true">🔒</i>`;
    elements.levelGrid.append(button);
  });

  SKINS.forEach((skin) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "skin-choice";
    button.dataset.skin = skin.id;
    button.style.setProperty("--skin-swatch", skin.swatch);
     button.innerHTML = `<canvas aria-hidden="true"></canvas><strong>${skin.name}</strong><span>${skin.description}</span><i class="skin-status"></i>`;
    elements.skinGrid.append(button);
  });

  let selectedArea = 0;
  let selectedSkin = "brown";
  let highestArea = 0;
  let ownedSkins = new Set(["brown"]);
  let startCallback = () => {};
  let purchaseCallback = () => false;
  let menuCallback = () => {};
  let previewStore;
  let previewFrameId = 0;

  function setTab(name) {
    shell.querySelectorAll("[data-menu-tab]").forEach((button) => button.classList.toggle("active", button.dataset.menuTab === name));
    shell.querySelectorAll("[data-menu-pane]").forEach((pane) => {
      pane.hidden = pane.dataset.menuPane !== name;
    });
  }

  shell.querySelectorAll("[data-menu-tab]").forEach((button) => {
    button.addEventListener("click", () => setTab(button.dataset.menuTab));
  });

  function refreshSelection() {
    elements.levelGrid.querySelectorAll(".level-choice").forEach((button) => {
      const locked = Number(button.dataset.level) > highestArea;
      button.disabled = locked;
      button.classList.toggle("locked", locked);
      button.classList.toggle("selected", Number(button.dataset.level) === selectedArea);
    });
    elements.skinGrid.querySelectorAll(".skin-choice").forEach((button) => {
      const skin = SKINS.find((item) => item.id === button.dataset.skin) || SKINS[0];
      const owned = ownedSkins.has(skin.id);
      button.classList.toggle("selected", skin.id === selectedSkin);
      button.classList.toggle("locked-skin", !owned);
      button.querySelector(".skin-status").textContent = owned
        ? (skin.price > 0 ? "DIMILIKI" : "GRATIS")
        : `BELI · ${skin.price} KOIN`;
    });
    elements.selectedLevel.textContent = `${String(selectedArea + 1).padStart(2, "0")} · ${AREA_DATA[selectedArea].name}`;
    elements.selectedSkin.textContent = SKINS.find((skin) => skin.id === selectedSkin)?.name || SKINS[0].name;
    const url = assets?.get(AREA_DATA[selectedArea].bg) || assetsManifest[AREA_DATA[selectedArea].bg];
    elements.menuBackdrop.style.backgroundImage = `linear-gradient(rgba(8,16,13,.28), rgba(8,16,13,.80)), url("${url}")`;
  }

  elements.levelGrid.addEventListener("click", (event) => {
    const button = event.target.closest(".level-choice");
    if (!button) return;
    selectedArea = Number(button.dataset.level);
    refreshSelection();
  });

  elements.skinGrid.addEventListener("click", (event) => {
    const button = event.target.closest(".skin-choice");
    if (!button) return;
    const skinId = button.dataset.skin;
    if (!ownedSkins.has(skinId)) {
      if (!purchaseCallback(skinId)) return;
      ownedSkins.add(skinId);
    }
    selectedSkin = skinId;
    refreshSelection();
  });

  elements.menuStart.addEventListener("click", () => {
    if (selectedArea > highestArea) {
      toast("Selesaikan area sebelumnya dulu.");
      return;
    }
    if (!ownedSkins.has(selectedSkin)) {
      toast("Beli skin ini dengan koin terlebih dahulu.");
      return;
    }
    elements.menu.hidden = true;
    startCallback(selectedArea, selectedSkin);
  });

  elements.menuButton.addEventListener("click", () => menuCallback());

  function renderPips(health) {
    elements.chance.textContent = `${health}×`;
    elements.pips.replaceChildren();
    for (let index = 0; index < 3; index += 1) {
      const pip = document.createElement("i");
      pip.className = `pip paw-pip${index >= health ? " empty" : ""}`;
      elements.pips.append(pip);
    }
  }

  function update(state) {
    elements.area.textContent = `${state.areaIndex + 1} · ${state.level.season}`;
    elements.stance.textContent = state.player.mode === "biped" ? "BERDIRI" : "MERANGKAK";
    elements.food.textContent = `◉ ${state.totalFood}`;
    elements.menuCoins.textContent = `KOIN ${state.totalFood}`;
    elements.claw.textContent = `≋ ${state.collectedClaws.size}/20`;
    elements.actionButton.querySelector(".control-label").textContent = state.player.mode === "biped" ? "CAKAR" : state.areaIndex >= 8 ? "ENDUS" : "TACKLE";
    renderPips(state.player.health);

    if (state.level.noise) {
      elements.meter.hidden = false;
      elements.meterLabel.textContent = "BISING";
      elements.meterFill.style.width = `${Math.max(0, Math.min(100, state.noise))}%`;
    } else if (state.level.heat) {
      elements.meter.hidden = false;
      elements.meterLabel.textContent = "PANAS";
      elements.meterFill.style.width = `${Math.max(0, Math.min(100, state.heat))}%`;
    } else if (state.level.cold) {
      elements.meter.hidden = false;
      elements.meterLabel.textContent = "HANGAT";
      elements.meterFill.style.width = `${Math.max(0, Math.min(100, state.cold))}%`;
    } else if (state.areaIndex === 7) {
      elements.meter.hidden = false;
      elements.meterLabel.textContent = "LEMAK";
      elements.meterFill.style.width = `${Math.max(0, Math.min(100, state.fat))}%`;
    } else if (state.buffTimer > 0) {
      elements.meter.hidden = false;
      elements.meterLabel.textContent = "TENAGA";
      elements.meterFill.style.width = `${Math.min(100, state.buffTimer * 12.5)}%`;
    } else {
      elements.meter.hidden = true;
    }
  }

  function animateSkinPreviews(now) {
    if (previewStore) {
      const frameIndex = Math.floor(now / 180) % 5;
      elements.skinGrid.querySelectorAll(".skin-choice").forEach((button) => {
        const skin = SKINS.find((item) => item.id === button.dataset.skin) || SKINS[0];
        const canvas = button.querySelector("canvas");
        const rect = canvas.getBoundingClientRect();
        if (!rect.width || !rect.height) return;
        const dpr = Math.min(window.devicePixelRatio || 1, 2);
        canvas.width = Math.round(rect.width * dpr);
        canvas.height = Math.round(rect.height * dpr);
        const context = canvas.getContext("2d");
        context.setTransform(dpr, 0, 0, dpr, 0, 0);
        context.clearRect(0, 0, rect.width, rect.height);
        const key = skin.sheets.URSA_BIPED_CORE;
        const animation = previewStore.animation(key, "biped_idle");
        drawContained(context, previewStore.image(key), animation?.frames?.[frameIndex], rect.width, rect.height);
      });
    }
    previewFrameId = requestAnimationFrame(animateSkinPreviews);
  }
  previewFrameId = requestAnimationFrame(animateSkinPreviews);

  let toastTimer;
  function toast(text, duration = 2400) {
    elements.toast.textContent = text;
    elements.toast.classList.add("visible");
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => elements.toast.classList.remove("visible"), duration);
  }

  return {
    elements,
    controls,
    update,
    toast,
    setPreviewStore(store) {
      previewStore = store;
    },
    onMenu(callback) {
      menuCallback = callback;
    },
    showMenu({ areaIndex = 0, skinId = "brown", highestArea: unlockedArea = 0, purchasedSkins = [], onStart, onPurchase }) {
      highestArea = Math.max(0, Math.min(AREA_DATA.length - 1, unlockedArea));
      ownedSkins = new Set(["brown", ...purchasedSkins]);
      selectedArea = Math.max(0, Math.min(highestArea, areaIndex));
      selectedSkin = ownedSkins.has(skinId) && SKINS.some((skin) => skin.id === skinId) ? skinId : "brown";
      startCallback = onStart;
      purchaseCallback = onPurchase || (() => false);
      setTab("levels");
      refreshSelection();
      elements.menu.hidden = false;
    },
    hideMenu() {
      elements.menu.hidden = true;
    },
    showEnding(state, onRestart) {
      elements.overlayResult.textContent = `${state.collectedClaws.size}/20 cap cakar · cadangan lemak ${Math.round(state.fat)}%`;
      elements.overlay.hidden = false;
      elements.overlayButton.onclick = () => {
        elements.overlay.hidden = true;
        onRestart();
      };
    },
    destroy() {
      cancelAnimationFrame(previewFrameId);
      window.clearTimeout(toastTimer);
      elements.overlayButton.onclick = null;
      mount.replaceChildren();
    },
  };
}
