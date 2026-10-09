import { createAssetStore } from "./assets.js";
import { createAudio } from "./audio.js";
import { AREA_DATA, SKINS, playerSkinKeys } from "./data.js";
import { createInput } from "./input.js";
import { createRenderer } from "./renderer.js";
import { createUI } from "./ui.js";
import { createWorld, updateWorld } from "./world.js";

function sanitizeSave(value) {
  const currentVersion = Number(value?.version) >= 2;
  const requestedArea = currentVersion && Number.isInteger(value?.currentArea) ? value.currentArea : 0;
  const requestedHighestArea = currentVersion && Number.isInteger(value?.highestArea) ? value.highestArea : 0;
  const highestArea = Math.max(0, Math.min(AREA_DATA.length - 1, requestedHighestArea));
  const area = Math.max(0, Math.min(highestArea, requestedArea));
  const claws = Array.isArray(value?.collectedClaws)
    ? value.collectedClaws.filter((item) => Number.isInteger(item) && item >= 0 && item < AREA_DATA.length)
    : [];
  const purchasedSkins = [...new Set([
    "brown",
    ...(currentVersion && Array.isArray(value?.purchasedSkins)
      ? value.purchasedSkins.filter((id) => SKINS.some((skin) => skin.id === id && skin.price > 0))
      : []),
  ])];
  return {
    version: 2,
    currentArea: Math.max(0, Math.min(AREA_DATA.length - 1, area)),
    highestArea,
    collectedClaws: claws,
    totalFood: Math.max(0, Number(value?.totalFood) || 0),
    fat: Math.max(0, Math.min(100, Number(value?.fat) || 20)),
    years: Math.max(0, Number(value?.years) || 0),
    purchasedSkins,
    selectedSkin: purchasedSkins.includes(value?.selectedSkin) ? value.selectedSkin : "brown",
  };
}

