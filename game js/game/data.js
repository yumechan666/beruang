const platform = (x, y, w, h = 180) => ({ x, y, w, h });

const STANDARD_PATH = [
  platform(0, 570, 680),
  platform(760, 555, 440),
  platform(1280, 500, 360),
  platform(1730, 545, 450),
  platform(2270, 475, 330),
  platform(2670, 550, 560),
];

const HIGH_PATH = [
  platform(900, 420, 190, 90),
  platform(1470, 350, 180, 90),
  platform(1990, 390, 170, 90),
  platform(2400, 315, 170, 90),
];

function pathWith(...extras) {
  return [...STANDARD_PATH.map((item) => ({ ...item })), ...extras];
}

export const AREA_DATA = [
  {
    name: "Hutan Rumah",
    season: "MUSIM SEMI",
    lesson: "Rendah untuk menembus. Tinggi untuk meraih.",
    bg: "BG_AREA_01",
    tile: "TILES_SPRING",
    enemySheet: "SPRING_CREATURES",
    width: 3230,
    platforms: pathWith(platform(1110, 390, 170, 80), platform(2500, 335, 160, 80)),
    objects: [
      { type: "hollow_log", x: 470, y: 570, w: 190, h: 105, requires: "quad" },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
    ],
    pickups: [
      { type: "spring_berries", x: 1010, y: 360 },
      { type: "spring_berries", x: 1510, y: 310 },
      { type: "healing_herbs", x: 2440, y: 280 },
    ],
    enemies: [
      { sheet: "SPRING_CREATURES", anim: "beetle_crawl", x: 1380, y: 500, range: 180, scale: 0.16 },
      { sheet: "SPRING_CREATURES", anim: "beetle_attack", x: 2360, y: 475, range: 130, scale: 0.15 },
    ],
    claw: { x: 2550, y: 285 },
  },
  {
    name: "Sungai Deras",
    season: "AKHIR MUSIM SEMI",
    lesson: "Empat kaki mencengkeram batu licin.",
    bg: "BG_AREA_02",
    tile: "TILES_RIVER",
    enemySheet: "SPRING_CREATURES",
    width: 3230,
    platforms: pathWith(platform(1450, 375, 180, 80), platform(2100, 380, 160, 80)),
    objects: [{ type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 }],
    pickups: [
      { type: "salmon", x: 930, y: 430, buff: true },
      { type: "salmon", x: 1510, y: 330, buff: true },
      { type: "salmon", x: 2150, y: 335, buff: true },
    ],
    enemies: [
      { sheet: "SPRING_CREATURES", anim: "otter_swim", x: 1120, y: 530, range: 210, scale: 0.2, air: true },
      { sheet: "SPRING_CREATURES", anim: "otter_push", x: 2450, y: 475, range: 130, scale: 0.18 },
    ],
    zones: [{ type: "current", x: 720, w: 920 }],
    claw: { x: 1550, y: 305 },
  },
  {
    name: "Hutan Lebat",
    season: "MUSIM PANAS",
    lesson: "Cakar kayu lapuk untuk membentuk jalan.",
    bg: "BG_AREA_03",
    tile: "TILES_WOOD",
    enemySheet: "FOREST_CLIFF_CREATURES",
    width: 3230,
    platforms: pathWith(...HIGH_PATH.map((item) => ({ ...item }))),
    objects: [
      { type: "carve_wall", x: 1130, y: 555, w: 90, h: 175, requires: "biped", breakable: true },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "carve_wall", x: 2200, y: 545, w: 90, h: 175, requires: "biped", breakable: true },
    ],
    pickups: [{ type: "spring_berries", x: 2040, y: 345 }],
    enemies: [
      { sheet: "FOREST_CLIFF_CREATURES", anim: "wood_beetle_fly", x: 1450, y: 365, range: 190, scale: 0.13, air: true },
      { sheet: "FOREST_CLIFF_CREATURES", anim: "wood_beetle_bite", x: 2410, y: 475, range: 140, scale: 0.13 },
    ],
    claw: { x: 2450, y: 270 },
  },
  {
    name: "Tebing Berkabut",
    season: "MUSIM PANAS",
    lesson: "Tahan angin rendah. Hantam batu dengan beratmu.",
    bg: "BG_AREA_04",
    tile: "TILES_CLIFF",
    enemySheet: "FOREST_CLIFF_CREATURES",
    width: 3230,
    platforms: pathWith(platform(1050, 380, 150, 80), platform(1520, 325, 180, 80), platform(2380, 310, 190, 80)),
    objects: [
      { type: "fragile_rock", x: 1320, y: 500, w: 100, h: 115, requires: "biped", breakable: true },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
    ],
    pickups: [{ type: "healing_herbs", x: 1580, y: 275 }],
    enemies: [
      { sheet: "FOREST_CLIFF_CREATURES", anim: "goat_idle", attackAnim: "goat_charge", x: 1960, y: 545, range: 250, scale: 0.2 },
    ],
    zones: [{ type: "wind", x: 1180, w: 1450 }],
    claw: { x: 2460, y: 260 },
  },
  {
    name: "Rawa Madu",
    season: "MUSIM PANAS",
    lesson: "Berjalan pelan. Sprint membangunkan sarang.",
    bg: "BG_AREA_05",
    tile: "TILES_HONEY",
    enemySheet: "HIVE_CREATURES",
    width: 3230,
    platforms: pathWith(platform(980, 410, 200, 90), platform(1500, 350, 170, 90), platform(2340, 340, 180, 90)),
    objects: [
      { type: "honey_wall", x: 1210, y: 555, w: 80, h: 170, requires: "biped" },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
    ],
    pickups: [
      { type: "honeycomb", x: 1040, y: 365, buff: true },
      { type: "honeycomb", x: 2400, y: 295, buff: true },
    ],
    enemies: [
      { sheet: "HIVE_CREATURES", anim: "worker_fly", x: 1450, y: 350, range: 210, scale: 0.12, air: true },
      { sheet: "HIVE_CREATURES", anim: "guard_alert", attackAnim: "guard_chase", x: 2220, y: 360, range: 300, scale: 0.14, air: true, noiseSensitive: true },
      { sheet: "HIVE_CREATURES", anim: "queen_hover", x: 2780, y: 330, range: 120, scale: 0.16, air: true, harmless: true },
    ],
    zones: [{ type: "honey", x: 700, w: 1900 }],
    claw: { x: 1560, y: 300 },
  },
  {
    name: "Air Terjun Salmon",
    season: "MUSIM PANAS",
    lesson: "Makan dulu. Gunakan tenaga sebelum pudar.",
    bg: "BG_AREA_06",
    tile: "TILES_RIVER",
    enemySheet: "RIVER_CREATURES",
    width: 3230,
    platforms: pathWith(platform(960, 410, 170, 80), platform(1430, 335, 170, 80), platform(1950, 285, 170, 80), platform(2420, 330, 170, 80)),
    objects: [{ type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 }],
    pickups: [
      { type: "salmon", x: 900, y: 455, buff: true },
      { type: "salmon", x: 1460, y: 290, buff: true },
      { type: "salmon", x: 2470, y: 285, buff: true },
    ],
    enemies: [
      { sheet: "RIVER_CREATURES", anim: "salmon_jump", x: 1180, y: 430, range: 130, scale: 0.14, air: true, harmless: true },
      { sheet: "RIVER_CREATURES", anim: "eagle_glide", attackAnim: "eagle_dive", x: 2050, y: 230, range: 350, scale: 0.18, air: true },
    ],
    claw: { x: 2030, y: 235 },
  },
  {
    name: "Perkemahan Manusia",
    season: "AKHIR MUSIM PANAS",
    lesson: "Rendahkan profil. Berdiri hanya saat aman.",
    bg: "BG_AREA_07",
    tile: "TILES_AUTUMN",
    enemySheet: "CAMP_CREATURES",
    width: 3230,
    platforms: pathWith(platform(1000, 420, 180, 80), platform(2360, 390, 190, 80)),
    objects: [
      { type: "camp_crate", x: 1160, y: 555, w: 85, h: 95, requires: "biped", breakable: true },
      { type: "bear_trap", x: 1510, y: 545, w: 75, h: 35, trap: true },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "camp_crate", x: 2530, y: 475, w: 85, h: 95, requires: "biped", breakable: true },
    ],
    pickups: [{ type: "apple", x: 1210, y: 500, buff: true }],
    enemies: [
      { sheet: "CAMP_CREATURES", anim: "ranger_walk", attackAnim: "ranger_alert", x: 1420, y: 555, range: 300, scale: 0.22, human: true },
      { sheet: "CAMP_CREATURES", anim: "dog_patrol", attackAnim: "dog_chase", x: 2250, y: 475, range: 270, scale: 0.18, human: true },
    ],
    zones: [
      { type: "grass", x: 850, w: 340 },
      { type: "grass", x: 2050, w: 310 },
    ],
    claw: { x: 2430, y: 340 },
  },
  {
    name: "Ladang Musim Gugur",
    season: "MUSIM GUGUR",
    lesson: "Pilih rute. Isi cadangan sebelum senja.",
    bg: "BG_AREA_08",
    tile: "TILES_AUTUMN",
    enemySheet: "AUTUMN_CREATURES",
    width: 3230,
    platforms: pathWith(...HIGH_PATH.map((item) => ({ ...item }))),
    objects: [{ type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 }],
    pickups: [
      { type: "apple", x: 850, y: 505, fat: 12 },
      { type: "pumpkin", x: 1030, y: 365, fat: 18 },
      { type: "acorns", x: 1500, y: 305, fat: 10 },
      { type: "honeycomb", x: 2030, y: 345, fat: 16 },
      { type: "spring_berries", x: 2390, y: 270, fat: 12 },
      { type: "fat_cache", x: 2800, y: 490, fat: 28 },
    ],
    enemies: [
      { sheet: "AUTUMN_CREATURES", anim: "raccoon_run", attackAnim: "raccoon_eat", x: 1330, y: 500, range: 240, scale: 0.16 },
      { sheet: "AUTUMN_CREATURES", anim: "deer_walk", attackAnim: "deer_block", x: 2200, y: 545, range: 170, scale: 0.2 },
    ],
    timer: 55,
    claw: { x: 2450, y: 260 },
  },
  {
    name: "Gua Es",
    season: "AWAL MUSIM DINGIN",
    lesson: "Endus kegelapan. Ingat jalur bercahaya.",
    bg: "BG_AREA_09",
    tile: "TILES_ICE",
    enemySheet: "ICE_CREATURES",
    width: 3230,
    platforms: pathWith(
      { ...platform(980, 410, 180, 80), hidden: true },
      { ...platform(1450, 345, 170, 80), hidden: true },
      { ...platform(2050, 360, 170, 80), hidden: true },
      { ...platform(2420, 300, 170, 80), hidden: true },
    ),
    objects: [
      { type: "fragile_rock", x: 1210, y: 555, w: 95, h: 110, requires: "biped", breakable: true },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "carve_wall", x: 2220, y: 545, w: 90, h: 175, requires: "biped", breakable: true },
    ],
    pickups: [{ type: "healing_herbs", x: 2470, y: 255 }],
    enemies: [
      { sheet: "ICE_CREATURES", anim: "bat_hang", attackAnim: "bat_startled", x: 1500, y: 260, range: 260, scale: 0.13, air: true },
      { sheet: "ICE_CREATURES", anim: "bat_fly", x: 2400, y: 260, range: 220, scale: 0.13, air: true },
    ],
    dark: true,
    claw: { x: 2480, y: 245 },
  },
  {
    name: "Puncak Musim Dingin",
    season: "MUSIM DINGIN",
    lesson: "Kuat saat berdiri. Stabil saat berlari.",
    bg: "BG_AREA_10",
    tile: "TILES_ICE",
    enemySheet: "ICE_CREATURES",
    width: 3230,
    platforms: pathWith(platform(980, 410, 180, 80), platform(1470, 345, 170, 80), platform(2050, 370, 170, 80), platform(2430, 310, 170, 80)),
    objects: [
      { type: "fragile_rock", x: 1160, y: 555, w: 100, h: 115, requires: "biped", breakable: true },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "carve_wall", x: 2220, y: 545, w: 90, h: 175, requires: "biped", breakable: true },
      { type: "winter_cave", x: 2950, y: 550, w: 210, h: 180 },
    ],
    pickups: [
      { type: "salmon", x: 1530, y: 300, buff: true },
      { type: "fat_cache", x: 2480, y: 260, fat: 20 },
    ],
    enemies: [
      { sheet: "ICE_CREATURES", anim: "bat_fly", attackAnim: "bat_startled", x: 2100, y: 270, range: 250, scale: 0.13, air: true },
    ],
    zones: [{ type: "wind", x: 650, w: 2300 }],
    cold: true,
    claw: { x: 2500, y: 245 },
  },
];

