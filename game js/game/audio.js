export function createAudio({ sdk, shell }) {
  let managed;
  let context;
  let unlocked = false;
  let noiseBuffer;

  async function init() {
    try {
      managed = await sdk.audio.getContext();
      context = managed.context;
      noiseBuffer = context.createBuffer(1, Math.floor(context.sampleRate * 0.35), context.sampleRate);
      const data = noiseBuffer.getChannelData(0);
      for (let index = 0; index < data.length; index += 1) {
        data[index] = (Math.random() * 2 - 1) * (1 - index / data.length);
      }
    } catch {
      context = undefined;
    }
  }

  function unlock() {
    if (!managed || unlocked) return;
    void managed.unlock().then(() => {
      unlocked = true;
    }).catch(() => {});
  }

  const unlockHandler = () => unlock();
  shell.addEventListener("pointerdown", unlockHandler, { capture: true });
  window.addEventListener("keydown", unlockHandler, { capture: true });
  void init();

  function tone(frequency, duration = 0.08, volume = 0.05, type = "sine") {
    if (!context || context.state !== "running") return;
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, context.currentTime);
    gain.gain.setValueAtTime(volume, context.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, context.currentTime + duration);
    oscillator.connect(gain).connect(context.destination);
    oscillator.start();
    oscillator.stop(context.currentTime + duration);
  }

  function texture({ cutoff = 700, duration = 0.14, volume = 0.08 } = {}) {
    if (!context || !noiseBuffer || context.state !== "running") return;
    const source = context.createBufferSource();
    const filter = context.createBiquadFilter();
    const gain = context.createGain();
    source.buffer = noiseBuffer;
    filter.type = "lowpass";
    filter.frequency.value = cutoff;
    gain.gain.setValueAtTime(volume, context.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, context.currentTime + duration);
    source.connect(filter).connect(gain).connect(context.destination);
    source.start();
    source.stop(context.currentTime + duration);
  }

  function play(name) {
    if (name === "jump") tone(230, 0.09, 0.04, "triangle");
    if (name === "shift") {
      tone(150, 0.11, 0.055, "triangle");
      texture({ cutoff: 450, duration: 0.1, volume: 0.035 });
    }
    if (name === "land") texture({ cutoff: 280, duration: 0.17, volume: 0.1 });
    if (name === "claw") texture({ cutoff: 1450, duration: 0.13, volume: 0.07 });
    if (name === "break") {
      texture({ cutoff: 520, duration: 0.24, volume: 0.12 });
      tone(85, 0.18, 0.05, "sine");
    }
    if (name === "pickup") tone(620, 0.08, 0.045, "sine");
    if (name === "hurt") tone(110, 0.22, 0.06, "sawtooth");
    if (name === "checkpoint") {
      tone(440, 0.12, 0.04, "sine");
      window.setTimeout(() => tone(660, 0.16, 0.035, "sine"), 80);
    }
  }

  return {
    play,
    unlock,
    async destroy() {
      shell.removeEventListener("pointerdown", unlockHandler, { capture: true });
      window.removeEventListener("keydown", unlockHandler, { capture: true });
      if (managed) await managed.dispose().catch(() => {});
    },
  };
}