export function createGame({ mount, sdk, ready, tweaks, assets }) {
  let cleanup = () => {};
  let runId = 0;

  return {
    start() {
      const id = ++runId;
      const ui = createUI(mount, assets);
      const assetStore = createAssetStore(assets);
      const audio = createAudio({ sdk, shell: ui.elements.shell });
      const config = {
        bipedSpeed: Number(tweaks.get("bipedSpeed")),
        quadSpeed: Number(tweaks.get("quadSpeed")),
        gravity: Number(tweaks.get("gravity")),
        cameraLookAhead: Number(tweaks.get("cameraLookAhead")),
        effectsIntensity: Number(tweaks.get("effectsIntensity")),
      };
      const unsubscribers = [];
      for (const key of Object.keys(config)) {
        unsubscribers.push(tweaks.subscribe(key, (value) => {
          config[key] = Number(value);
        }));
      }

      let input;
      let renderer;
      let resizeObserver;
      let frameId = 0;
      let lastTime = 0;
      let state;
      let transitionTimer = 0;
      let destroyed = false;
      let saved = sanitizeSave(null);
      let menuOpen = true;

      const haptic = (pattern) => {
        if (!sdk.device.haptics.isSupported()) return;
        void sdk.device.haptics.vibrate(pattern).catch(() => {});
      };

      function progressFromState(nextArea = state.areaIndex) {
        return {
          version: 2,
          currentArea: nextArea,
          highestArea: Math.max(saved.highestArea, nextArea),
          collectedClaws: [...state.collectedClaws],
          totalFood: state.totalFood,
          fat: state.fat,
          years: saved.years,
          purchasedSkins: [...saved.purchasedSkins],
          selectedSkin: state.player.skin,
        };
      }

      function persist(nextArea = state.areaIndex) {
        saved = progressFromState(nextArea);
        void sdk.gameState.save(saved).catch(() => {});
      }

      function purchaseSkin(skinId) {
        const skin = SKINS.find((item) => item.id === skinId);
        if (!skin) return false;
        if (saved.purchasedSkins.includes(skinId)) {
          saved.selectedSkin = skinId;
          state.player.skin = skinId;
          persist();
          return true;
        }

        const price = Number(skin.price) || 0;
        if (price <= 0 || state.totalFood < price) {
          ui.toast("Koin belum cukup. Kumpulkan makanan di area.");
          return false;
        }

        state.totalFood -= price;
        saved.totalFood = state.totalFood;
        saved.purchasedSkins.push(skinId);
        saved.selectedSkin = skinId;
        state.player.skin = skinId;
        persist();
        ui.update(state);
        ui.toast(`${skin.name} berhasil dibeli!`);
        return true;
      }

      function startFromMenu(areaIndex, skinId) {
        if (areaIndex > saved.highestArea) {
          ui.toast("Selesaikan area sebelumnya dulu.");
          return;
        }
        if (!saved.purchasedSkins.includes(skinId)) {
          ui.toast("Beli skin ini dengan koin terlebih dahulu.");
          return;
        }
        menuOpen = false;
        saved.currentArea = areaIndex;
        saved.selectedSkin = skinId;
        void sdk.gameState.save(saved).catch(() => {});
        void enterArea(areaIndex, saved);
      }

      function showStartMenu() {
        ui.showMenu({
          areaIndex: state.areaIndex,
          skinId: state.player.skin,
          highestArea: saved.highestArea,
          purchasedSkins: saved.purchasedSkins,
          onStart: startFromMenu,
          onPurchase: purchaseSkin,
        });
      }

      async function enterArea(index, progress, announce = true) {
        const level = AREA_DATA[index];
        await assetStore.preload([level.bg, level.tile, level.enemySheet, ...playerSkinKeys(progress.selectedSkin)]);
        if (destroyed || id !== runId) return;
        state = createWorld(index, progress);
        input.clearPressed();
        ui.update(state);
        if (announce) ui.toast(`${index + 1}. ${level.name} · ${level.lesson}`, 3000);
      }

      function completeArea() {
        if (transitionTimer || state.ending) return;
        if (state.areaIndex < AREA_DATA.length - 1) {
          const next = state.areaIndex + 1;
          const progress = progressFromState(next);
          persist(next);
          ui.toast(`Bab ${state.areaIndex + 1} selesai · ${AREA_DATA[next].season}`, 1800);
          transitionTimer = window.setTimeout(() => {
            transitionTimer = 0;
            void enterArea(next, progress);
          }, 1050);
          return;
        }

        state.ending = true;
        state.player.action = { sheet: "URSA_YEAR2_INSTINCT", anim: "star_sleep", duration: 1, age: 0.96, reverse: false };
        saved.years += 1;
        persist(AREA_DATA.length - 1);
        audio.play("checkpoint");
        haptic([25, 55, 25, 80]);
        transitionTimer = window.setTimeout(() => {
          transitionTimer = 0;
          ui.showEnding(state, () => {
            const restartProgress = {
              collectedClaws: [...state.collectedClaws],
              totalFood: 0,
              fat: 20,
              selectedSkin: state.player.skin,
            };
            saved.currentArea = 0;
            void sdk.gameState.save({ ...saved, currentArea: 0, totalFood: 0, fat: 20 }).catch(() => {});
            void enterArea(0, restartProgress);
          });
        }, 950);
      }

      const hooks = {
        audio: (name) => audio.play(name),
        toast: (text) => ui.toast(text),
        haptic,
        complete: completeArea,
        restartArea: () => {
          const progress = progressFromState(state.areaIndex);
          transitionTimer = window.setTimeout(() => {
            transitionTimer = 0;
            void enterArea(state.areaIndex, progress, false);
          }, 280);
        },
      };

      function loop(now) {
        if (destroyed || !state) return;
        const dt = lastTime ? Math.min(0.033, (now - lastTime) / 1000) : 0;
        lastTime = now;
        if (!menuOpen) updateWorld(state, input, dt, config, hooks);
        renderer.render(state);
        ui.update(state);
        frameId = requestAnimationFrame(loop);
      }

      async function boot() {
        try {
          saved = sanitizeSave(await sdk.gameState.load());
        } catch {
          saved = sanitizeSave(null);
        }
        if (destroyed || id !== runId) return;

        const area = AREA_DATA[saved.currentArea];
        ui.toast("Menyiapkan jejak musim…", 8000);
        const criticalReady = await assetStore.preload([
          "URSA_BIPED_CORE",
          "URSA_QUAD_CORE",
          "URSA_SKILLS",
          "URSA_SPECIAL",
          "URSA_REACTIONS",
          "URSA_YEAR2_SKILLS",
          "URSA_YEAR2_INSTINCT",
          "WORLD_PROPS",
          "FOOD_ATLAS",
          "UI_ICONS",
          "WARM_EFFECTS",
          "GOLDEN_EFFECTS",
          "WINTER_EFFECTS",
          "YEAR2_PROPS_A",
          "YEAR2_PROPS_B",
          "YEAR2_FOOD",
          "YEAR2_EFFECTS_A",
          "YEAR2_EFFECTS_B",
          "YEAR2_EFFECTS_C",
          ...SKINS.map((skin) => skin.sheets.URSA_BIPED_CORE),
          ...playerSkinKeys(saved.selectedSkin),
          area.bg,
          area.tile,
          area.enemySheet,
        ]);
        if (destroyed || id !== runId) return;

        if (!criticalReady) {
          ui.toast("Sebagian lukisan belum terbuka. Ketuk untuk mencoba lagi.", 8000);
          ui.elements.overlay.hidden = false;
          ui.elements.overlay.querySelector(".overlay-kicker").textContent = "KABUT TEBAL";
          ui.elements.overlay.querySelector("h2").textContent = "Jejak belum terlihat.";
          ui.elements.overlayResult.textContent = "Periksa koneksi lalu coba memuat lukisan kembali.";
          ui.elements.overlayButton.querySelector(".control-label").textContent = "Coba lagi";
          ui.elements.overlayButton.onclick = () => {
            ui.elements.overlay.hidden = true;
            void boot();
          };
          return;
        }

        input = createInput(ui.elements.shell, ui.controls);
        renderer = createRenderer(ui.elements.canvas, ui.elements.stanceCanvas, assetStore, config);
        resizeObserver = new ResizeObserver(() => renderer.resize());
        resizeObserver.observe(ui.elements.canvas);
        renderer.resize();
        state = createWorld(saved.currentArea, saved);
        ui.setPreviewStore(assetStore);
        ui.onMenu(() => {
          menuOpen = true;
          input.clearPressed();
          showStartMenu();
        });
        showStartMenu();
        void assetStore.preloadAll();
        frameId = requestAnimationFrame(loop);
      }

      void boot();

      cleanup = () => {
        destroyed = true;
        runId += 1;
        cancelAnimationFrame(frameId);
        window.clearTimeout(transitionTimer);
        resizeObserver?.disconnect();
        input?.destroy();
        unsubscribers.forEach((unsubscribe) => unsubscribe?.());
        void audio.destroy();
        ui.destroy();
      };
    },
    destroy() {
      cleanup();
      cleanup = () => {};
    },
    sdk,
    ready,
    tweaks,
    assets,
  };
}
