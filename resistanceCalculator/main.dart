import "dart:html";
import "dart:async";
import "dart:math" as math;

// KEY CODES \\
// 13 => Enter
// 27 => Escape

const int NORMAL_STYLE = 0;
const int SELECTED_RESISTOR_STYLE = 1;
const int RIGHT_CLICK_DRAG_STYLE = 2;
const int RIGHT_CLICK_CORRECT_DRAG_STYLE = 3;
const int CIRCUIT_DRAG_CONFIRM_STYLE = 4;
const int CIRCUIT_OUTLINE_STYLE = 5;
const int CIRCUIT_SELECTED_OUTLINE_STYLE = 6;
const int TRASH_CAN_STYLE = 7;
const int PENDING_DELETE_STYLE = 8;
const int PENDING_DELETE_OUTLINE_STYLE = 9;

const int PADDING = 20;
const String FONT = "Roboto";

const int DEFAULT_RESISTANCE = 100;

CanvasElement canvas;
CanvasRenderingContext2D ctx;

Element contextualMenu;

Element resistanceSetter;
NumberInputElement rsInput;
ButtonInputElement resistanceSetterButton;

ButtonInputElement addSeries;
NumberInputElement addSeriesNumber;
ButtonInputElement addParallel;
NumberInputElement addParallelNumber;

List<Circuit> diagram;

BoundingBox trashCan;
Circuit circuitToRemove;

StreamSubscription circuitDragSubscription;
Circuit draggedCircuit;
num relativeDragPositionX;
num relativeDragPositionY;

Resistor selectedResistor;

num mouseX = 0;
num mouseY = 0;

bool leftClickDragging = false;

num rightClickStartX = 0;
num rightClickStartY = 0;
bool rightClickDragging = false;
bool correctDrag = false;
Circuit connectionDragStartCircuit;
Circuit connectionDragEndCircuit;

void main() {
	canvas = querySelector("#circuitBoard");
	canvas.tabIndex = 9001;
	canvas.width = window.innerWidth;
	canvas.height = window.innerHeight;
	ctx = canvas.getContext("2d");
	
	trashCan = new BoundingBox(canvas.width - 110, 10, 100, 100);
	
	contextualMenu = querySelector("#contextualMenu");
	
	resistanceSetter = querySelector("#resistanceSetter");
	rsInput = querySelector("#rsInput");
	resistanceSetterButton = querySelector("#setResistance");
	
	addSeries = querySelector("#addSeries");
	addSeriesNumber = querySelector("#addSeriesNumber") as NumberInputElement;
	addParallel = querySelector("#addParallel");
	addParallelNumber = querySelector("#addParallelNumber") as NumberInputElement;
	
	diagram = [];
	
	Timer updateTimer = new Timer.periodic(Duration.ZERO, update);
	Timer drawTimer = new Timer.periodic(Duration.ZERO, draw);
	
	canvas.onMouseDown.listen(canvasMouseDown);
	canvas.onMouseUp.listen(canvasMouseUp);
	canvas.onDoubleClick.listen(canvasDoubleClick);
	canvas.onMouseMove.listen(canvasMouseMove);
	
	window.onContextMenu.listen((MouseEvent e) => e.preventDefault());
	window.onResize.listen((Event e) {
		canvas.width = window.innerWidth;
		canvas.height = window.innerHeight;
		trashCan.x = canvas.width - 110;
	});
	
	rsInput.onKeyDown.listen((KeyboardEvent e) {
		if(e.keyCode == 13) {
			setResistance(null);
		} else if(e.keyCode == 27) {
			selectedResistor = null;
		}
	});
	resistanceSetterButton.onClick.listen(setResistance);
	
	addSeries.onClick.listen(addSeriesClick);
	addParallel.onClick.listen(addParallelClick);
	
	addSeriesNumber.onKeyDown.listen((KeyboardEvent e) {
		if(e.keyCode == 13) {
			addSeriesClick(null);
		} else if(e.keyCode == 27) {
			addSeriesNumber.value = "";
		}
	});
	
	addParallelNumber.onKeyDown.listen((KeyboardEvent e) {
		if(e.keyCode == 13) {
			addParallelClick(null);
		} else if(e.keyCode == 27) {
			addParallelNumber.value = "";
		}
	});
}

