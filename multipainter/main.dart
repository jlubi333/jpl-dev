import "dart:html";
import "dart:async";
import "dart:js" as js;
import "package:firebase/firebase.dart" as fb;

const int LEFT_BRACKET_KEY = 219;
const int RIGHT_BRACKET_KEY = 221;
const int C_KEY = 67;
const int M_KEY = 77;
const int S_KEY = 83;
const int X_KEY = 88;

Point mousePoint = new Point(window.innerWidth / 2, window.innerWidth / 2);

CanvasElement canvas;
CanvasRenderingContext2D ctx;
Element toolsPanel, brush, brushInfo;
AnchorElement saveButton;
InputElement colorSelector;
bool isDrawing = false;
int brushSize = 10;

fb.Firebase mainFirebase, roomFirebase;

void main() {
	String roomName = js.context.callMethod("prompt", ["Please enter a room name!"]);
	if (roomName == null) {
		window.alert("Bye!");
		return;
	}
	roomName = firebaseSanitize(roomName);
	querySelector("#roomName").text = roomName;

	mainFirebase = new fb.Firebase("https://jpl-painter.firebaseio.com/");
	roomFirebase = mainFirebase.child(roomName);

	int i = 0;
	roomFirebase.onValue.listen((fb.Event data) {
		fb.DataSnapshot dataSnapshot = data.snapshot;
		// The data URL for the canvas
		String val = data.snapshot.val();
		if (val != null) {
			ImageElement canvasData = new ImageElement();
			canvasData.onLoad.listen((Event e) {
				ctx.drawImage(canvasData, 0, 0);
			});
			canvasData.src = val;
		}
	});

	canvas = querySelector("#artboard");
	canvas.width = window.innerWidth;
	canvas.height = window.innerHeight;
	ctx = canvas.getContext("2d");

	toolsPanel = querySelector("#toolsPanel");

	brush = querySelector("#brush");
	brushInfo = querySelector("#brushInfo");
	setBrushSize(brushSize);

	colorSelector = querySelector("#colorSelector");
	colorSelector.onInput.listen((_) => setColor(colorSelector.value));
	setColor(colorSelector.value);

	canvas.onMouseDown.listen(canvasMouseDown);
	canvas.onMouseUp.listen(canvasMouseUp);
	canvas.onMouseMove.listen(canvasMouseMove);

	querySelector("#plus").onClick.listen((_) => increaseBrushSize());
	querySelector("#minus").onClick.listen((_) => decreaseBrushSize());
	querySelector("#fill").onClick.listen((_) => fillCanvas());
	saveButton = querySelector("#save a");
	saveButton.onClick.listen((_) => save());

	window.onKeyDown.listen((KeyboardEvent e) {
		if (e.keyCode == M_KEY) {
			if (toolsPanel.style.display == "none") {
				toolsPanel.style.display = "block";
			} else {
				toolsPanel.style.display = "none";
			}
		} else if (e.keyCode == C_KEY) {
			colorSelector.click();
		} else if (e.keyCode == RIGHT_BRACKET_KEY) {
			increaseBrushSize();
		} else if (e.keyCode == LEFT_BRACKET_KEY) {
			decreaseBrushSize();
		} else if (e.keyCode == X_KEY) {
			fillCanvas();
		} else if (e.keyCode == S_KEY) {
			save();
			saveButton.click();
		}
	});

	window.onContextMenu.listen((MouseEvent e) => e.preventDefault());
}

String firebaseSanitize(String s) {
	s = s.replaceAll(".", "");
	s = s.replaceAll("#", "");
	s = s.replaceAll("\$", "");
	s = s.replaceAll("[", "");
	s = s.replaceAll("]", "");
	if (s.length == 0) {
		s = " ";
	}
	return s;
}

void updateFirebase() {
	roomFirebase.set(canvas.toDataUrl());
}

void paint(Point p) {
	ctx.fillRect(p.x - brushSize / 2, p.y - brushSize / 2, brushSize, brushSize);
}

void fillCanvas() {
	ctx.fillRect(0, 0, canvas.width, canvas.height);
	updateFirebase();
}

void setColor(String color) {
	ctx.fillStyle = color;
	brush.style.backgroundColor = color;
}

void setBrushSize(num size) {
	brushSize = size;
	brush.style.width = "$brushSize";
	brush.style.height = "$brushSize";
	centerBrush();

	brushInfo.innerHtml = "Brush Size: " + brushSize.toString();
}

void increaseBrushSize() {
	setBrushSize(brushSize + 1);
}

void decreaseBrushSize() {
	if (brushSize == 1) {
		return;
	}
	setBrushSize(brushSize - 1);
}

void centerBrush() {
	brush.style.left = (mousePoint.x - brushSize / 2).toString();
	brush.style.top = (mousePoint.y - brushSize / 2).toString();
}

void save() {
	saveButton.href = canvas.toDataUrl();
}

void canvasMouseDown(MouseEvent e) {
	mousePoint = e.offset;
	isDrawing = true;
	paint(mousePoint);
}

void canvasMouseUp(MouseEvent e) {
	isDrawing = false;
	updateFirebase();
}

void canvasMouseMove(MouseEvent e) {
	mousePoint = e.offset;
	if (isDrawing) {
		paint(mousePoint);
	}
	centerBrush();
}