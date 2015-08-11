import "dart:html";
import "dart:web_audio";
import "dart:async";
import "dart:math" as math;

const num X_STEP = 100 * 2 * math.PI;
const int Y_STEP = 100;

const int ENTER_KEY_CODE = 13;
const int SPACE_KEY_CODE = 32;
const int LEFT_KEY_CODE = 37;
const int RIGHT_KEY_CODE = 39;

const int WAVE_HEIGHT = 400;
const num MIDDLE_A = 440;

AudioContext audioContext;
OscillatorNode oscillator;

CanvasElement canvas;
CanvasRenderingContext2D ctx;

CanvasElement sineCanvas;
CanvasRenderingContext2D sineContext;

CanvasElement correctWaveCanvas;

RangeInputElement frequencySlider;

num frequency = MIDDLE_A;

bool playing = false;

num x = 0;
int delta, now;
int then = 0;

void main() {	
	audioContext = new AudioContext();
	
	canvas = querySelector("#waveBoard");
	canvas.tabIndex = 9001;
	updateCanvases();
	
	frequencySlider = querySelector("#frequencySlider");
	frequencySlider.min = "27.50";
	frequencySlider.max = "4186.01";
	frequencySlider.step = "0.01";
	updateFrequency(frequency);
	
	frequencySlider.onInput.listen((Event e) {
		updateFrequency(frequencySlider.valueAsNumber);
	});
	
	Element middleAButton = querySelector("#middleAButton");
	middleAButton.onClick.listen((_) => updateFrequency(MIDDLE_A));
	Element playPause = querySelector("#playPause");
	playPause.onClick.listen((_) {
		if(playing) {
			oscillatorOff();
			playPause.innerHtml = "&#9654;";
		} else {
			oscillatorOn();
			playPause.innerHtml = "||";
		}
		playing = !playing;
	});
	
	window.onKeyDown.listen((KeyboardEvent e) {
		if(e.keyCode == ENTER_KEY_CODE) {
			middleAButton.click();
		} else if(e.keyCode == SPACE_KEY_CODE) {
			playPause.click();
		} else if(e.keyCode == LEFT_KEY_CODE) {
			updateFrequency(frequency - 1);
		} else if(e.keyCode == RIGHT_KEY_CODE) {
			updateFrequency(frequency + 1);
		}
	});

	window.onResize.listen((_) =>	updateCanvases());
		
	ctx.beginPath();
	Timer drawTimer = new Timer.periodic(Duration.ZERO, waveLoop);
}


void waveLoop(Timer t) {
	now = new DateTime.now().millisecondsSinceEpoch;
	delta = new DateTime.now().millisecondsSinceEpoch - then;
	
	correctWaveCanvas = sineCanvas;
	
	if(playing) {
		//x += 360 * oscillator.frequency.value / MIDDLE_A * 0.001 * delta;
		x += 1 * delta * 0.001;
		if(x >= scaledPeriod()) {
			x = 0;
		}
	}
	
	then = now;
	
	ctx.clearRect(0, 0, canvas.width, canvas.height);
	ctx.strokeRect(0, 0, X_STEP, 1000);
	ctx.drawImage(correctWaveCanvas, x - 360, canvas.height / 2 - correctWaveCanvas.height / 2);
}

void updateCanvases() {
	canvas.width = window.innerWidth;
	canvas.height = window.innerHeight;
	ctx = canvas.getContext("2d");
	ctx.fillStyle = "black";
	ctx.strokeStyle = "black";
	
	sineCanvas = new CanvasElement(width: canvas.width + 360, height: window.innerHeight);
	sineContext = sineCanvas.getContext("2d");
	sineContext.fillStyle = ctx.fillStyle;
	sineContext.strokeStyle = ctx.strokeStyle;
	
	sineContext.clearRect(0, 0, sineCanvas.width, sineCanvas.height);
	sineContext.beginPath();
	sineContext.moveTo(0, sineCanvas.height / 2);
	for(int i = 0; i < sineCanvas.width; i++) {
		drawSineWave(180 / math.PI, i, sineCanvas.height / 2);
	}
	sineContext.stroke();
}

void drawSineWave(num amplitude, num angle, num offset) {
	sineContext.lineTo(angle, -amplitude * math.sin(scaledFrequency() * angle * math.PI / 180) + offset);
}

void drawFourierSquareWave(num amplitude, num angle, num offset) {
	
}

double scaledFrequency() {
	return frequency / X_STEP;
}

double scaledPeriod() {
	print(scaledFrequency());
	return 1 / scaledFrequency();
}

void updateFrequency(num value) {
	frequency = value;
	frequencySlider.value = value.toString();
	
	if(oscillator != null) {
		// oscillator.type = "sawtooth";
		oscillator.frequency.value = frequency;
	}
	
	updateCanvases();
}

void oscillatorOn() {
	oscillator = audioContext.createOscillator();
	oscillator.frequency.value = frequency;
	oscillator.connectNode(audioContext.destination);
	oscillator.start(0);
}

void oscillatorOff() {
	oscillator.stop(0);
}