void update(Timer timer) {	
	for(Circuit c in diagram) {
		c.update();
	}
	 
	if(selectedResistor != null) {
		if(selectedResistor.boundingBox.y > 100) {
			showResistanceSelector(selectedResistor.boundingBox.x + selectedResistor.boundingBox.width / 2,
				selectedResistor.boundingBox.y,
				false);
		} else {
			showResistanceSelector(selectedResistor.boundingBox.x + selectedResistor.boundingBox.width / 2,
				selectedResistor.boundingBox.y + selectedResistor.boundingBox.height,
				true);
		}
	} else {
		hideResistanceSelector();
	}
	
	if(rightClickDragging) {
		correctDrag = false;
		connectionDragEndCircuit = null;
		for(Circuit c in diagram) {
			if(c != connectionDragStartCircuit && c.boundingBox.containsWithPadding(mouseX, mouseY, PADDING)) {
				correctDrag = true;
				connectionDragEndCircuit = c;
				break;
			}
		}
	}
}

void draw(Timer timer) {
	ctx.clearRect(0, 0, canvas.width, canvas.height);
	
	// Trash can
	styleCtx(TRASH_CAN_STYLE);
	trashCan.draw();
	ctx
		..beginPath()
		..moveTo(trashCan.x + 20, trashCan.y + 20)
		..lineTo(trashCan.x + trashCan.width - 20, trashCan.y + trashCan.height - 20)
		..moveTo(trashCan.x + trashCan.width - 20, trashCan.y + 20)
		..lineTo(trashCan.x + 20, trashCan.y + trashCan.height - 20)
		..stroke();
	
	for(Circuit c in diagram) {
		if(c == connectionDragStartCircuit || c == connectionDragEndCircuit) {
			styleCtx(CIRCUIT_DRAG_CONFIRM_STYLE);
		} else if(c == draggedCircuit && trashCan.contains(mouseX, mouseY)) {
			styleCtx(PENDING_DELETE_STYLE);
		} else {
			styleCtx(NORMAL_STYLE);
		}
		c.draw();
	}
	
	// Render outline and resistance after (on top of) the circuits
	for(Circuit c in diagram) {
		if(c == connectionDragStartCircuit || c == connectionDragEndCircuit) {
			styleCtx(CIRCUIT_SELECTED_OUTLINE_STYLE);
		} else if(c == draggedCircuit && trashCan.contains(mouseX, mouseY)) {
			styleCtx(PENDING_DELETE_OUTLINE_STYLE);
		} else {
			styleCtx(CIRCUIT_OUTLINE_STYLE);
		}
		c.boundingBox.drawWithPadding(PADDING);
		
		ctx.font = "25px " + FONT;
		ctx.fillText(c.calculateResistance().toStringAsFixed(2) + "Ω", c.boundingBox.x - PADDING, c.boundingBox.y + c.boundingBox.height + PADDING + 25);
	}
	
	if(rightClickDragging) {
		if(correctDrag) {
			styleCtx(RIGHT_CLICK_CORRECT_DRAG_STYLE);
		} else {
			styleCtx(RIGHT_CLICK_DRAG_STYLE);
		}
		ctx
			..beginPath()
			..arc(rightClickStartX, rightClickStartY, 5, 0, 2 * math.PI, false)
			..arc(mouseX, mouseY, 5, 0, 2 * math.PI, false)
			..fill()
			..beginPath()
			..moveTo(rightClickStartX, rightClickStartY)
			..lineTo(mouseX, mouseY)
			..stroke();
	}
}

