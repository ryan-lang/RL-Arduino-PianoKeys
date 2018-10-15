var port = chrome.runtime.connectNative('com.rlang.arduinopiano');

chrome.runtime.onMessage.addListener((e) => {
    if (e.event == "chordChange") {
    	let message = e.chord.root+e.chord.extension;
    	console.log("Posting to arduinopiano:", message);
        port.postMessage(message);
    }
});