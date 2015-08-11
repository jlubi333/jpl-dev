import "dart:html";
import "dart:math";

const double PRECISION = 1000.0;

const int ENTER_KEY = 13;

const int T_KEY = 84;
const int X_KEY = 88;
const int Y_KEY = 89;
const int Z_KEY = 90;

const int M_KEY = 77;
const int N_KEY = 78;

const String CONTROLS = "controls";
const String OUTPUT = "output";
const String RATE_SELECTORS = "rateSelectors";
const String CALCULATE_BUTTON = "calculate";
const String FLIP_X = "flipX";
const String FLIP_Y = "flipY";
const String TRIANGLE_CANVAS = "triangle";
const String XS = "xs";
const String YS = "ys";
const String ZS = "zs";
const String THETAS = "thetas";

const String X = "x";
const String Y = "y";
const String Z = "z";
const String THETA = "theta";

const String DERIVATIVE_PREFIX = "d___";

const int TRIANGLE_SPEED = 300;

bool bigTriangle = true;

num xsLeft, xsTop, ysLeft, ysTop, zsLeft, zsTop, thetasLeft, thetasTop;

bool xFlipped = false;
bool yFlipped = false;

List<InputElement> inputs;
Element output;

Element xs;
Element ys;
Element zs;
Element thetas;

CanvasElement canvas;
CanvasRenderingContext2D ctx;

List<List<num>> triangleCoords;
List<List<num>> interpolateCoords;

// Values
Map<String, num> V = {};

Map<Relationship, Function> RELATION_DATABASE = {
	// X^2 + Y^2 = Z^2
	new Relationship(d(Z), [X, Y, d(X), d(Y)]): () => (V[X] * V[d(X)] + V[Y] * V[d(Y)]) / sqrt(pow(V[X], 2) + pow(V[Y], 2)),
	new Relationship(d(Y), [Z, X, d(Z), d(X)]): () => (V[Z] * V[d(Z)] - V[X] * V[d(X)]) / sqrt(pow(V[Z], 2) - pow(V[X], 2)),
	new Relationship(d(X), [Z, Y, d(Z), d(Y)]): () => (V[Z] * V[d(Z)] - V[Y] * V[d(Y)]) / sqrt(pow(V[Z], 2) - pow(V[Y], 2)),
	
	// sin(THETA) = Y/Z
	new Relationship(d(Z), [Y, THETA, d(Y), d(THETA)]): () => (sin(V[THETA]) * V[d(Y)] - V[Y] * cos(V[THETA]) * V[d(THETA)]) / pow(sin(V[X]), 2),
	new Relationship(d(Y), [Z, THETA, d(Z), d(THETA)]): () => V[d(Z)] * sin(V[THETA]) + cos(V[THETA]) * V[d(THETA)] * V[Z],
	new Relationship(d(THETA), [Y, Z, d(Y), d(Z)]): () => (V[Z] * V[d(Y)] - V[Y] * V[d(Z)]) / (pow(V[Z], 2) * sqrt(1 - pow(V[Y] / V[Z], 2))),
	
	// cos(THETA) = X/Z
	new Relationship(d(Z), [X, THETA, d(X), d(THETA)]): () => (cos(V[THETA]) * V[d(X)] - V[X] * -cos(V[THETA]) * V[d(THETA)]) / pow(cos(V[X]), 2),
	new Relationship(d(X), [Z, THETA, d(Z), d(THETA)]): () => V[d(Z)] * cos(V[THETA]) - cos(V[THETA]) * V[d(THETA)] * V[Z],
	new Relationship(d(THETA), [X, Z, d(X), d(Z)]): () => - ((V[Z] * V[d(X)] - V[X] * V[d(Z)]) / (pow(V[Z], 2) * sqrt(1 - pow(V[X] / V[Z], 2)))),
	
	// tan(THETA) = Y/X
	new Relationship(d(X), [Y, THETA, d(Y), d(THETA)]): () => (tan(V[THETA]) * V[d(Y)] - V[Y] * pow(1.0 / cos(V[THETA]), 2) * V[d(THETA)]) / pow(tan(V[THETA]), 2),
	new Relationship(d(Y), [X, THETA, d(X), d(THETA)]): () => V[d(X)] * tan(V[THETA]) + (1.0 / pow(cos(V[THETA]), 2)) * V[d(THETA)] * V[X],
	new Relationship(d(THETA), [X, Y, d(X), d(Y)]): () => (V[X] * V[d(Y)] - V[Y] * V[d(X)]) / (pow(V[X], 2) * (1 + pow(V[Y] / V[X], 2)))
};

// Derivative notation
String d(String s) {
	return DERIVATIVE_PREFIX + s;
}

num solve(Relationship r) {
	for(Relationship other in RELATION_DATABASE.keys) {
		if(r.satisfies(other)) {
			return RELATION_DATABASE[other]();
		}
	}
	return null;
}