void canvasMouseDown(MouseEvent e) {
	hideContextualMenu();
	
	if(!rightClickDragging) {
		connectionDragStartCircuit = null;
		connectionDragEndCircuit = null;
	}
	
	if(e.button == 0) {
		leftClickDragging = true;
		if(!rightClickDragging) {
			for(Circuit c in diagram) {
				if(c.boundingBox.containsWithPadding(e.offset.x, e.offset.y, PADDING)) {
					draggedCircuit = c;
					relativeDragPositionX = (e.offset.x - c.boundingBox.x).abs();
					relativeDragPositionY = (e.offset.y - c.boundingBox.y).abs();
					circuitDragSubscription = canvas.onMouseMove.listen(circuitDragged);
					break;
				}
			}
		}
		
		if(selectedResistor != null && !selectedResistor.boundingBox.containsWithPadding(e.offset.x, e.offset.y, PADDING)) {
			selectedResistor = null;
		}
	} else if(e.button == 2) {
		e.preventDefault();
		
		if(!leftClickDragging) {
			for(Circuit c in diagram) {
				if(c.boundingBox.containsWithPadding(e.offset.x, e.offset.y, 10)) {
					rightClickStartX = e.offset.x;
					rightClickStartY = e.offset.y;
					rightClickDragging = true;
					connectionDragStartCircuit = c;
				}
			}
		}
	}
}

void canvasMouseUp(MouseEvent e) {
	if(e.button == 0) {
		leftClickDragging = false;
		
		if(circuitDragSubscription != null) {
			circuitDragSubscription.cancel();
			if(trashCan.contains(e.offset.x, e.offset.y)) {
				diagram.remove(draggedCircuit);
			}
			draggedCircuit = null;
		}
	}
	else if(e.button == 2) {	
		if(correctDrag) {
			showContextualMenu(e.offset.x, e.offset.y, ["Serial Connection", "Parallel Connection"],
				[(e) {
					mergeSerial(connectionDragStartCircuit, connectionDragEndCircuit);
					connectionDragStartCircuit = null;
					connectionDragEndCircuit = null;
				}, (e) {
					mergeParallel(connectionDragStartCircuit, connectionDragEndCircuit);
					connectionDragStartCircuit = null;
					connectionDragEndCircuit = null;
				}]);
		} else {
			connectionDragStartCircuit = null;
		}
				
		rightClickDragging = false;
		correctDrag = false;
	}
}

void canvasDoubleClick(MouseEvent e) {
	Resistor r = getSelectedResistor(diagram, e.offset.x, e.offset.y);
	selectedResistor = r;
	
	if(selectedResistor == null) {
		diagram.add(new Resistor.atPoint(DEFAULT_RESISTANCE, e.offset.x, e.offset.y));
	}
}

Resistor getSelectedResistor(List<Circuit> circuitList, num x, num y) {
	for(Circuit c in circuitList) {
		if(c.boundingBox.containsWithPadding(x, y, PADDING)) {
			if(c is ContainerCircuit) {
				return getSelectedResistor((c as ContainerCircuit).circuits, x, y);
			} else if(c is Resistor) {
				return c;
			}
		}
	}
	return null;
}

void canvasMouseMove(MouseEvent e) {
	mouseX = e.offset.x;
	mouseY = e.offset.y;
}

void circuitDragged(MouseEvent e) {
	draggedCircuit.boundingBox.x = e.offset.x - relativeDragPositionX;
	draggedCircuit.boundingBox.y = e.offset.y - relativeDragPositionY;
}

void setResistance(MouseEvent e) {
	if(rsInput.valueAsNumber.isNaN) {
		invalidNumberAlert();
		return;
	}
	
	selectedResistor._resistance = rsInput.valueAsNumber;
	rsInput.value = "";
	selectedResistor = null;
}

void addSeriesClick(MouseEvent e) {
	if(addSeriesNumber.valueAsNumber.isNaN) {
		invalidNumberAlert();
		return;
	}
	List<Circuit> cs = new List<Circuit>();
	for(int i = 0; i < addSeriesNumber.valueAsNumber.toInt(); i++) {
		cs.add(new Resistor(DEFAULT_RESISTANCE));
	}
	diagram.add(new Serial(cs, 200, 200));
	addSeriesNumber.value = "";
}

void addParallelClick(MouseEvent e) {
	if(addParallelNumber.valueAsNumber.isNaN) {
		invalidNumberAlert();
		return;
	}
	List<Circuit> cs = new List<Circuit>();
	for(int i = 0; i < addParallelNumber.valueAsNumber.toInt(); i++) {
		cs.add(new Resistor(DEFAULT_RESISTANCE));
	}
	diagram.add(new Parallel(cs, 200, 200));
	addParallelNumber.value = "";
}

