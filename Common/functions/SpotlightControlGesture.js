// Pure local Ctrl gesture state. The caller supplies monotonic event times and
// cancels on focus, composition, modality and pointer activity.
var holdThreshold = 250;

function idle() { return { pending: false, started: 0, held: false }; }

function press(state, event) {
    if (!event.eligible) return idle();
    if (!event.controlKey) return idle();
    if (event.repeat) return state;
    // Another Ctrl press (including the other physical key) is a chord.
    if (state.pending || state.held || event.otherModifiers) return idle();
    return { pending: true, started: event.time, held: false };
}

function hold(state, time, eligible) {
    if (!eligible) return idle();
    if (!state.pending || time - state.started < holdThreshold) return state;
    // The tap candidate expires even if its eventual release is lost. Held
    // presentation is cleared by the next local release/focus/pointer signal.
    return { pending: false, started: state.started, held: true };
}

function release(state, event) {
    const toggle = state.pending && !state.held && event.controlKey && !event.repeat
        && event.eligible && !event.otherModifiers
        && event.time >= state.started && event.time - state.started < holdThreshold;
    return { state: idle(), toggle: toggle };
}
