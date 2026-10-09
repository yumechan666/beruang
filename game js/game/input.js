const KEY_MAP = {
  ArrowLeft: "left",
  a: "left",
  A: "left",
  ArrowRight: "right",
  d: "right",
  D: "right",
  ArrowDown: "down",
  s: "down",
  S: "down",
  " ": "jump",
  w: "jump",
  W: "jump",
  ArrowUp: "jump",
  Shift: "shift",
  e: "action",
  E: "action",
  j: "action",
  J: "action",
};

export function createInput(shell, controls) {
  const held = { left: false, right: false, down: false, jump: false, shift: false, action: false };
  const pressed = new Set();
  const cleanups = [];

  function setControl(name, active) {
    if (active && !held[name]) pressed.add(name);
    held[name] = active;
  }

  function onKeyDown(event) {
    const control = KEY_MAP[event.key];
    if (!control) return;
    event.preventDefault();
    setControl(control, true);
  }

  function onKeyUp(event) {
    const control = KEY_MAP[event.key];
    if (!control) return;
    event.preventDefault();
    setControl(control, false);
  }

  window.addEventListener("keydown", onKeyDown);
  window.addEventListener("keyup", onKeyUp);
  cleanups.push(() => window.removeEventListener("keydown", onKeyDown));
  cleanups.push(() => window.removeEventListener("keyup", onKeyUp));

  for (const [name, button] of Object.entries(controls)) {
    const release = (event) => {
      event.preventDefault();
      setControl(name, false);
    };
    const press = (event) => {
      event.preventDefault();
      button.setPointerCapture?.(event.pointerId);
      setControl(name, true);
    };
    button.addEventListener("pointerdown", press);
    button.addEventListener("pointerup", release);
    button.addEventListener("pointercancel", release);
    button.addEventListener("lostpointercapture", release);
    cleanups.push(() => button.removeEventListener("pointerdown", press));
    cleanups.push(() => button.removeEventListener("pointerup", release));
    cleanups.push(() => button.removeEventListener("pointercancel", release));
    cleanups.push(() => button.removeEventListener("lostpointercapture", release));
  }

  const clearAll = () => {
    for (const key of Object.keys(held)) held[key] = false;
    pressed.clear();
  };
  window.addEventListener("blur", clearAll);
  cleanups.push(() => window.removeEventListener("blur", clearAll));

  shell.addEventListener("contextmenu", (event) => event.preventDefault());

  return {
    held,
    axis() {
      return Number(held.right) - Number(held.left);
    },
    consume(name) {
      if (!pressed.has(name)) return false;
      pressed.delete(name);
      return true;
    },
    clearPressed() {
      pressed.clear();
    },
    destroy() {
      cleanups.forEach((cleanup) => cleanup());
      clearAll();
    },
  };
}