void invalidNumberAlert() {
	window.alert("Your input must be a valid number!");
}

void styleCtx(int ctxStyle) {
	if(ctxStyle == NORMAL_STYLE) {
		ctx.fillStyle = "#000000";
		ctx.strokeStyle = "#000000";
		ctx.lineWidth = 1;
	} else if(ctxStyle == SELECTED_RESISTOR_STYLE) {
		ctx.fillStyle = "#000000";
		ctx.strokeStyle = "#0000FF";
		ctx.lineWidth = 3;
	} else if(ctxStyle == RIGHT_CLICK_DRAG_STYLE) {
		ctx.fillStyle = "#FF0000";
		ctx.strokeStyle = "#FF0000";
		ctx.lineWidth = 3;
	} else if(ctxStyle == RIGHT_CLICK_CORRECT_DRAG_STYLE) {
		ctx.fillStyle = "#00FF00";
		ctx.strokeStyle = "#00FF00";
		ctx.lineWidth = 3;
	} else if(ctxStyle == CIRCUIT_DRAG_CONFIRM_STYLE) {
		ctx.fillStyle = "#000000";
		ctx.strokeStyle = "#007700";
		ctx.lineWidth = 2;
	} else if(ctxStyle == CIRCUIT_OUTLINE_STYLE) {
		ctx.fillStyle = "#000000";
		ctx.strokeStyle = "#CCCCCC";
		ctx.lineWidth = 1;
	} else if(ctxStyle == CIRCUIT_SELECTED_OUTLINE_STYLE) {
		ctx.fillStyle = "#000000";
		ctx.strokeStyle = "#AACCAA";
		ctx.lineWidth = 1;
	} else if(ctxStyle == TRASH_CAN_STYLE) {
		ctx.fillStyle = "#000000";
		ctx.strokeStyle = "#FF0000";
		ctx.lineWidth = 2;
	} else if(ctxStyle == PENDING_DELETE_STYLE) {
		ctx.fillStyle = "#000000";
		ctx.strokeStyle = "#FF0000";
		ctx.lineWidth = 1;
	} else if(ctxStyle == PENDING_DELETE_OUTLINE_STYLE) {
		ctx.fillStyle = "#000000";
		ctx.strokeStyle = "#550000";
		ctx.lineWidth = 1;
	}
}

void showContextualMenu(num x, num y, List<String> options, List<Function> callbacks) {
	contextualMenu.children.clear();
	LIElement li;
	for(int i = 0; i < options.length; i++) {
		li = new LIElement();
		li.innerHtml = options[i];
		li.onClick.listen((e) => hideContextualMenu());
		li.onClick.listen(callbacks[i]);
		contextualMenu.append(li);
	}
	
	contextualMenu.style.left = x.toString() + "px";
	contextualMenu.style.top = y.toString() + "px";
	contextualMenu.style.display = "block";
}

void hideContextualMenu() {
	contextualMenu.style.display = "none";
}

void showResistanceSelector(num x, num y, bool reverse) {
	resistanceSetter.style.display = "block";

	// triangle is 10 pixels + 5 pixels of padding = offset of 15
	if(reverse) {
		querySelector("#rsTriangleBorder").className = "upTriangleBorder";
		querySelector("#rsTriangle").className = "upTriangle";
		resistanceSetter.style.top = (y + 15).toString() + "px"; 
	} else {
		querySelector("#rsTriangleBorder").className = "downTriangleBorder";
		querySelector("#rsTriangle").className = "downTriangle";
		resistanceSetter.style.top = (y - resistanceSetter.offsetHeight - 15).toString() + "px";
	}
	
	resistanceSetter.style.left = (x - resistanceSetter.offsetWidth / 2).toString() + "px";
	
	rsInput.focus();
}

void hideResistanceSelector() {
	resistanceSetter.style.display = "none";
	rsInput.value = "";
}

