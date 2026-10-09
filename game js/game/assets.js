import assetsManifest from "../assets.json";
import { ALL_IMAGE_KEYS, SHEET_KEYS } from "./data.js";

function loadImage(url) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.decoding = "async";
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(`Gagal memuat gambar: ${url}`));
    image.src = url;
  });
}

export function createAssetStore(assets) {
  const images = new Map();
  const sheets = new Map();
  const pending = new Map();

  const urlFor = (key) => assets?.get(key) || assetsManifest[key];

  async function load(key) {
    if (images.has(key)) return images.get(key);
    if (pending.has(key)) return pending.get(key);
    const url = urlFor(key);
    if (!url) throw new Error(`Aset ${key} tidak terdaftar`);

    const promise = Promise.all([
      loadImage(url),
      SHEET_KEYS.includes(key)
        ? fetch(assetsManifest[key].replace(/\.webp$/, ".frames.json")).then((response) => {
            if (!response.ok) throw new Error(`Data frame ${key} tidak tersedia`);
            return response.json();
          })
        : Promise.resolve(null),
    ]).then(([image, sheet]) => {
      images.set(key, image);
      if (sheet) sheets.set(key, sheet);
      pending.delete(key);
      return image;
    });

    pending.set(key, promise);
    return promise;
  }

  async function preload(keys) {
    const results = await Promise.allSettled([...new Set(keys)].map((key) => load(key)));
    return results.every((result) => result.status === "fulfilled");
  }

  return {
    load,
    preload,
    preloadAll() {
      return preload(ALL_IMAGE_KEYS);
    },
    image(key) {
      return images.get(key);
    },
    sheet(key) {
      return sheets.get(key);
    },
    frame(key, name) {
      return sheets.get(key)?.frames?.find((frame) => frame.name === name);
    },
    animation(key, name) {
      return sheets.get(key)?.animations?.find((animation) => animation.name === name);
    },
  };
}
