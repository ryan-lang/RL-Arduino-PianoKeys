window.addEventListener("message", (e) => {
    if(e.data.event == "chordChange"){
        chrome.runtime.sendMessage(e.data);
    }
});

runInPage(initChordWatcher);

function runInPage(fn) {
    const script = document.createElement('script');
    document.head.appendChild(script).text =
        '((...args) => (' + fn + ')(...args))(' + JSON.stringify(chrome.runtime.id) + ')';
    script.remove();
}

function initChordWatcher() {
    console.log('Extension loaded:', window.Chordify);

    let lastChord = null;
    window.Chordify.player.on('chordchange', function($curChord) {
        const chord = window.Chordify.song.chords[$curChord.data('i')];
        const { handle, handleParts } = chord;

        if (lastChord !== handle) {
            window.postMessage({ event: "chordChange", chord: handleParts }, '*');
            lastChord = handle;
        }
    });
}