void mergeSerial(Circuit c1, Circuit c2) {
	if(c1 is Serial && c2 is Serial) {
		diagram.remove(c2);
		for(Circuit c in c2.circuits) {
			c1.circuits.add(c);
		}
	}
	else if(c1 is Serial) {
		diagram.remove(c2);
		c1.circuits.add(c2);
	}
	else if(c2 is Serial) {
		diagram.remove(c1);
		c2.boundingBox.x = c1.boundingBox.x;
		c2.boundingBox.y = c1.boundingBox.y;
		c2.circuits.insert(0, c1);
	}
	else {
		diagram.remove(c1);
		diagram.remove(c2);
		diagram.add(new Serial([c1, c2], c1.boundingBox.x, c1.boundingBox.y));
	}
}

void mergeParallel(Circuit c1, Circuit c2) {
	if(c1 is Parallel && c2 is Parallel) {
		diagram.remove(c2);
		for(Circuit c in c2.circuits) {
			c1.circuits.add(c);
		}
	}
	else if(c1 is Parallel) {
		diagram.remove(c2);
		c1.circuits.add(c2);
	}
	else if(c2 is Parallel) {
		diagram.remove(c1);
		c2.boundingBox.x = c1.boundingBox.x;
		c2.boundingBox.y = c1.boundingBox.y;
		c2.circuits.insert(0, c1);
	}
	else {
		diagram.remove(c1);
		diagram.remove(c2);
		diagram.add(new Parallel([c1, c2], c1.boundingBox.x, c1.boundingBox.y));
	}
}

// *** Classes *** \\\

class BoundingBox {
	num x, y, width, height;
	
	BoundingBox(this.x, this.y, this.width, this.height);
	
	bool contains(num x, num y) {
		return containsWithPadding(x, y, 0);
	}
	
	bool containsWithPadding(num x, num y, num padding) {
		return (x >= this.x - padding
			&& x <= this.x + width + padding
			&& y >= this.y - padding
			&& y <= this.y + height + padding);
	}
	
	void draw() {
		drawWithPadding(0);
	}
	
	void drawWithPadding(num padding) {
		ctx
			..beginPath()
			..strokeRect(x - padding, y - padding, width + 2 * padding, height + 2 * padding);
	}
}

// Circuit \\

abstract class Circuit {
	static final int hitboxSize = 20;
	
	BoundingBox boundingBox;
	double calculateResistance();
	void draw();
	
	void update() {}
}

abstract class ContainerCircuit {
	List<Circuit> circuits;
}

class Serial extends Circuit implements ContainerCircuit {
	List<Circuit> circuits;
	
	Serial(this.circuits, num x, num y) {
		boundingBox = new BoundingBox(x, y, 0, 0);
		update();		
	}
	
	@override
	double calculateResistance() {
		double resistance = 0.0;
		for(Circuit c in circuits) {
			resistance += c.calculateResistance();
		}
		
		return resistance;
	}
	
	@override
	void update() {
		num maxHeight = 0;
		for(Circuit c in circuits) {
			if(c.boundingBox.height > maxHeight) {
				maxHeight = c.boundingBox.height;
			}
		}
		boundingBox.height = maxHeight;
		
		num currentX = 0;
		for(Circuit c in circuits) {
			c.boundingBox.x = boundingBox.x + currentX;
			c.boundingBox.y = boundingBox.y + boundingBox.height / 2 - c.boundingBox.height / 2;
			
			currentX += c.boundingBox.width;
		}
		boundingBox.width = currentX;
		
		for(Circuit c in circuits) {
			c.update();
		}
		
		super.update();
	}
	
	@override
	void draw() {
		for(Circuit c in circuits) {
			c.draw();
		}
	}
}

class Parallel extends Circuit implements ContainerCircuit {
	static final num verticalPadding = 50;
	static final num horizontalOutreach = 20;
	
	List<Circuit> circuits;
	
	Parallel(this.circuits, num x, num y) {
		boundingBox = new BoundingBox(x, y, 0, 0);
		update();
	}
	
	@override
	double calculateResistance() {
		double resistance = 0.0;
		for(Circuit c in circuits) {
			resistance += 1.0 / c.calculateResistance();
		}
		return 1.0 / resistance;
	}
	