void calculate() {
	for(InputElement ie in inputs) {
		V[ie.id]= ie.valueAsNumber;
	}
	
	if(V[X].isNaN && !(V[Y].isNaN || V[Z].isNaN)) {
		V[X] = sqrt(pow(V[Z], 2) - pow(V[Y], 2));
	} else if(V[Y].isNaN && !(V[X].isNaN || V[Z].isNaN)) {
		V[Y] = sqrt(pow(V[Z], 2) - pow(V[X], 2));
	} else if(V[Z].isNaN && !(V[X].isNaN || V[Y].isNaN)) {
		V[Z] = sqrt(pow(V[X], 2) + pow(V[Y], 2));
	}
	
	RadioButtonInputElement selectedRadio = querySelector("#" + RATE_SELECTORS + " input[type=radio]:checked");
	String result = "Not solvable.";
	String status = "error";
	if(selectedRadio != null) {
		num numericalResult = solve(new Relationship(selectedRadio.value, V.keys.where((String key) => !V[key].isNaN)));
		if(numericalResult != null && numericalResult.isFinite) {
			result = selectedRadio.parent.children[0].innerHtml + " is " + ((PRECISION * numericalResult).round() / PRECISION).toString();
			status = "success";
		}
	} else {
		result = "Please select a rate to find.";
	}
	output.innerHtml = result;
	output.className = status;
}

num angleArcX, angleArcY, angleArcRadius, angleArcStartAngle, angleArcEndAngle;
bool angleArcAnticlockwise;
void drawTriangle() {
	ctx
		..beginPath()
		..moveTo(triangleCoords[0][0], triangleCoords[0][1])
		..lineTo(triangleCoords[1][0], triangleCoords[1][1])
		..lineTo(triangleCoords[2][0], triangleCoords[2][1])
		..closePath()
		..stroke();
	
	angleArcRadius = (triangleCoords[2][0] - triangleCoords[1][0]).abs() / 16;
	
	if(angleArcRadius != 0) {
		angleArcX = triangleCoords[2][0];
		angleArcY = triangleCoords[2][1];
		angleArcEndAngle = atan((triangleCoords[1][1] - triangleCoords[0][1]) / (triangleCoords[2][0] - triangleCoords[1][0]));
		
		if(isTriangleLeft()) {
			angleArcStartAngle = PI;
			angleArcEndAngle += PI;
			angleArcAnticlockwise = false;
		} else {
			angleArcStartAngle = 0;
			angleArcAnticlockwise = true;
		}
		
		// Flip if on top
		if(!isTriangleBottom()) {
			angleArcAnticlockwise = !angleArcAnticlockwise;
		}
		
		ctx.beginPath();
		ctx.arc(angleArcX, angleArcY, angleArcRadius, angleArcStartAngle, angleArcEndAngle, angleArcAnticlockwise);
		ctx.stroke();
	}
}

num getTriangleSize() {
	return 160;
}

bool isTriangleLeft() {
	return triangleCoords[1][0] < canvas.width / 2;
}

bool isTriangleBottom() {
	return triangleCoords[1][1] > canvas.height / 2;
}

void flipTriangleX() {
	int modifier = xFlipped ? -1 : 1;
	num amount = modifier * getTriangleSize() * 2;
	interpolateCoords[0][1] += amount;
	interpolateCoords[1][1] -= amount;
	interpolateCoords[2][1] -= amount;
	xFlipped = !xFlipped;
}

void flipTriangleY() {
	int modifier = yFlipped ? 1 : -1;
	num amount = modifier * getTriangleSize() * 2;
	interpolateCoords[0][0] += amount;
	interpolateCoords[1][0] += amount;
	interpolateCoords[2][0] -= amount;
	yFlipped = !yFlipped;
}

void centerTriangle() {
	xFlipped = false;
	yFlipped = false;
	num centerX = canvas.width / 2;
	num centerY = canvas.height / 2;
	num size = getTriangleSize();
	interpolateCoords = [[centerX + size, centerY - size], [centerX + size, centerY + size], [centerX - size, centerY + size]];
	triangleCoords = [];
	for(int i = 0; i < interpolateCoords.length; i++) {
		triangleCoords.add([]);
		for(int j = 0; j < interpolateCoords[i].length; j++) {
			triangleCoords[i].add(interpolateCoords[i][j]);
		}
	}
		
	xsLeft = triangleCoords[0][0] - getTriangleSize() - xs.clientWidth / 2;
	ysTop = triangleCoords[0][1] + getTriangleSize() + ys.clientHeight / 2;
}

void resizeCanvas() {
	canvas.width = window.innerWidth;
	canvas.height = window.innerHeight;
}

num interpolate(num delta, num speed, num p1, num p2) {
	if((p2 - p1).abs() > speed * delta) {
		int modifier = p1 < p2 ? 1 : -1;
		return p1 + (modifier * speed * delta);
	} else {
		return p2;
	}
}