const YEAR_TWO_AREAS = [
  {
    name: "Lembah Napas Bumi",
    season: "TAHUN KEDUA · MUSIM SEMI",
    lesson: "Berdiri menahan uap. Merangkak membaca jedanya.",
    bg: "BG_AREA_11",
    tile: "TILES_THERMAL",
    enemySheet: "THERMAL_CREATURES",
    width: 3230,
    platforms: pathWith(platform(980, 410, 190, 80), platform(1480, 345, 180, 80), platform(2360, 330, 190, 80)),
    objects: [
      { type: "steam_vent", atlas: "YEAR2_PROPS_A", x: 910, y: 555, w: 90, h: 90, steam: true },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "steam_vent", atlas: "YEAR2_PROPS_A", x: 2380, y: 475, w: 90, h: 90, steam: true },
    ],
    pickups: [
      { type: "mineral_salt", atlas: "YEAR2_FOOD", x: 1030, y: 365 },
      { type: "cloudberry", atlas: "YEAR2_FOOD", x: 1530, y: 300, fat: 10 },
    ],
    enemies: [
      { sheet: "THERMAL_CREATURES", anim: "pika_scurry", attackAnim: "pika_hide", x: 1350, y: 500, range: 190, scale: 0.15, harmless: true },
      { sheet: "THERMAL_CREATURES", anim: "salamander_crawl", attackAnim: "salamander_flash", x: 2260, y: 545, range: 170, scale: 0.16 },
    ],
    zones: [{ type: "steam", x: 650, w: 2050 }],
    heat: true,
    claw: { x: 2410, y: 280 },
  },
  {
    name: "Kanopi Raksasa",
    season: "TAHUN KEDUA · MUSIM SEMI",
    lesson: "Dorong batang saat berdiri, lalu gunakan momentum rendah.",
    bg: "BG_AREA_12",
    tile: "TILES_REDWOOD",
    enemySheet: "REDWOOD_CREATURES",
    width: 3230,
    platforms: pathWith(...HIGH_PATH.map((item) => ({ ...item })), platform(2750, 300, 180, 80)),
    objects: [
      { type: "redwood_gate", atlas: "YEAR2_PROPS_A", x: 1180, y: 555, w: 95, h: 190, requires: "biped", breakable: true },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "rolling_log", atlas: "YEAR2_PROPS_A", x: 2470, y: 475, w: 115, h: 80, requires: "biped", breakable: true },
    ],
    pickups: [
      { type: "pine_cone", atlas: "YEAR2_FOOD", x: 1510, y: 305 },
      { type: "cloudberry", atlas: "YEAR2_FOOD", x: 2440, y: 270 },
    ],
    enemies: [
      { sheet: "REDWOOD_CREATURES", anim: "squirrel_glide", attackAnim: "squirrel_land", x: 1480, y: 270, range: 260, scale: 0.14, air: true, harmless: true },
      { sheet: "REDWOOD_CREATURES", anim: "owl_perch", attackAnim: "owl_dive", x: 2260, y: 260, range: 330, scale: 0.16, air: true },
    ],
    zones: [{ type: "canopy", x: 800, w: 1900 }],
    claw: { x: 2800, y: 250 },
  },
  {
    name: "Danau Kaca",
    season: "TAHUN KEDUA · AKHIR MUSIM SEMI",
    lesson: "Sebar beratmu. Luncur, jangan melawan es.",
    bg: "BG_AREA_13",
    tile: "TILES_GLASS_ICE",
    enemySheet: "GLACIER_CREATURES",
    width: 3230,
    platforms: pathWith(platform(1020, 430, 180, 75), platform(1510, 360, 170, 75), platform(2360, 350, 190, 75)),
    objects: [
      { type: "thin_ice", atlas: "YEAR2_PROPS_B", x: 1120, y: 555, w: 150, h: 55, pressure: true },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "ice_pressure", atlas: "YEAR2_PROPS_A", x: 2380, y: 475, w: 140, h: 55, pressure: true },
    ],
    pickups: [
      { type: "trout", atlas: "YEAR2_FOOD", x: 1540, y: 315, buff: true },
      { type: "winter_pear", atlas: "YEAR2_FOOD", x: 2420, y: 300 },
    ],
    enemies: [
      { sheet: "GLACIER_CREATURES", anim: "seal_slide", attackAnim: "seal_dive", x: 1360, y: 500, range: 240, scale: 0.17, harmless: true },
      { sheet: "GLACIER_CREATURES", anim: "fox_trot", attackAnim: "fox_pounce", x: 2220, y: 545, range: 260, scale: 0.17 },
    ],
    zones: [{ type: "ice", x: 620, w: 2150 }],
    claw: { x: 2450, y: 300 },
  },
  {
    name: "Gua Gema Beri",
    season: "TAHUN KEDUA · MUSIM PANAS",
    lesson: "Endus memantul—jalur palsu berpendar lebih singkat.",
    bg: "BG_AREA_14",
    tile: "TILES_ECHO",
    enemySheet: "ECHO_CREATURES",
    width: 3230,
    platforms: pathWith(
      { ...platform(980, 415, 180, 75), hidden: true },
      { ...platform(1480, 340, 180, 75), hidden: true },
      { ...platform(2320, 330, 190, 75), hidden: true },
    ),
    objects: [
      { type: "echo_stone", atlas: "YEAR2_PROPS_A", x: 1100, y: 555, w: 80, h: 115, echo: true },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "scent_totem", atlas: "YEAR2_PROPS_B", x: 2440, y: 475, w: 75, h: 110, echo: true },
    ],
    pickups: [
      { type: "cave_berry", atlas: "YEAR2_FOOD", x: 1020, y: 365, hidden: true, fat: 12 },
      { type: "cave_berry", atlas: "YEAR2_FOOD", x: 2380, y: 280, hidden: true, fat: 12 },
    ],
    enemies: [
      { sheet: "ECHO_CREATURES", anim: "porcupine_walk", attackAnim: "porcupine_bristle", x: 1390, y: 500, range: 180, scale: 0.17 },
      { sheet: "ECHO_CREATURES", anim: "cricket_hop", attackAnim: "cricket_alert", x: 2250, y: 350, range: 230, scale: 0.12, air: true },
    ],
    dark: true,
    echo: true,
    claw: { x: 2440, y: 275 },
  },
  {
    name: "Hutan Bekas Api",
    season: "TAHUN KEDUA · MUSIM PANAS",
    lesson: "Berdiri menahan abu. Merangkak menembus asap cepat.",
    bg: "BG_AREA_15",
    tile: "TILES_ASH",
    enemySheet: "ASH_CREATURES",
    width: 3230,
    platforms: pathWith(platform(1030, 400, 180, 80), platform(1510, 350, 170, 80), platform(2380, 325, 180, 80)),
    objects: [
      { type: "ash_shelter", atlas: "YEAR2_PROPS_A", x: 1120, y: 555, w: 180, h: 105, requires: "quad" },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "soot_hollow", atlas: "YEAR2_PROPS_B", x: 2420, y: 475, w: 180, h: 95, requires: "quad" },
    ],
    pickups: [
      { type: "fireweed_root", atlas: "YEAR2_FOOD", x: 1500, y: 305, fat: 14 },
      { type: "spring_herbs", atlas: "YEAR2_FOOD", x: 2410, y: 275 },
    ],
    enemies: [
      { sheet: "ASH_CREATURES", anim: "elk_walk", attackAnim: "elk_stamp", x: 1430, y: 500, range: 230, scale: 0.18 },
      { sheet: "ASH_CREATURES", anim: "fire_beetle_crawl", attackAnim: "fire_beetle_burst", x: 2320, y: 475, range: 180, scale: 0.13 },
    ],
    zones: [{ type: "ash", x: 650, w: 2120 }],
    heat: true,
    claw: { x: 2450, y: 270 },
  },
  {
    name: "Delta Pembangun",
    season: "TAHUN KEDUA · MUSIM PANAS",
    lesson: "Dorong kayu berdiri, tunggangi arus dengan empat kaki.",
    bg: "BG_AREA_16",
    tile: "TILES_DELTA",
    enemySheet: "DELTA_CREATURES",
    width: 3230,
    platforms: pathWith(platform(980, 425, 190, 75), platform(1490, 365, 180, 75), platform(2350, 350, 190, 75)),
    objects: [
      { type: "rolling_log", atlas: "YEAR2_PROPS_A", x: 1060, y: 555, w: 130, h: 75, requires: "biped", breakable: true },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "beaver_dam", atlas: "YEAR2_PROPS_A", x: 2380, y: 475, w: 125, h: 105, requires: "biped", breakable: true },
      { type: "raft_log", atlas: "YEAR2_PROPS_B", x: 2760, y: 550, w: 150, h: 65 },
    ],
    pickups: [
      { type: "mussels", atlas: "YEAR2_FOOD", x: 1510, y: 320, fat: 12 },
      { type: "trout", atlas: "YEAR2_FOOD", x: 2410, y: 305, buff: true },
    ],
    enemies: [
      { sheet: "DELTA_CREATURES", anim: "beaver_swim", attackAnim: "beaver_build", x: 1370, y: 525, range: 220, scale: 0.16, air: true, harmless: true },
      { sheet: "DELTA_CREATURES", anim: "heron_stalk", attackAnim: "heron_flap", x: 2260, y: 475, range: 230, scale: 0.17 },
    ],
    zones: [{ type: "current", x: 620, w: 2200 }],
    claw: { x: 2430, y: 300 },
  },
  {
    name: "Padang Bunga Bulan",
    season: "TAHUN KEDUA · MUSIM GUGUR",
    lesson: "Jejak hanya nyata saat bunga terbuka oleh naluri.",
    bg: "BG_AREA_17",
    tile: "TILES_MOON",
    enemySheet: "MOON_CREATURES",
    width: 3230,
    platforms: pathWith(
      { ...platform(1020, 410, 180, 75), hidden: true },
      { ...platform(1510, 345, 180, 75), hidden: true },
      { ...platform(2380, 330, 190, 75), hidden: true },
    ),
    objects: [
      { type: "moonflower_patch", atlas: "YEAR2_PROPS_A", x: 1080, y: 555, w: 130, h: 90 },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "moonflower_patch", atlas: "YEAR2_PROPS_A", x: 2440, y: 475, w: 130, h: 90 },
    ],
    pickups: [
      { type: "moon_berries", atlas: "YEAR2_FOOD", x: 1050, y: 360, hidden: true, fat: 14 },
      { type: "moon_berries", atlas: "YEAR2_FOOD", x: 2410, y: 280, hidden: true, fat: 14 },
    ],
    enemies: [
      { sheet: "MOON_CREATURES", anim: "moth_fly", attackAnim: "moth_spiral", x: 1430, y: 300, range: 240, scale: 0.13, air: true, harmless: true },
      { sheet: "MOON_CREATURES", anim: "fox_sneak", attackAnim: "fox_pounce", x: 2260, y: 475, range: 280, scale: 0.17 },
    ],
    moon: true,
    dark: true,
    claw: { x: 2440, y: 275 },
  },
  {
    name: "Jalur Longsor",
    season: "TAHUN KEDUA · MUSIM GUGUR",
    lesson: "Diam menyimpan aman. Pound membuka longsor terkendali.",
    bg: "BG_AREA_18",
    tile: "TILES_GLASS_ICE",
    enemySheet: "AVALANCHE_CREATURES",
    width: 3230,
    platforms: pathWith(platform(1030, 405, 180, 80), platform(1500, 340, 180, 80), platform(2370, 320, 190, 80)),
    objects: [
      { type: "avalanche_shelf", atlas: "YEAR2_PROPS_B", x: 1140, y: 555, w: 120, h: 125, requires: "biped", breakable: true, avalanche: true },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "avalanche_shelf", atlas: "YEAR2_PROPS_B", x: 2420, y: 475, w: 120, h: 125, requires: "biped", breakable: true, avalanche: true },
    ],
    pickups: [
      { type: "winter_pear", atlas: "YEAR2_FOOD", x: 1510, y: 295 },
      { type: "cloudberry", atlas: "YEAR2_FOOD", x: 2410, y: 270 },
    ],
    enemies: [
      { sheet: "AVALANCHE_CREATURES", anim: "hare_run", attackAnim: "hare_duck", x: 1380, y: 500, range: 220, scale: 0.14, harmless: true },
      { sheet: "AVALANCHE_CREATURES", anim: "ibex_step", attackAnim: "ibex_charge", x: 2250, y: 475, range: 260, scale: 0.18 },
    ],
    zones: [{ type: "wind", x: 650, w: 2150 }],
    noise: true,
    claw: { x: 2440, y: 265 },
  },
  {
    name: "Mata Air Rahasia",
    season: "TAHUN KEDUA · MUSIM DINGIN",
    lesson: "Simpan hangat di batu, belanjakan untuk sprint dingin.",
    bg: "BG_AREA_19",
    tile: "TILES_THERMAL",
    enemySheet: "REFUGE_CREATURES",
    width: 3230,
    platforms: pathWith(platform(980, 420, 190, 80), platform(1490, 355, 180, 80), platform(2380, 340, 190, 80)),
    objects: [
      { type: "hot_spring_vent", atlas: "YEAR2_PROPS_B", x: 1060, y: 555, w: 120, h: 95, warm: true },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "warm_stone", atlas: "YEAR2_PROPS_B", x: 2420, y: 475, w: 100, h: 80, warm: true },
    ],
    pickups: [
      { type: "spring_herbs", atlas: "YEAR2_FOOD", x: 1510, y: 310 },
      { type: "trout", atlas: "YEAR2_FOOD", x: 2410, y: 295, buff: true },
    ],
    enemies: [
      { sheet: "REFUGE_CREATURES", anim: "otter_soak", attackAnim: "otter_dive", x: 1370, y: 510, range: 200, scale: 0.16, harmless: true },
      { sheet: "REFUGE_CREATURES", anim: "crane_walk", attackAnim: "crane_fly", x: 2250, y: 475, range: 240, scale: 0.16 },
    ],
    zones: [{ type: "warm", x: 800, w: 520 }, { type: "warm", x: 2240, w: 500 }],
    cold: true,
    claw: { x: 2440, y: 290 },
  },
  {
    name: "Sarang Bintang",
    season: "TAHUN KEDUA · MALAM PANJANG",
    lesson: "Satukan berat, kecepatan, ingatan, dan naluri.",
    bg: "BG_AREA_20",
    tile: "TILES_MOON",
    enemySheet: "STAR_CREATURES",
    width: 3230,
    platforms: pathWith(
      { ...platform(1020, 410, 180, 75), hidden: true },
      platform(1510, 340, 180, 75),
      { ...platform(2380, 315, 190, 75), hidden: true },
    ),
    objects: [
      { type: "star_arch", atlas: "YEAR2_PROPS_B", x: 1120, y: 555, w: 165, h: 185, requires: "quad" },
      { type: "checkpoint_tree", x: 1690, y: 545, w: 70, h: 105 },
      { type: "scent_totem", atlas: "YEAR2_PROPS_B", x: 2420, y: 475, w: 85, h: 120, echo: true },
    ],
    pickups: [
      { type: "moon_berries", atlas: "YEAR2_FOOD", x: 1050, y: 360, hidden: true, fat: 12 },
      { type: "mineral_salt", atlas: "YEAR2_FOOD", x: 2410, y: 265, hidden: true },
    ],
    enemies: [
      { sheet: "STAR_CREATURES", anim: "glow_beetle_crawl", attackAnim: "glow_beetle_pulse", x: 1400, y: 500, range: 210, scale: 0.12, harmless: true },
      { sheet: "STAR_CREATURES", anim: "wolverine_patrol", attackAnim: "wolverine_retreat", x: 2240, y: 475, range: 250, scale: 0.17 },
    ],
    dark: true,
    starfall: true,
    claw: { x: 2440, y: 260 },
  },
];