	@override
	void update() {	
		num maxWidth = 0;
		for(Circuit c in circuits) {
			if(c.boundingBox.width > maxWidth) {
				maxWidth = c.boundingBox.width;
			}
		}
		boundingBox.width = maxWidth + 2 * horizontalOutreach;
		
		num currentY = 0;
		for(Circuit c in circuits) {
			c.boundingBox.x = boundingBox.x + boundingBox.width / 2 - c.boundingBox.width / 2;
			c.boundingBox.y = boundingBox.y + currentY;
			
			currentY += c.boundingBox.height + verticalPadding;
		}
		
		boundingBox.height = currentY - verticalPadding;
		
		for(Circuit c in circuits) {
			c.update();
		}
		
		super.update();
	}
	
	@override
	void draw() {
		ctx
			..beginPath()
			..moveTo(boundingBox.x + horizontalOutreach, boundingBox.y + circuits[0].boundingBox.height / 2)
			..lineTo(boundingBox.x + horizontalOutreach, boundingBox.y + boundingBox.height - circuits[circuits.length - 1].boundingBox.height / 2)
			
			..moveTo(boundingBox.x + boundingBox.width - horizontalOutreach, boundingBox.y + circuits[0].boundingBox.height / 2)
			..lineTo(boundingBox.x + boundingBox.width - horizontalOutreach, boundingBox.y + boundingBox.height - circuits[circuits.length - 1].boundingBox.height / 2)
			
			..moveTo(boundingBox.x, boundingBox.y + boundingBox.height / 2)
			..lineTo(boundingBox.x + horizontalOutreach, boundingBox.y + boundingBox.height / 2)
			
			..moveTo(boundingBox.x + boundingBox.width, boundingBox.y + boundingBox.height / 2)
			..lineTo(boundingBox.x + boundingBox.width - horizontalOutreach, boundingBox.y + boundingBox.height / 2)
			
			..stroke();
		for(Circuit c in circuits) {
			ctx
				..beginPath()
				..moveTo(c.boundingBox.x, c.boundingBox.y + c.boundingBox.height / 2)
				..lineTo(boundingBox.x + horizontalOutreach, c.boundingBox.y + c.boundingBox.height / 2)
				
				..moveTo(c.boundingBox.x + c.boundingBox.width, c.boundingBox.y + c.boundingBox.height / 2)
				..lineTo(boundingBox.x + boundingBox.width - horizontalOutreach, c.boundingBox.y + c.boundingBox.height / 2)
				..stroke();
			c.draw();
		}
	}
}

class Resistor extends Circuit {
	static final num defaultWidth = 100;
	static final num defaultHeight = 30;
	
	num _resistance;
	
	Resistor(num _resistance) : this.atPoint(_resistance, 0, 0);
	
	Resistor.atPoint(this._resistance, num x, num y) {
		boundingBox = new BoundingBox(x, y, defaultWidth, defaultHeight);
		super.update();
	}
	
	@override
	double calculateResistance() {
		return _resistance.toDouble();
	}
	
	@override
	void draw() {
		ctx.save();
		if(this == selectedResistor) {
			styleCtx(SELECTED_RESISTOR_STYLE);
		}
		ctx
			..beginPath()
			..moveTo(boundingBox.x, boundingBox.y + defaultHeight / 2)
			..lineTo(boundingBox.x + 20, boundingBox.y + defaultHeight / 2)
			..lineTo(boundingBox.x + 25, boundingBox.y)
			..lineTo(boundingBox.x + 35, boundingBox.y + defaultHeight)
			..lineTo(boundingBox.x + 45, boundingBox.y)
			..lineTo(boundingBox.x + 55, boundingBox.y + defaultHeight)
			..lineTo(boundingBox.x + 65, boundingBox.y)
			..lineTo(boundingBox.x + 75, boundingBox.y + defaultHeight)
			..lineTo(boundingBox.x + 80, boundingBox.y + defaultHeight / 2)
			..lineTo(boundingBox.x + 100, boundingBox.y + defaultHeight / 2)
			..stroke();
		String res = calculateResistance().toStringAsFixed(2) + "Ω";
		ctx.font = "12px " + FONT;
		ctx.fillText(res, boundingBox.x + boundingBox.width / 2 - ctx.measureText(res).width / 2, boundingBox.y + boundingBox.height + PADDING - 6);
		ctx.restore();
	}
}