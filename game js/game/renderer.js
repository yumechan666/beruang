import { playerSheetFor } from "./data.js";

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function frameAt(assetStore, key, animationName, frameIndex) {
  const animation = assetStore.animation(key, animationName);
  if (!animation?.frames?.length) return null;
  const index = ((frameIndex % animation.frames.length) + animation.frames.length) % animation.frames.length;
  return animation.frames[index];
}

function drawFrameInCell(ctx, image, frame, x, y, w, h, alpha = 1) {
  if (!image || !frame) return;
  const crop = frame.content || frame.source;
  if (!crop) return;
  const scale = Math.min(w / crop.w, h / crop.h);
  const drawW = crop.w * scale;
  const drawH = crop.h * scale;
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.drawImage(image, crop.x, crop.y, crop.w, crop.h, x + (w - drawW) / 2, y + (h - drawH) / 2, drawW, drawH);
  ctx.restore();
}

export function createRenderer(canvas, stanceCanvas, assetStore, config) {
  const ctx = canvas.getContext("2d");
  const stanceCtx = stanceCanvas.getContext("2d");
  let width = 0;
  let height = 0;

  function resize() {
    const rect = canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(rect.width * dpr);
    canvas.height = Math.round(rect.height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    width = rect.width;
    height = rect.height;
  }

  function viewFor(state) {
    const worldHeight = 680;
    const scale = height / worldHeight;
    const worldWidth = width / scale;
    const look = state.player.facing * config.cameraLookAhead * (state.player.mode === "quad" ? 1 : 0.55);
    const target = state.player.x + look - worldWidth * 0.42;
    const maxCamera = Math.max(0, state.level.width - worldWidth);
    state.cameraX += (clamp(target, 0, maxCamera) - state.cameraX) * 0.1;
    const shake = state.shake > 0 ? Math.sin(state.time * 72) * 6 * state.shake * config.effectsIntensity : 0;
    return { scale, worldWidth, cameraX: state.cameraX, shake };
  }

  function screenX(view, worldX) {
    return (worldX - view.cameraX) * view.scale + view.shake;
  }

  function screenY(view, worldY) {
    return worldY * view.scale;
  }

  function drawBackground(state, view) {
    const image = assetStore.image(state.level.bg);
    if (!image) {
      ctx.fillStyle = state.areaIndex >= 8 ? "#17304a" : "#809a62";
      ctx.fillRect(0, 0, width, height);
      return;
    }
    const drawH = height;
    const drawW = image.width * (drawH / image.height);
    const offset = -((view.cameraX * 0.12) % (drawW * 2));
    for (let index = -2; index < Math.ceil(width / drawW) + 3; index += 1) {
      const tileIndex = index + Math.floor((view.cameraX * 0.12) / drawW);
      const x = offset + index * drawW;
      ctx.save();
      if (Math.abs(tileIndex) % 2 === 1) {
        ctx.translate(x + drawW, 0);
        ctx.scale(-1, 1);
        ctx.drawImage(image, 0, 0, drawW, drawH);
      } else {
        ctx.drawImage(image, x, 0, drawW, drawH);
      }
      ctx.restore();
    }
  }

  function drawPlatform(state, view, ground) {
    if (ground.hidden && state.instinctTimer <= 0) return;
    const image = assetStore.image(state.level.tile);
    const sheet = assetStore.sheet(state.level.tile);
    const frame = sheet?.frames?.find((item) => item.name === "center" && !item.empty);
    const x = screenX(view, ground.x);
    const y = screenY(view, ground.y);
    const w = ground.w * view.scale;
    if (!image || !frame?.content) return;
    const crop = frame.content;
    const surfaceY = frame.surfaceY ?? crop.y;
    const scaleY = 0.42 * view.scale;
    const drawY = y - (surfaceY - crop.y) * scaleY;
    ctx.save();
    if (ground.hidden) {
      ctx.globalAlpha = 0.82;
      ctx.globalCompositeOperation = "screen";
    }
    ctx.drawImage(image, crop.x, crop.y, crop.w, crop.h, x, drawY, w, crop.h * scaleY);
    ctx.restore();
  }

  function drawAtlasObject(key, name, view, x, y, w, h, alpha = 1) {
    const image = assetStore.image(key);
    const frame = assetStore.frame(key, name);
    drawFrameInCell(ctx, image, frame, screenX(view, x - w / 2), screenY(view, y - h), w * view.scale, h * view.scale, alpha);
  }

  function drawZones(state, view) {
    for (const zone of state.level.zones || []) {
      const x = screenX(view, zone.x);
      const w = zone.w * view.scale;
      if (zone.type === "current") {
        const gradient = ctx.createLinearGradient(0, screenY(view, 535), 0, height);
        gradient.addColorStop(0, "rgba(90,180,190,.30)");
        gradient.addColorStop(1, "rgba(20,75,100,.68)");
        ctx.fillStyle = gradient;
        ctx.fillRect(x, screenY(view, 535), w, height - screenY(view, 535));
      }
      if (zone.type === "grass") {
        ctx.fillStyle = "rgba(45,74,38,.35)";
        ctx.fillRect(x, screenY(view, 490), w, screenY(view, 65));
      }
      if (zone.type === "steam" || zone.type === "ash" || zone.type === "warm") {
        const colors = zone.type === "steam"
          ? ["rgba(255,212,145,.08)", "rgba(255,145,72,.18)"]
          : zone.type === "ash"
            ? ["rgba(45,42,38,.05)", "rgba(35,29,28,.30)"]
            : ["rgba(255,205,154,.04)", "rgba(255,151,104,.15)"];
        const gradient = ctx.createLinearGradient(0, screenY(view, 420), 0, height);
        gradient.addColorStop(0, colors[0]);
        gradient.addColorStop(1, colors[1]);
        ctx.fillStyle = gradient;
        ctx.fillRect(x, screenY(view, 390), w, height - screenY(view, 390));
      }
      if (zone.type === "ice") {
        ctx.fillStyle = "rgba(165,229,242,.12)";
        ctx.fillRect(x, screenY(view, 520), w, screenY(view, 55));
      }
    }
  }

  function drawProps(state, view) {
    for (const object of state.objects) {
      if (object.opened && object.type !== "checkpoint_tree") continue;
      const alpha = object.trap && state.instinctTimer <= 0 ? 0.55 : 1;
      drawAtlasObject(object.atlas || "WORLD_PROPS", object.type, view, object.x, object.y, object.w, object.h, alpha);
      if (object.type === "checkpoint_tree" && object.activated) {
        const glow = ctx.createRadialGradient(screenX(view, object.x), screenY(view, object.y - 62), 0, screenX(view, object.x), screenY(view, object.y - 62), 65 * view.scale);
        glow.addColorStop(0, "rgba(255,216,113,.55)");
        glow.addColorStop(1, "rgba(255,216,113,0)");
        ctx.save();
        ctx.globalCompositeOperation = "screen";
        ctx.fillStyle = glow;
        ctx.fillRect(screenX(view, object.x - 80), screenY(view, object.y - 150), 160 * view.scale, 160 * view.scale);
        ctx.restore();
      }
    }
  }

  function drawPickups(state, view) {
    for (const pickup of state.pickups) {
      if (pickup.collected) continue;
      if (pickup.hidden && state.instinctTimer <= 0) continue;
      const bob = Math.sin(state.time * 3 + pickup.x) * 7;
      drawAtlasObject(pickup.atlas || "FOOD_ATLAS", pickup.type, view, pickup.x, pickup.y + bob, 54, 54);
    }
    if (!state.collectedClaws.has(state.areaIndex) && state.level.claw) {
      const claw = state.level.claw;
      const bob = Math.sin(state.time * 3.8) * 8;
      drawAtlasObject("UI_ICONS", "claw_collectible", view, claw.x, claw.y + bob, 56, 56);
    }
  }

  function drawAnchored(key, animationName, index, view, x, y, artScale, facing = 1, alpha = 1) {
    const image = assetStore.image(key);
    const frame = frameAt(assetStore, key, animationName, index);
    if (!image || !frame) return;
    const crop = frame.content || frame.source;
    const anchor = frame.anchor || { x: frame.source.x + frame.source.w / 2, y: frame.source.y + frame.source.h };
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.translate(screenX(view, x), screenY(view, y));
    ctx.scale(facing * artScale * view.scale, artScale * view.scale);
    ctx.drawImage(image, crop.x, crop.y, crop.w, crop.h, -(anchor.x - crop.x), -(anchor.y - crop.y), crop.w, crop.h);
    ctx.restore();
  }

  function drawEnemies(state, view) {
    for (const enemy of state.enemies) {
      const anim = enemy.stunned > 0 ? enemy.anim : enemy.alert > 0 && enemy.attackAnim ? enemy.attackAnim : enemy.anim;
      const frame = Math.floor(state.time * (enemy.alert > 0 ? 10 : 6)) % 5;
      const alpha = enemy.stunned > 0 ? 0.55 : 1;
      drawAnchored(enemy.sheet, anim, frame, view, enemy.x, enemy.y, enemy.scale, enemy.direction, alpha);

      if (enemy.human && enemy.alert <= 0) {
        const sx = screenX(view, enemy.x);
        const sy = screenY(view, enemy.y - 68);
        ctx.save();
        ctx.fillStyle = "rgba(255,207,91,.12)";
        ctx.beginPath();
        ctx.moveTo(sx, sy);
        ctx.lineTo(sx + enemy.direction * enemy.range * view.scale, sy + 80 * view.scale);
        ctx.lineTo(sx + enemy.direction * enemy.range * view.scale, sy - 80 * view.scale);
        ctx.closePath();
        ctx.fill();
        ctx.restore();
      }
    }
  }

  function playerAnimation(state) {
    const player = state.player;
    if (player.action) {
      const progress = clamp(player.action.age / player.action.duration, 0, 0.999);
      let frame = Math.floor(progress * 5);
      if (player.action.reverse) frame = 4 - frame;
      return { sheet: player.action.sheet, anim: player.action.anim, frame };
    }
    if (!player.grounded) {
      return player.mode === "biped"
        ? { sheet: "URSA_BIPED_CORE", anim: "biped_jump", frame: clamp(Math.floor((player.vy + 700) / 290), 0, 4) }
        : { sheet: "URSA_QUAD_CORE", anim: "quad_jump", frame: clamp(Math.floor((player.vy + 700) / 290), 0, 4) };
    }
    if (player.mode === "biped") {
      return { sheet: "URSA_BIPED_CORE", anim: player.moving ? "biped_walk" : "biped_idle", frame: Math.floor(state.time * (player.moving ? 9 : 5)) % 5 };
    }
    return { sheet: "URSA_QUAD_CORE", anim: player.moving ? "quad_run" : "quad_sniff", frame: Math.floor(state.time * (player.moving ? 11 : 5)) % 5 };
  }

  function drawPlayer(state, view) {
    const player = state.player;
    const animation = playerAnimation(state);
    const blink = player.invulnerable > 0 && Math.floor(state.time * 14) % 2 === 0;
    const skinSheet = playerSheetFor(player.skin, animation.sheet);
    drawAnchored(skinSheet, animation.anim, animation.frame, view, player.x, player.y, player.mode === "biped" ? 0.31 : 0.29, player.facing, blink ? 0.45 : 1);
  }

  function drawEffects(state, view) {
    for (const effect of state.effects) {
      const frame = Math.min(4, Math.floor((effect.age / effect.duration) * 5));
      drawAnchored(effect.sheet, effect.anim, frame, view, effect.x, effect.y, effect.scale, 1, 1 - effect.age / effect.duration * 0.25);
    }
  }

  function drawAtmosphere(state, view) {
    if (state.areaIndex === 7) {
      const dusk = 1 - clamp(state.areaTimer / 55, 0, 1);
      ctx.fillStyle = `rgba(28,21,46,${dusk * 0.34})`;
      ctx.fillRect(0, 0, width, height);
    }
    if (state.areaIndex === 9 || state.level.cold || state.level.noise) {
      for (let index = 0; index < 46 * config.effectsIntensity; index += 1) {
        const x = ((index * 79 + state.time * 170) % (width + 100)) - 50;
        const y = (index * 131) % height;
        ctx.fillStyle = `rgba(238,249,255,${0.18 + (index % 3) * 0.08})`;
        ctx.beginPath();
        ctx.arc(x, y, 1.2 + (index % 3), 0, Math.PI * 2);
        ctx.fill();
      }
    }
    if (state.level.dark) {
      ctx.fillStyle = `rgba(3,9,21,${state.instinctTimer > 0 ? 0.34 : 0.68})`;
      ctx.fillRect(0, 0, width, height);
      if (state.instinctTimer > 0) {
        const px = screenX(view, state.player.x);
        const py = screenY(view, state.player.y - 38);
        const glow = ctx.createRadialGradient(px, py, 5, px, py, 190 * view.scale);
        glow.addColorStop(0, "rgba(92,232,239,.22)");
        glow.addColorStop(1, "rgba(92,232,239,0)");
        ctx.save();
        ctx.globalCompositeOperation = "screen";
        ctx.fillStyle = glow;
        ctx.fillRect(px - 210 * view.scale, py - 210 * view.scale, 420 * view.scale, 420 * view.scale);
        ctx.restore();
      }
    }
  }

  function drawTutorial(state, view) {
    if (state.player.x > 720 || state.areaIndex !== 0) return;
    const x = screenX(view, 265);
    const y = screenY(view, 390);
    ctx.save();
    ctx.font = `800 ${Math.max(13, 18 * view.scale)}px "Nunito Sans", sans-serif`;
    ctx.textAlign = "center";
    ctx.fillStyle = "rgba(27,31,20,.80)";
    const text = state.player.mode === "quad" ? "SHIFT untuk berdiri" : "SHIFT untuk merangkak";
    const metrics = ctx.measureText(text);
    ctx.fillRect(x - metrics.width / 2 - 12, y - 22, metrics.width + 24, 32);
    ctx.fillStyle = "#fff2cf";
    ctx.fillText(text, x, y);
    ctx.restore();
  }

  function drawStanceIcon(state) {
    const rect = stanceCanvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    if (stanceCanvas.width !== Math.round(rect.width * dpr) || stanceCanvas.height !== Math.round(rect.height * dpr)) {
      stanceCanvas.width = Math.round(rect.width * dpr);
      stanceCanvas.height = Math.round(rect.height * dpr);
    }
    stanceCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
    stanceCtx.clearRect(0, 0, rect.width, rect.height);
    const frame = assetStore.frame("UI_ICONS", state.player.mode === "biped" ? "biped_stance" : "quad_stance");
    drawFrameInCell(stanceCtx, assetStore.image("UI_ICONS"), frame, 0, 0, rect.width, rect.height);
  }

  function render(state) {
    if (!width || !height) return;
    const view = viewFor(state);
    ctx.clearRect(0, 0, width, height);
    drawBackground(state, view);
    drawZones(state, view);
    for (const ground of state.platforms) drawPlatform(state, view, ground);
    drawProps(state, view);
    drawPickups(state, view);
    drawEnemies(state, view);
    drawAtmosphere(state, view);
    drawEffects(state, view);
    drawPlayer(state, view);
    drawTutorial(state, view);
    drawStanceIcon(state);
  }

  return { resize, render };
}