AREA_DATA.push(...YEAR_TWO_AREAS);

// Every chapter has a second authored half. The offset keeps the existing half
// intact while remixing its verbs into a longer final test before the exit.
const EXTENSION_OFFSET = 3030;
const extensionProps = [
  { type: "hollow_log", w: 190, h: 105, requires: "quad" },
  { type: "fragile_rock", w: 100, h: 115, requires: "biped", breakable: true },
  { type: "carve_wall", w: 90, h: 175, requires: "biped", breakable: true },
  { type: "fragile_rock", w: 100, h: 115, requires: "biped", breakable: true },
  { type: "honey_wall", w: 90, h: 170, requires: "biped" },
  { type: "fragile_rock", w: 100, h: 115, requires: "biped", breakable: true },
  { type: "camp_crate", w: 90, h: 100, requires: "biped", breakable: true },
  { type: "hollow_log", w: 190, h: 105, requires: "quad" },
  { type: "carve_wall", w: 90, h: 175, requires: "biped", breakable: true },
  { type: "fragile_rock", w: 100, h: 115, requires: "biped", breakable: true },
  { type: "steam_vent", atlas: "YEAR2_PROPS_A", w: 95, h: 95, steam: true },
  { type: "redwood_gate", atlas: "YEAR2_PROPS_A", w: 95, h: 190, requires: "biped", breakable: true },
  { type: "thin_ice", atlas: "YEAR2_PROPS_B", w: 150, h: 55, pressure: true },
  { type: "echo_stone", atlas: "YEAR2_PROPS_A", w: 85, h: 120, echo: true },
  { type: "ash_shelter", atlas: "YEAR2_PROPS_A", w: 180, h: 105, requires: "quad" },
  { type: "beaver_dam", atlas: "YEAR2_PROPS_A", w: 125, h: 105, requires: "biped", breakable: true },
  { type: "moonflower_patch", atlas: "YEAR2_PROPS_A", w: 130, h: 90 },
  { type: "avalanche_shelf", atlas: "YEAR2_PROPS_B", w: 125, h: 125, requires: "biped", breakable: true, avalanche: true },
  { type: "hot_spring_vent", atlas: "YEAR2_PROPS_B", w: 120, h: 95, warm: true },
  { type: "star_arch", atlas: "YEAR2_PROPS_B", w: 170, h: 185, requires: "quad" },
];

