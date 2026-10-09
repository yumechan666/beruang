import { AREA_DATA } from "./data.js";

const PLAYER_SIZES = {
  biped: { w: 54, h: 112 },
  quad: { w: 96, h: 58 },
};

function cloneList(list = []) {
  return list.map((item) => ({ ...item }));
}

export function createWorld(areaIndex, progress = {}) {
  const level = AREA_DATA[areaIndex];
  return {
    areaIndex,
    level,
    time: 0,
    cameraX: 0,
    shake: 0,
    completed: false,
    ending: false,
    totalFood: progress.totalFood || 0,
    fat: progress.fat ?? 20,
    cold: level.cold ? Math.min(100, 52 + (progress.fat ?? 20) * 0.45) : 100,
    heat: level.heat ? 20 : 0,
    noise: 0,
    buffTimer: 0,
    instinctTimer: 0,
    tractionTimer: 0,
    areaTimer: level.timer || 0,
    collectedClaws: new Set(progress.collectedClaws || []),
    platforms: cloneList(level.platforms),
    objects: cloneList(level.objects).map((object) => ({ ...object, opened: false, activated: false })),
    pickups: cloneList(level.pickups).map((pickup) => ({ ...pickup, collected: false })),
    enemies: cloneList(level.enemies).map((enemy, index) => ({
      ...enemy,
      originX: enemy.x,
      phase: index * 1.7,
      direction: index % 2 ? -1 : 1,
      stunned: 0,
      alert: 0,
    })),
    effects: [],
    checkpoint: { x: 120, y: level.platforms[0].y },
    player: {
      x: 120,
      y: level.platforms[0].y,
      vx: 0,
      vy: 0,
      mode: "quad",
      facing: 1,
      grounded: true,
      health: 3,
      skin: progress.selectedSkin || "brown",
      invulnerable: 0,
      action: null,
      moving: false,
      landedAt: 0,
    },
  };
}

function rectForPlayer(player) {
  const size = PLAYER_SIZES[player.mode];
  return { x: player.x - size.w / 2, y: player.y - size.h, w: size.w, h: size.h };
}