num previousTimestamp = 0, delta = 0;
void draw(num timestamp) {
	if(previousTimestamp == 0) {
		delta = timestamp;
	} else {
		delta = timestamp - previousTimestamp;
	}
	delta /= 1000;
	
	ctx.fillStyle = "#FFFFFF";
	ctx.strokeStyle = "#000000";
	
	ctx.fillRect(0, 0, canvas.width, canvas.height);
	
	for(int i = 0; i < triangleCoords.length; i++) {
		for(int j = 0; j < triangleCoords[i].length; j++) {
			triangleCoords[i][j] = interpolate(delta, TRIANGLE_SPEED, triangleCoords[i][j], interpolateCoords[i][j]);
		}
	}
	
	if(isTriangleLeft()) {
		ysLeft = triangleCoords[0][0] - ys.clientWidth - 10;
		zsLeft = canvas.width / 2 + 10;
		thetasLeft = triangleCoords[2][0] - thetas.clientWidth - 70;
	} else {
		ysLeft = triangleCoords[0][0] + 10;
		zsLeft = canvas.width / 2 - zs.clientWidth - 10;
		thetasLeft = triangleCoords[2][0] + 55;
	}
	
	if(isTriangleBottom()) {
		xsTop = triangleCoords[1][1] + 10;
		zsTop = canvas.height / 2 - zs.clientHeight;
		thetasTop = triangleCoords[1][1] - thetas.clientHeight;
	} else {
		xsTop = triangleCoords[1][1] - xs.clientHeight - 10;
		zsTop = canvas.height / 2;
		thetasTop = triangleCoords[1][1] + 10;
	}
	
	xs.style.left = xsLeft.toString() + "px";
	xs.style.top = xsTop.toString() + "px";
	
	ys.style.left = ysLeft.toString() + "px";
	ys.style.top = ysTop.toString() + "px";
	
	zs.style.left = zsLeft.toString() + "px";
	zs.style.top = zsTop.toString() + "px";
	
	thetas.style.left = thetasLeft.toString() + "px";
	thetas.style.top = thetasTop.toString() + "px";
	
	drawTriangle();
	
	previousTimestamp = timestamp;
	window.animationFrame.then(draw);
}

void main() {
	inputs = querySelectorAll("#" + CONTROLS + " input[type=number]");
	output = querySelector("#" + OUTPUT);
	
	List<RadioButtonInputElement> radios = querySelectorAll("#" + RATE_SELECTORS + " input[type=radio]");
	radios.forEach((RadioButtonInputElement radio) => radio.onClick.listen((MouseEvent e) {
		NumberInputElement disabledNumberInputElement = querySelector("#" + radio.value);
		for(NumberInputElement n in inputs) {
			n.disabled = false;
		}
		disabledNumberInputElement.value = "";
		disabledNumberInputElement.disabled = true;
	}));
	
	for(InputElement input in inputs) {
		input.onKeyDown.listen((KeyboardEvent e) {
			if(e.keyCode == ENTER_KEY) {
				calculate();
			}
		});
	}
	
	querySelector("#" + CALCULATE_BUTTON).onClick.listen((MouseEvent e) => calculate());
	
	canvas = querySelector("#" + TRIANGLE_CANVAS);
	resizeCanvas();
	ctx = canvas.getContext("2d");
	
	window.onResize.listen((Event e) {
		resizeCanvas();
		centerTriangle();
	});
	
	window.onKeyDown.listen((KeyboardEvent e) {
		if([X_KEY, Y_KEY, Z_KEY, T_KEY].contains(e.keyCode)) {
			e.preventDefault();
			
			String selectedRate;
			if(e.keyCode == X_KEY) {
				selectedRate = d(X);
			} else if(e.keyCode == Y_KEY) {
				selectedRate = d(Y);
			} else if(e.keyCode == Z_KEY) {
				selectedRate = d(Z);
			} else if(e.keyCode == T_KEY) {
				selectedRate = d(THETA);
			}
			
			RadioButtonInputElement r = querySelector("#rad_" + selectedRate);
			if(r != null) {
				r.click();
			}
		} else if([N_KEY, M_KEY].contains(e.keyCode)) {
			e.preventDefault();
			if(e.keyCode == N_KEY) {
				flipTriangleY();
			} else if(e.keyCode == M_KEY) {
				flipTriangleX();
			}
		}
	});
	
	querySelector("#" + FLIP_X).onClick.listen((MouseEvent e) => flipTriangleX());
	querySelector("#" + FLIP_Y).onClick.listen((MouseEvent e) => flipTriangleY());
	
	xs = querySelector("#" + XS);
	ys = querySelector("#" + YS);
	zs = querySelector("#" + ZS);
	thetas = querySelector("#" + THETAS);
	[xs, ys, zs, thetas].forEach((Element e) => e.style.visibility = "visible");
	
	centerTriangle();
	
	window.animationFrame.then(draw);
}

class Relationship {
	String result;
	Set<String> dependencies;
	
	Relationship(this.result, Iterable<String> dependencies) {
		this.dependencies = new Set.from(dependencies);
	}
	
	bool satisfies(Relationship other) {
		return this.result == other.result && this.dependencies.intersection(other.dependencies).containsAll(other.dependencies);
	}
}