for (const [index, area] of AREA_DATA.entries()) {
  area.width = 6260;
  area.platforms.push(
    ...STANDARD_PATH.map((item) => ({ ...item, x: item.x + EXTENSION_OFFSET })),
    ...HIGH_PATH.slice(0, index % 3 === 0 ? 4 : 2).map((item) => ({ ...item, x: item.x + EXTENSION_OFFSET, hidden: area.dark && index % 2 === 0 })),
  );
  area.objects.push(
    { type: "checkpoint_tree", x: 4740, y: 545, w: 70, h: 105 },
    { ...extensionProps[index], x: 4320, y: 500 },
  );
  area.pickups.push(
    ...area.pickups.slice(0, 2).map((item, pickupIndex) => ({ ...item, x: item.x + EXTENSION_OFFSET, y: Math.max(260, item.y - pickupIndex * 25) })),
  );
  area.enemies.push(
    ...area.enemies.slice(0, 2).map((item, enemyIndex) => ({ ...item, x: item.x + EXTENSION_OFFSET + enemyIndex * 120, originX: undefined })),
  );
  area.zones = [
    ...(area.zones || []),
    ...(area.zones || []).map((zone) => ({ ...zone, x: zone.x + EXTENSION_OFFSET })),
  ];
  if (index === AREA_DATA.length - 1) {
    area.objects.push({ type: "winter_cave", x: 6000, y: 550, w: 220, h: 185 });
  }
}