function overlaps(a, b) {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

function zoneAt(level, type, x) {
  return level.zones?.find((zone) => zone.type === type && x >= zone.x && x <= zone.x + zone.w);
}

function addEffect(state, sheet, anim, x, y, scale = 0.25) {
  state.effects.push({ sheet, anim, x, y, scale, age: 0, duration: 0.5 });
}

function beginAction(player, sheet, anim, duration = 0.42, reverse = false) {
  player.action = { sheet, anim, duration, age: 0, reverse };
}

function pulseHaptic(hooks, pattern) {
  hooks.haptic?.(pattern);
}

function damage(state, hooks, reason) {
  const player = state.player;
  if (player.invulnerable > 0) return;
  player.health -= 1;
  player.invulnerable = 1.2;
  player.x = state.checkpoint.x;
  player.y = state.checkpoint.y;
  player.vx = 0;
  player.vy = 0;
  player.grounded = true;
  state.shake = 0.3;
  hooks.audio?.("hurt");
  hooks.toast?.(reason);
  pulseHaptic(hooks, [40, 30, 50]);
  if (player.health <= 0) {
    player.health = 3;
    player.x = 120;
    player.y = state.level.platforms[0].y;
    state.checkpoint = { x: 120, y: state.level.platforms[0].y };
    state.buffTimer = 0;
    hooks.toast?.("Tiga kesempatan habis—area dimulai ulang.");
    hooks.restartArea?.();
  }
}

function resolveGateCollisions(state, previousX) {
  const player = state.player;
  const playerRect = rectForPlayer(player);
  for (const object of state.objects) {
    if (object.opened || object.type === "checkpoint_tree" || object.type === "winter_cave" || object.trap) continue;
    const blocksByMode = object.requires && object.requires !== player.mode;
    const blocksUntilOpened = object.breakable;
    if (!blocksByMode && !blocksUntilOpened) continue;
    const obstacle = { x: object.x - object.w / 2, y: object.y - object.h, w: object.w, h: object.h };
    if (!overlaps(playerRect, obstacle)) continue;
    const half = PLAYER_SIZES[player.mode].w / 2;
    if (previousX <= object.x) player.x = obstacle.x - half - 1;
    else player.x = obstacle.x + obstacle.w + half + 1;
    player.vx = 0;
  }
}

function nearestInteractive(state, range = 145) {
  return state.objects.find((object) => {
    if (object.opened || (!object.breakable && object.type !== "honey_wall")) return false;
    return Math.abs(object.x - state.player.x) < range && Math.abs(object.y - state.player.y) < 180;
  });
}

function nearestSpecial(state, range = 150) {
  return state.objects.find((object) => {
    const special = object.steam || object.warm || object.echo || object.avalanche || object.type === "rolling_log" || object.type === "beaver_dam" || object.type === "redwood_gate";
    return special && !object.opened && Math.abs(object.x - state.player.x) < range && Math.abs(object.y - state.player.y) < 190;
  });
}

function handleAction(state, hooks) {
  const player = state.player;
  if (player.action) return;

  if (player.mode === "quad" && state.areaIndex >= 8) {
    state.instinctTimer = 3.8;
    if (zoneAt(state.level, "ice", player.x)) {
      state.tractionTimer = 3.8;
      beginAction(player, "URSA_YEAR2_SKILLS", "ice_balance", 0.5);
      addEffect(state, "YEAR2_EFFECTS_A", "ice_crack", player.x, player.y, 0.24);
    } else if (state.level.echo) {
      beginAction(player, "URSA_YEAR2_INSTINCT", "echo_sniff", 0.5);
      addEffect(state, "YEAR2_EFFECTS_A", "echo_ring", player.x, player.y - 35, 0.34);
    } else if (state.level.moon || state.level.starfall) {
      beginAction(player, "URSA_YEAR2_INSTINCT", "moon_track", 0.5);
      addEffect(state, state.level.starfall ? "YEAR2_EFFECTS_C" : "YEAR2_EFFECTS_B", state.level.starfall ? "aurora_pulse" : "moon_pollen", player.x, player.y - 35, 0.3);
    } else {
      beginAction(player, "URSA_REACTIONS", "instinct", 0.5);
      addEffect(state, "WINTER_EFFECTS", "instinct_pulse", player.x, player.y - 40, 0.34);
    }
    hooks.audio?.("shift");
    pulseHaptic(hooks, 20);
    return;
  }

  if (player.mode === "biped" && !player.grounded) {
    player.vy = 1050;
    if (state.level.noise) {
      state.noise = Math.min(100, state.noise + 34);
      beginAction(player, "URSA_YEAR2_INSTINCT", "avalanche_pound", 0.46);
    } else {
      beginAction(player, "URSA_SKILLS", "ground_pound", 0.46);
    }
    return;
  }

  const special = nearestSpecial(state);
  if (special && player.mode === "biped") {
    if (special.steam || special.warm) {
      special.suppressed = 2.5;
      state.heat = Math.max(0, state.heat - 28);
      state.cold = Math.min(100, state.cold + 26);
      beginAction(player, "URSA_YEAR2_SKILLS", "steam_brace", 0.56);
      addEffect(state, special.warm ? "YEAR2_EFFECTS_B" : "YEAR2_EFFECTS_A", special.warm ? "warm_mist" : "steam_burst", special.x, special.y - 55, 0.3);
      hooks.audio?.("shift");
      return;
    }
    if (special.echo) {
      state.instinctTimer = 5;
      beginAction(player, "URSA_YEAR2_INSTINCT", "echo_sniff", 0.52);
      addEffect(state, "YEAR2_EFFECTS_A", "echo_ring", special.x, special.y - 55, 0.34);
      return;
    }
    special.opened = true;
    if (special.avalanche) {
      state.noise = 0;
      beginAction(player, "URSA_YEAR2_INSTINCT", "avalanche_pound", 0.58);
      addEffect(state, "YEAR2_EFFECTS_B", "avalanche_wave", special.x, special.y, 0.4);
    } else {
      beginAction(player, "URSA_YEAR2_SKILLS", "log_push", 0.58);
      addEffect(state, special.type === "beaver_dam" ? "YEAR2_EFFECTS_C" : "YEAR2_EFFECTS_C", special.type === "beaver_dam" ? "mud_splat" : "bark_fall", special.x, special.y - 30, 0.3);
    }
    hooks.audio?.("break");
    pulseHaptic(hooks, [30, 20, 30]);
    return;
  }

  if (player.mode === "biped" && zoneAt(state.level, "ash", player.x)) {
    beginAction(player, "URSA_YEAR2_SKILLS", "ash_shield", 0.5);
    state.heat = Math.max(0, state.heat - 18);
    addEffect(state, "YEAR2_EFFECTS_A", "ash_gust", player.x, player.y - 40, 0.28);
    return;
  }

  const object = nearestInteractive(state);
  if (object && player.mode === "biped") {
    object.opened = true;
    if (object.type === "fragile_rock") {
      beginAction(player, "URSA_SKILLS", "ground_pound", 0.5);
      addEffect(state, "GOLDEN_EFFECTS", "stone_break", object.x, object.y - 45, 0.33);
      hooks.audio?.("break");
    } else {
      beginAction(player, "URSA_SKILLS", "carve", 0.52);
      addEffect(state, "WARM_EFFECTS", "wood_chips", object.x, object.y - 60, 0.3);
      hooks.audio?.("claw");
    }
    state.shake = 0.22;
    pulseHaptic(hooks, [25, 20, 35]);
    return;
  }

  if (player.mode === "biped") {
    beginAction(player, "URSA_BIPED_CORE", "biped_claw", 0.38);
    hooks.audio?.("claw");
  } else {
    beginAction(player, "URSA_QUAD_CORE", "quad_tackle", 0.34);
    player.vx += player.facing * 170;
    hooks.audio?.("shift");
  }
}

function updateEnemies(state, dt, hooks) {
  const player = state.player;
  const playerRect = rectForPlayer(player);
  const hiddenInGrass = player.mode === "quad" && zoneAt(state.level, "grass", player.x);

  for (const enemy of state.enemies) {
    enemy.stunned = Math.max(0, enemy.stunned - dt);
    enemy.alert = Math.max(0, enemy.alert - dt);
    const distance = Math.abs(player.x - enemy.x);
    const noisy = enemy.noiseSensitive && player.mode === "quad" && Math.abs(player.vx) > 250;
    const spotted = enemy.human && !hiddenInGrass && distance < enemy.range && player.mode === "biped";
    if (noisy || spotted || (distance < enemy.range * 0.55 && !enemy.harmless)) enemy.alert = 0.75;

    const pace = enemy.alert > 0 ? 85 : 28;
    enemy.x = enemy.originX + Math.sin(state.time * (enemy.alert > 0 ? 2.2 : 0.8) + enemy.phase) * Math.min(enemy.range * 0.45, 120);
    enemy.direction = Math.cos(state.time * (enemy.alert > 0 ? 2.2 : 0.8) + enemy.phase) >= 0 ? 1 : -1;
    if (enemy.alert > 0 && !enemy.human) enemy.x += Math.sign(player.x - enemy.x) * pace * dt;

    const enemyRect = {
      x: enemy.x - 36,
      y: enemy.air ? enemy.y - 42 : enemy.y - 58,
      w: 72,
      h: enemy.air ? 70 : 58,
    };
    const attacking = player.action && (player.action.anim === "biped_claw" || player.action.anim === "quad_tackle" || player.action.anim === "ground_pound");
    if (attacking && distance < 115 && Math.abs(player.y - enemy.y) < 130 && !enemy.harmless && !enemy.human) {
      if (enemy.stunned <= 0) {
        enemy.stunned = 1.7;
        enemy.alert = 0;
        addEffect(state, "WARM_EFFECTS", "dust_puff", enemy.x, enemy.y - 20, 0.2);
        hooks.audio?.("land");
      }
    } else if (enemy.stunned <= 0 && !enemy.harmless && overlaps(playerRect, enemyRect)) {
      damage(state, hooks, enemy.human ? "Terdeteksi! Kembali ke semak terakhir." : "Baca gerakannya sebelum mendekat.");
    }
  }
}

function updateCollectibles(state, hooks) {
  const player = state.player;
  for (const pickup of state.pickups) {
    if (pickup.hidden && state.instinctTimer <= 0) continue;
    if (pickup.collected || Math.hypot(player.x - pickup.x, player.y - pickup.y) > 78) continue;
    pickup.collected = true;
    state.totalFood += 1;
    if (pickup.buff) state.buffTimer = Math.max(state.buffTimer, 8);
    if (pickup.fat) state.fat = Math.min(100, state.fat + pickup.fat);
    if (pickup.type === "healing_herbs") player.health = Math.min(3, player.health + 1);
    beginAction(player, "URSA_SKILLS", "eat", 0.38);
    addEffect(state, "GOLDEN_EFFECTS", "pollen_burst", pickup.x, pickup.y, 0.19);
    hooks.audio?.("pickup");
    pulseHaptic(hooks, 15);
  }

  if (!state.collectedClaws.has(state.areaIndex) && state.level.claw) {
    const claw = state.level.claw;
    if (Math.hypot(player.x - claw.x, player.y - claw.y) < 74) {
      state.collectedClaws.add(state.areaIndex);
      hooks.audio?.("checkpoint");
      hooks.toast?.(`Cap cakar ${state.collectedClaws.size}/${AREA_DATA.length} ditemukan`);
      addEffect(state, "WINTER_EFFECTS", "instinct_pulse", claw.x, claw.y, 0.2);
    }
  }
}

function updateCheckpoints(state, hooks) {
  for (const object of state.objects) {
    if (object.type !== "checkpoint_tree" || object.activated) continue;
    if (Math.abs(state.player.x - object.x) < 70) {
      object.activated = true;
      state.checkpoint = { x: object.x + 70, y: object.y };
      hooks.audio?.("checkpoint");
      hooks.toast?.("Jejak cakar tersimpan");
      pulseHaptic(hooks, [18, 35, 18]);
    }
  }
}

function updateHazards(state, hooks) {
  const playerRect = rectForPlayer(state.player);
  for (const object of state.objects) {
    if (!object.trap) continue;
    const trap = { x: object.x - object.w / 2, y: object.y - object.h, w: object.w, h: object.h };
    if (overlaps(playerRect, trap)) damage(state, hooks, state.instinctTimer > 0 ? "Jejak jebakan terlihat—lompat lebih awal." : "Endus rumput untuk menemukan jebakan.");
  }
  for (const object of state.objects) {
    object.suppressed = Math.max(0, (object.suppressed || 0) - 1 / 60);
    const near = Math.abs(state.player.x - object.x) < Math.max(70, object.w * 0.6);
    if (object.pressure && near && state.player.mode === "biped" && state.player.grounded) {
      addEffect(state, "YEAR2_EFFECTS_A", "ice_crack", object.x, object.y, 0.26);
      damage(state, hooks, "Es membaca beratmu—sebarkan tubuh dengan empat kaki.");
    }
    if (object.steam && object.suppressed <= 0 && near && Math.sin(state.time * 3.2 + object.x) > 0.72 && state.player.mode === "quad") {
      addEffect(state, "YEAR2_EFFECTS_A", "steam_burst", object.x, object.y - 50, 0.28);
      damage(state, hooks, "Uap meletup—berdiri dan tahan semburannya.");
    }
    if (object.warm && near) state.cold = Math.min(100, state.cold + 18 / 60);
  }
}

function updateEffects(state, dt) {
  for (const effect of state.effects) effect.age += dt;
  state.effects = state.effects.filter((effect) => effect.age < effect.duration);
}

export function updateWorld(state, input, dt, config, hooks) {
  if (state.completed || state.ending) return;
  const player = state.player;
  state.time += dt;
  state.shake = Math.max(0, state.shake - dt);
  player.invulnerable = Math.max(0, player.invulnerable - dt);
  state.buffTimer = Math.max(0, state.buffTimer - dt);
  state.instinctTimer = Math.max(0, state.instinctTimer - dt * (state.level.moon ? 0.55 : 1));
  state.tractionTimer = Math.max(0, state.tractionTimer - dt);
  if (state.areaTimer > 0) state.areaTimer = Math.max(0, state.areaTimer - dt);

  if (player.action) {
    player.action.age += dt;
    if (player.action.age >= player.action.duration) player.action = null;
  }

  if (input.consume("shift")) {
    const next = player.mode === "biped" ? "quad" : "biped";
    player.mode = next;
    beginAction(player, "URSA_SPECIAL", "stance_shift", 0.34, next === "biped");
    hooks.audio?.("shift");
    pulseHaptic(hooks, 18);
    addEffect(state, "WARM_EFFECTS", "dust_puff", player.x, player.y, 0.17);
  }

  if (input.consume("action")) handleAction(state, hooks);

  const axis = input.axis();
  if (axis) player.facing = axis;
  let speed = player.mode === "biped" ? config.bipedSpeed : config.quadSpeed;
  if (zoneAt(state.level, "honey", player.x) && player.mode === "quad") speed *= 0.42;
  if (zoneAt(state.level, "ice", player.x)) speed *= player.mode === "quad" ? 1.2 : 0.72;
  if (zoneAt(state.level, "ash", player.x)) speed *= player.mode === "quad" ? 1.12 : 0.82;
  const targetVx = axis * speed;
  player.vx += (targetVx - player.vx) * Math.min(1, dt * (player.grounded ? 11 : 5));
  const onIce = zoneAt(state.level, "ice", player.x);
  const braking = onIce && state.tractionTimer <= 0 ? 0.8 : 9;
  if (!axis && player.grounded) player.vx *= Math.max(0, 1 - dt * braking);
  player.moving = Math.abs(player.vx) > 38;

  if (zoneAt(state.level, "wind", player.x)) player.vx -= (player.mode === "biped" ? 145 : 48) * dt;
  if (zoneAt(state.level, "current", player.x)) player.vx -= (player.mode === "biped" ? 125 : 28) * dt;

  if (input.consume("jump") && player.grounded && !player.action) {
    const boost = state.buffTimer > 0 ? 1.23 : 1;
    player.vy = -(player.mode === "quad" ? 590 : 650) * boost;
    player.grounded = false;
    hooks.audio?.("jump");
    pulseHaptic(hooks, 12);
  }

  const previousX = player.x;
  const previousY = player.y;
  const wasGrounded = player.grounded;
  player.vy += config.gravity * dt;
  player.x += player.vx * dt;
  player.y += player.vy * dt;
  player.x = Math.max(40, Math.min(state.level.width - 30, player.x));
  resolveGateCollisions(state, previousX);

  player.grounded = false;
  if (player.vy >= 0) {
    const size = PLAYER_SIZES[player.mode];
    for (const ground of state.platforms) {
      const overlapsX = player.x + size.w / 2 > ground.x && player.x - size.w / 2 < ground.x + ground.w;
      if (overlapsX && previousY <= ground.y + 2 && player.y >= ground.y) {
        player.y = ground.y;
        player.vy = 0;
        player.grounded = true;
        break;
      }
    }
  }

  if (!wasGrounded && player.grounded && state.time - player.landedAt > 0.16) {
    player.landedAt = state.time;
    state.shake = Math.max(state.shake, player.mode === "biped" ? 0.16 : 0.08);
    addEffect(state, "WARM_EFFECTS", "dust_puff", player.x, player.y, 0.18);
    hooks.audio?.("land");
  }

  if (player.y > 760) damage(state, hooks, "Salah pijak—kembali ke jejak cakar.");

  if (state.level.cold) {
    const inWind = zoneAt(state.level, "wind", player.x);
    state.cold += (player.mode === "biped" ? 4.5 : -5.8) * dt;
    if (inWind) state.cold -= (player.mode === "biped" ? 1.2 : 3.4) * dt;
    if (zoneAt(state.level, "warm", player.x)) state.cold += 16 * dt;
    state.cold = Math.max(0, Math.min(100, state.cold));
    if (state.cold <= 0) {
      damage(state, hooks, "Terlalu dingin. Berdiri untuk menghangatkan tubuh.");
      state.cold = 42;
    }
  }

  if (state.level.heat) {
    const hotZone = zoneAt(state.level, "steam", player.x) || zoneAt(state.level, "ash", player.x);
    state.heat += hotZone ? (player.mode === "quad" ? 8.5 : 4.2) * dt : -5 * dt;
    if (player.action?.anim === "ash_shield" || player.action?.anim === "steam_brace") state.heat -= 9 * dt;
    state.heat = Math.max(0, Math.min(100, state.heat));
    if (state.heat >= 100) {
      damage(state, hooks, "Terlalu panas—gunakan lindungan atau berdiri menahan udara.");
      state.heat = 45;
    }
  }

  if (state.level.noise) {
    state.noise += (Math.abs(player.vx) > 280 ? 7 : -13) * dt;
    state.noise = Math.max(0, Math.min(100, state.noise));
    if (state.noise >= 100) {
      addEffect(state, "YEAR2_EFFECTS_B", "avalanche_wave", player.x + 120, player.y, 0.42);
      damage(state, hooks, "Salju mendengar langkahmu—bergerak pelan atau picu jalur aman.");
      state.noise = 28;
    }
  }

  updateEnemies(state, dt, hooks);
  updateCollectibles(state, hooks);
  updateCheckpoints(state, hooks);
  updateHazards(state, hooks);
  updateEffects(state, dt);

  if (state.areaIndex === 7 && state.areaTimer === 0 && state.totalFood > 0) hooks.toast?.("Malam tiba—segera menuju ujung ladang.");

  if (player.x >= state.level.width - 110) {
    state.completed = true;
    hooks.complete?.();
  }
}