const BASE_PLAYER_SHEETS = {
  URSA_BIPED_CORE: "URSA_BIPED_CORE",
  URSA_QUAD_CORE: "URSA_QUAD_CORE",
  URSA_SKILLS: "URSA_SKILLS",
  URSA_SPECIAL: "URSA_SPECIAL",
  URSA_REACTIONS: "URSA_REACTIONS",
  URSA_YEAR2_SKILLS: "URSA_YEAR2_SKILLS",
  URSA_YEAR2_INSTINCT: "URSA_YEAR2_INSTINCT",
};

export const SKINS = [
  {
    id: "brown",
    name: "Cokelat Hutan",
    description: "Bulu cokelat muda klasik",
    swatch: "#8b5b36",
    price: 0,
    sheets: BASE_PLAYER_SHEETS,
  },
  {
    id: "black",
    name: "Hitam Malam",
    description: "Arang gelap, moncong hangat",
    swatch: "#242a29",
    price: 25,
    sheets: {
      URSA_BIPED_CORE: "BLACK_BIPED_CORE",
      URSA_QUAD_CORE: "BLACK_QUAD_CORE",
      URSA_SKILLS: "BLACK_SKILLS",
      URSA_SPECIAL: "BLACK_SPECIAL",
      URSA_REACTIONS: "BLACK_REACTIONS",
      URSA_YEAR2_SKILLS: "BLACK_YEAR2_SKILLS",
      URSA_YEAR2_INSTINCT: "BLACK_YEAR2_INSTINCT",
    },
  },
  {
    id: "cinnamon",
    name: "Kayu Manis",
    description: "Merah tembaga, kaki gelap",
    swatch: "#b66132",
    price: 50,
    sheets: {
      URSA_BIPED_CORE: "CINNAMON_BIPED_CORE",
      URSA_QUAD_CORE: "CINNAMON_QUAD_CORE",
      URSA_SKILLS: "CINNAMON_SKILLS",
      URSA_SPECIAL: "CINNAMON_SPECIAL",
      URSA_REACTIONS: "CINNAMON_REACTIONS",
      URSA_YEAR2_SKILLS: "CINNAMON_YEAR2_SKILLS",
      URSA_YEAR2_INSTINCT: "CINNAMON_YEAR2_INSTINCT",
    },
  },
];

export function playerSheetFor(skinId, baseKey) {
  return SKINS.find((skin) => skin.id === skinId)?.sheets[baseKey] || baseKey;
}

export function playerSkinKeys(skinId) {
  const skin = SKINS.find((item) => item.id === skinId) || SKINS[0];
  return Object.values(skin.sheets);
}

export const SHEET_KEYS = [
  "URSA_BIPED_CORE",
  "URSA_QUAD_CORE",
  "URSA_SKILLS",
  "URSA_SPECIAL",
  "URSA_REACTIONS",
  "URSA_YEAR2_SKILLS",
  "URSA_YEAR2_INSTINCT",
  "BLACK_BIPED_CORE",
  "BLACK_QUAD_CORE",
  "BLACK_SKILLS",
  "BLACK_SPECIAL",
  "BLACK_REACTIONS",
  "BLACK_YEAR2_SKILLS",
  "BLACK_YEAR2_INSTINCT",
  "CINNAMON_BIPED_CORE",
  "CINNAMON_QUAD_CORE",
  "CINNAMON_SKILLS",
  "CINNAMON_SPECIAL",
  "CINNAMON_REACTIONS",
  "CINNAMON_YEAR2_SKILLS",
  "CINNAMON_YEAR2_INSTINCT",
  "SPRING_CREATURES",
  "FOREST_CLIFF_CREATURES",
  "HIVE_CREATURES",
  "RIVER_CREATURES",
  "CAMP_CREATURES",
  "AUTUMN_CREATURES",
  "ICE_CREATURES",
  "THERMAL_CREATURES",
  "REDWOOD_CREATURES",
  "GLACIER_CREATURES",
  "ECHO_CREATURES",
  "ASH_CREATURES",
  "DELTA_CREATURES",
  "MOON_CREATURES",
  "AVALANCHE_CREATURES",
  "REFUGE_CREATURES",
  "STAR_CREATURES",
  "FOOD_ATLAS",
  "WORLD_PROPS",
  "YEAR2_PROPS_A",
  "YEAR2_PROPS_B",
  "YEAR2_FOOD",
  "UI_ICONS",
  "WARM_EFFECTS",
  "GOLDEN_EFFECTS",
  "WINTER_EFFECTS",
  "YEAR2_EFFECTS_A",
  "YEAR2_EFFECTS_B",
  "YEAR2_EFFECTS_C",
  "TILES_SPRING",
  "TILES_RIVER",
  "TILES_WOOD",
  "TILES_CLIFF",
  "TILES_HONEY",
  "TILES_AUTUMN",
  "TILES_ICE",
  "TILES_THERMAL",
  "TILES_REDWOOD",
  "TILES_GLASS_ICE",
  "TILES_ECHO",
  "TILES_ASH",
  "TILES_DELTA",
  "TILES_MOON",
];

export const ALL_IMAGE_KEYS = [
  ...SHEET_KEYS,
  ...AREA_DATA.map((area) => area.bg),
];
