import "dart:html";
import "dart:async";
import "dart:math";
import "dart:web_audio";
import "package:firebase/firebase.dart" as fb;

const List<String> COLOR_LETTERS = const ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"];

const String PRIVATE_ROOM = "%";

const int MAX_TIMEOUT = 3;

const num MOUSE_SIZE = 32;

const num GRAVITY = Tile.SIZE * 30;

const num DT = 1000 / 60;

// 0b01
const int X_COLLISION_MASK = 1;
// 0b10
const int Y_COLLISION_MASK = 2;

const int TILE_FG_STYLE = 0;
const int TILE_BG_STYLE = 1;
const int COIN_STYLE = 2;

const int PLAYER_TYPE = 0;
const int IDIOT_ENEMY_TYPE = 1;
const int PREDA_TYPE = 2;
const int PROJECTILE_TYPE = 3;
const int VECTOR_TYPE = 4;
const int BOUNDING_BOX_TYPE = 5;

const int ENTER_KEY = 13;
const int SPACEBAR_KEY = 32;
const int NUMBER_SIGN_KEY = 35;
const int DOLLAR_SIGN_KEY = 36;
const int PERIOD_KEY = 46;
const int NINE_KEY = 57;
const int A_KEY = 65;
const int D_KEY = 68;
const int R_KEY = 82;
const int S_KEY = 83;
const int T_KEY = 84;
const int W_KEY = 87;
const int X_KEY = 88;
const int LEFT_BRACKET_KEY = 91;
const int RIGHT_BRACKET_KEY = 93;

Random randomizer = new Random();

Map<int, bool> keys = {
};

Vector mousePosition;

CanvasElement canvas;
CanvasRenderingContext2D ctx;

ImageElement cursorImage = new ImageElement();

List<List<Tile>> tiles = [];

int timeoutCounter = 0;

AudioContext audioContext = new AudioContext();
Sound bgMusic = new Sound.silent(), hitSound = new Sound.silent(), dieSound = new Sound.silent(), predaSpawnSound = new Sound.silent();

fb.Firebase rootFirebaseRef;
fb.Firebase mainFirebaseRef;
fb.Firebase myFirebaseRef;
fb.Firebase eventFirebaseRef;
List<Entity> entities = [];
List<Entity> foreignEntities = [];
Map<Entity, fb.Firebase> entityRefs = {
};
Map<int, String> pendingEventsFromCloud = {
};
Player myPlayer;

bool magicColor = false;

// Readies
bool cursorReady = false;

void main() {
	TextInputElement roomNameInput = querySelector("#roomNameInput");
	TextInputElement usernameInput = querySelector("#usernameInput");
	InputElement colorInput = querySelector("#colorInput");
	ButtonElement startButton = querySelector("#startButton");

	[roomNameInput, usernameInput].forEach((TextInputElement tie) => tie.onKeyPress.listen((KeyboardEvent e) {
		if (e.keyCode == ENTER_KEY) {
			startButton.click();
		} else if ([PERIOD_KEY, NUMBER_SIGN_KEY, DOLLAR_SIGN_KEY, LEFT_BRACKET_KEY, RIGHT_BRACKET_KEY].contains(e.keyCode)) {
			e.preventDefault();
		}
	}));

	startButton.onClick.listen((MouseEvent e) {
		String roomName = firebaseSanitize(roomNameInput.value);
		String username = firebaseSanitize(usernameInput.value);
		String color = colorInput.value.replaceAll("#", "");

		if (roomName.length == 0) {
			window.alert("Please enter a room name.");
			return;
		} else if (username.length == 0) {
			window.alert("Please enter a usernname.");
			return;
		}

		String colorTester = color.toUpperCase();
		COLOR_LETTERS.forEach((String s) {
			colorTester = colorTester.replaceAll(s.toUpperCase(), "");
		});
		if (color.length != 6 || colorTester.length != 0) {
			window.alert("Please enter a valid color.");
			return;
		}

		startGame(roomName, username, "#" + color);
	});

	rootFirebaseRef = new fb.Firebase("https://jpl-platformer.firebaseio.com/");

	SelectElement roomSelection = querySelector("#roomSelection");
	roomSelection.onChange.listen((Event e) {
		if (roomSelection.selectedIndex == 0) {
			roomNameInput.value = "";
			return;
		}
		roomNameInput.value = roomSelection.children[roomSelection.selectedIndex].children[0].text;
	});

	StreamSubscription<fb.Event> firstFirebaseDataSubscription = rootFirebaseRef.onValue.listen(null);
	firstFirebaseDataSubscription.onData((fb.Event data) {
		OptionElement statusOption = querySelector("#statusOption");
		OptionElement loadingOption = querySelector("#loadingOption");
		if (loadingOption != null) {
			loadingOption.remove();
		}
		fb.DataSnapshot snapshot = data.snapshot;
		Map rooms = null;
		// Ghetto JavaScript fix :'c
		if (data.snapshot.hasChildren) {
			rooms = data.snapshot.val();
		}
		if (rooms == null || rooms.keys.where((String room) => !(room.startsWith(PRIVATE_ROOM) && room.endsWith(PRIVATE_ROOM))).length == 0) {
			roomSelection.children[0].text = "No Open Rooms";
			roomSelection.disabled = true;
			return;
		}
		for (String room in rooms.keys) {
			if (room.startsWith(PRIVATE_ROOM) && room.endsWith(PRIVATE_ROOM)) {
				continue;
			}
			OptionElement roomOption = new OptionElement();
			SpanElement roomNameSpan = new SpanElement();
			roomNameSpan.text = room;
			roomOption.children.add(roomNameSpan);
			roomOption.innerHtml += " (" + rooms[room].length.toString() + ")";
			roomSelection.children.add(roomOption);
		}
		firstFirebaseDataSubscription.cancel();
	});

	// Cursor \\

	cursorImage.onLoad.listen((Event e) {
		cursorReady = true;
	});
	cursorImage.src = "cursor.png";

	Sound.loadSound(hitSound, "hit.wav");
	Sound.loadSound(dieSound, "die.wav");
	Sound.loadSound(predaSpawnSound, "predaSpawnSound.wav");
}

String firebaseSanitize(String s) {
	s = s.replaceAll(".", "");
	s = s.replaceAll("#", "");
	s = s.replaceAll("\$", "");
	s = s.replaceAll("[", "");
	s = s.replaceAll("]", "");
	return s;
}

void startGame(String roomName, String username, String playerColor) {
	// Background Music \\
	Sound.loadSound(bgMusic, "bg.ogg", play: true, volume: 0.5, loop: true);

	// Setup \\

	querySelector("#preGameContainer").style.display = "none";
	querySelector("#gameContainer").style.display = "block";
	querySelector("#roomName").innerHtml = roomName;
	querySelector("#username").innerHtml = username;

	canvas = querySelector("#game");
	canvas.width = window.innerWidth;
	canvas.height = window.innerHeight;
	ctx = canvas.getContext("2d");
	ctx.font = "16px Roboto";

	List<List<int>> map = [
			[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
			[1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 2],
			[1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0],
			[1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0],
			[1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0],
			[1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0],
			[1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0],
			[1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0],
			[1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0],
			[1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0],
			[1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0],
			[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0],
			[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 0],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0],
			[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0],
			[1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	];

	for (int r = 0; r < map.length; r++) {
		tiles.add([]);
		for (int c = 0; c < map[r].length; c++) {
			tiles[r].add(new Tile(map[r][c], map[r][c] == 1));
		}
	}

	// Multiplayer \\

	mainFirebaseRef = rootFirebaseRef.child(roomName);
	myFirebaseRef = mainFirebaseRef.push();
	eventFirebaseRef = mainFirebaseRef.child("events");

	mainFirebaseRef.onValue.listen((fb.Event data) {
		fb.DataSnapshot snapshot = data.snapshot;
		Map val = data.snapshot.val();
		if (val == null) {
			return;
		}
		entities = [];
		foreignEntities = [];
		val.forEach((connectionName, info) {
			bool isMine = connectionName == myFirebaseRef.key;
			info.forEach((entityName, jsonMap) {
				Entity e = readEntity(jsonMap);
				if (e != null) {
					if (isMine) {
						if (e is Player) {
							myPlayer = e;
						}
						entities.add(e);
					} else {
						foreignEntities.add(e);
					}
					entityRefs[e] = snapshot.child(connectionName).child(entityName).ref();
				}
			});
		});
	});
	eventFirebaseRef.onChildAdded.listen((fb.Event data) {
		Map val = data.snapshot.val();
		pendingEventsFromCloud[val["EntityUID"]] = val["EventType"];
		data.snapshot.ref().remove();
	});
	// TODO Is the player lagged out?
//	myFirebaseRef.onValue.listen((fb.Event data) {
//		if(data.snapshot.numChildren() == 0) {
//			timeoutCounter += 1;
//		} else {
//			timeoutCounter = 0;
//		}
//	});
	myFirebaseRef.onDisconnect.remove();

	myPlayer = new Player(username, playerColor, new BoundingBox(2 * Tile.SIZE, 1 * Tile.SIZE, Tile.SIZE, Tile.SIZE), Tile.SIZE * 6, 15);
	addEntity(myPlayer);

	// Event Handlers \\

	window.onContextMenu.listen((MouseEvent e) => e.preventDefault());

	window.onResize.listen((Event e) {
		canvas.width = window.innerWidth;
		canvas.height = window.innerHeight;
	});

	Element controls = querySelector("#controls");
	window.onKeyDown.listen((KeyboardEvent e) {
		keys[e.keyCode] = true;

		if (e.keyCode == X_KEY) {
			if (controls.style.display != "none") {
				controls.style.display = "none";
			} else {
				controls.style.display = "block";
			}
		}
	});

	window.onKeyUp.listen((KeyboardEvent e) {
		keys[e.keyCode] = false;
	});

	mousePosition = new Vector(window.innerWidth / 2, window.innerHeight / 2);
	window.onMouseMove.listen((MouseEvent e) {
		mousePosition.x = e.offset.x;
		mousePosition.y = e.offset.y;
	});

	Timer playerShooting;
	window.onMouseDown.listen((MouseEvent e) {
		myPlayer.shootPoint(mousePosition.x + MOUSE_SIZE / 2, mousePosition.y + MOUSE_SIZE / 2);
		if (e.button == 2) {
			playerShooting = new Timer.periodic(new Duration(milliseconds: 500), (Timer t) {
				myPlayer.shootPoint(mousePosition.x + MOUSE_SIZE / 2, mousePosition.y + MOUSE_SIZE / 2);
			});
		}
	});

	window.onMouseUp.listen((MouseEvent e) {
		if (playerShooting != null) {
			playerShooting.cancel();
		}
	});

	// Update and Render \\

	Timer updateTimer = new Timer.periodic(new Duration(microseconds: (1000.0 * DT).round()), update);
	window.animationFrame.then(draw);
}

num disconnectTime = 0;
num enemySpawnTime = 0;
num predaSpawnTime = 0;

void update(Timer timer) {
	if (isKeyPressed(S_KEY) && isKeyPressed(T_KEY) && isKeyPressed(A_KEY) && isKeyPressed(R_KEY) && isKeyPressed(NINE_KEY)) {
		magicColor = true;
	}

	if (magicColor) {
		myPlayer.colorString = randomColor();
	}

	myPlayer.velocity.x = 0;
	if (isKeyPressed(A_KEY)) {
		myPlayer.moveLeft();
	}
	if (isKeyPressed(D_KEY)) {
		myPlayer.moveRight();
	}
	if (myPlayer.grounded && (isKeyPressed(SPACEBAR_KEY) || isKeyPressed(W_KEY))) {
		myPlayer.jump();
	}

	pendingEventsFromCloud.forEach((int entityUid, String event) {
		for (Entity e in entities) {
			if (e.UID == entityUid) {
				if (event == "die") {
					e.die();
				} else if (event == "increaseKills") {
					if (e is Player) {
						(e as Player).kills += 1;
					}
				}
				pendingEventsFromCloud[entityUid] = "";
			}
		}
	});

	for (Entity e in entities) {
		e.update(DT);
		if (e._finished) {
			removeEntity(e);
		} else {
			reloadEntity(e);
		}
	}

	// TODO Fix lag
//	disconnectTime += DT;
//	if(disconnectTime > 500) {
//		mainFirebaseRef.remove();
//		if(timeoutCounter > MAX_TIMEOUT) {
//			window.location.assign(window.location.href);
//		}
//	}

	enemySpawnTime += DT;
	if (enemySpawnTime > 15000) {
		enemySpawnTime = 0;
		IdiotEnemy ie = new IdiotEnemy(new BoundingBox(randomizer.nextInt(tiles.length) * Tile.SIZE,
		randomizer.nextInt(tiles[0].length) * Tile.SIZE,
		randomizer.nextInt(Tile.SIZE ~/ 2) + Tile.SIZE ~/ 2,
		randomizer.nextInt(Tile.SIZE ~/ 2) + Tile.SIZE ~/ 2), 32 * 10, 0);
		Tile tile = tileFromCoordinate(ie.boundingBox.x, ie.boundingBox.y);
		while (tile == null || tile.isBlocked || ie.collidesWithMap(X_COLLISION_MASK | Y_COLLISION_MASK) || ie.distanceSqToEntity(myPlayer) > pow(5 * Tile.SIZE, 2)) {
			ie.boundingBox.setPosition(randomizer.nextInt(tiles.length) * Tile.SIZE, randomizer.nextInt(tiles[0].length) * Tile.SIZE);
			tile = tileFromCoordinate(ie.boundingBox.x, ie.boundingBox.y);
		}
		addEntity(ie);
	}

	predaSpawnTime += DT;
	if (predaSpawnTime > 120000) {
		addEntity(new Preda(myPlayer, new BoundingBox(23 * Tile.SIZE, 7 * Tile.SIZE, 100, 100), 0.5 * Tile.SIZE, 100));
		predaSpawnTime = 0;
	}
}

void draw(num timestamp) {
	// Clear
	ctx.fillStyle = "black";
	ctx.fillRect(0, 0, canvas.width, canvas.height);

	int x = 0, y = 0;
	for (List<Tile> lt in tiles) {
		for (Tile t in lt) {
			t.draw(x, y);
			x += Tile.SIZE;
		}
		x = 0;
		y += Tile.SIZE;
	}

	for (Entity e in entities) {
		e.draw();
	}

	for (Entity e in foreignEntities) {
		e.draw();
	}

	if (cursorReady) {
		ctx.drawImage(cursorImage, mousePosition.x, mousePosition.y);
	}

	window.animationFrame.then(draw);
}

void drawFilledStrokedRect(String fillColor, String strokeColor, num x, num y, num width, num height, num lineWidth) {
	ctx.fillStyle = fillColor;
	ctx.fillRect(x, y, width, height);
	ctx.strokeStyle = strokeColor;
	ctx.lineWidth = lineWidth;
	ctx.strokeRect(x, y, width, height);
}

Entity getEntityByUid(int uid) {
	for (Entity e in entities) {
		if (e.UID == uid) {
			return e;
		}
	}
	return null;
}

void addEntity(Entity e) {
	fb.Firebase entityRef = myFirebaseRef.push();
	entityRefs[e] = entityRef;
	reloadEntity(e);
}

void reloadEntity(Entity e) {
	entityRefs[e].set(e.toJson());
}

void removeEntity(Entity e) {
	entityRefs[e].remove();
}

void addPendingEvent(int entityUID, String event) {
	eventFirebaseRef.push().set({
			"EntityUID": entityUID, "EventType": event
	});
}

Entity readEntity(Map jsonMap) {
	if (jsonMap["type"] == PLAYER_TYPE) {
		return new Player.fromJson(jsonMap);
	} else if (jsonMap["type"] == IDIOT_ENEMY_TYPE) {
		return new IdiotEnemy.fromJson(jsonMap);
	} else if (jsonMap["type"] == PREDA_TYPE) {
		return new Preda.fromJson(jsonMap);
	} else if (jsonMap["type"] == PROJECTILE_TYPE) {
		return new Projectile.fromJson(jsonMap);
	} else {
		return null;
	}
}

bool isKeyPressed(int keyCode) {
	// cannot just return keys[keyCode] because it may be null
	return keys[keyCode] == true;
}

String randomColor() {
	String color = "#";
	for (int i = 0; i < 6; i++) {
		color += COLOR_LETTERS[randomizer.nextInt(COLOR_LETTERS.length)];
	}
	return color;
}

class Sound {
	AudioBuffer audioBuffer;
	GainNode gainNode;

	Sound(this.audioBuffer, this.gainNode);

	Sound.silent() {
		this.audioBuffer = null;
		this.gainNode = null;
	}

	void play({num volume: 1, bool loop: false}) {
		if (this.audioBuffer == null || this.gainNode == null) {
			return;
		}
		AudioBufferSourceNode source = audioContext.createBufferSource();
		source.buffer = this.audioBuffer;
		source.loop = loop;
		source.connectNode(this.gainNode);
		this.gainNode.connectNode(audioContext.destination);
		this.gainNode.gain.value = volume;
		source.start(0);
	}

	static loadSound(Sound sound, String soundLocation, {bool play: false, num volume: 1, bool loop: false}) {
		HttpRequest soundRequest = new HttpRequest();
		soundRequest.open("GET", soundLocation, async: true);
		soundRequest.responseType = "arraybuffer";
		soundRequest.onLoad.listen((ProgressEvent e) {
			audioContext.decodeAudioData(soundRequest.response).then((AudioBuffer buffer) {
				sound.audioBuffer = buffer;
				sound.gainNode = audioContext.createGain();
				if (play) {
					sound.play(volume: volume, loop: loop);
				}
			});
		});
		soundRequest.send();
	}
}

Tile tileFromCoordinate(num x, num y) {
	int row = y ~/ Tile.SIZE;
	int col = x ~/ Tile.SIZE;

	if (row >= tiles.length || row < 0 || col >= tiles[row].length || col < 0) {
		return null;
	} else {
		return tiles[row][col];
	}
}

class Tile {
	static const int SIZE = 24;

	String fillColor, strokeColor;
	int id;
	bool isBlocked;

	Tile(this.id, this.isBlocked) {
		if (this.id == 0) {
			this.fillColor = "#000000";
			this.strokeColor = "#000000";
		} else if (this.id == 1) {
			this.fillColor = "#333333";
			this.strokeColor = "#222222";
		} else if (this.id == 2) {
			this.fillColor = "#FFFF00";
			this.strokeColor = "#FF5500";
		}
	}

	void draw(int x, int y) {
		drawFilledStrokedRect(this.fillColor, this.strokeColor, x, y, SIZE, SIZE, 1);
	}
}

abstract class Entity implements Serializable {
	final int UID, type;
	Map jsonMap;

	// Do not serialize
	List<String> pendingEvents;

	String colorString;
	BoundingBox boundingBox;
	Vector velocity;
	bool _finished;

	// TODO Make UID actually a UID

	Entity(this.type, this.colorString, this.boundingBox, this.velocity) : this.UID = randomizer.nextInt(10000000) {
		this.pendingEvents = [];
		this._finished = false;
		this.jsonMap = {
		};
		this.jsonMap["UID"] = this.UID;
		this.jsonMap["type"] = this.type;
	}

	Entity.fromJson(Map jsonMap) : this.type = jsonMap["type"], this.UID = jsonMap["UID"] {
		this.pendingEvents = [];
		this.jsonMap = jsonMap;
		this.colorString = this.jsonMap["colorString"];
		this.boundingBox = new BoundingBox.fromJson(this.jsonMap["boundingBox"]);
		this.velocity = new Vector.fromJson(this.jsonMap["velocity"]);
		this._finished = this.jsonMap["_finished"];
	}

	void draw() {
		drawFilledStrokedRect(this.colorString, "#FFFFFF", this.boundingBox.x, this.boundingBox.y, this.boundingBox.width, this.boundingBox.height, 1);
	}

	void update(num delta) {
		this.updatePosition(delta);
		this.handleEvents();
	}

	void updatePosition(num delta) {
		this.boundingBox.x += this.velocity.x * (delta / 1000);
		this.boundingBox.y += this.velocity.y * (delta / 1000);
	}

	void handleEvents() {
		List<Entity> collidingEntities = this.getCollidingEntities();
		for (Entity e in collidingEntities) {
			this.onEntityCollide(e);
		}
		if (this.boundingBox.y > tiles.length * Tile.SIZE) {
			this.die();
		}
	}

	void onEntityCollide(Entity sender) {
	}

	void die() {
		this._finished = true;
	}

	// Collision detection, JPL Style(tm)

	bool collidesWithMap(int mask) {
		Tile tile;

		for (num modifier in [0.01, 0.5, 0.99]) {
			if ((mask & X_COLLISION_MASK) != 0) {
				if (this.velocity.x < 0) {
					tile = tileFromCoordinate(this.boundingBox.x, this.boundingBox.y + this.boundingBox.height * modifier);
				} else if (this.velocity.x > 0) {
					tile = tileFromCoordinate(this.boundingBox.getRight(), this.boundingBox.y + this.boundingBox.height * modifier);
				}

				if (tile != null && tile.isBlocked) {
					return true;
				}
			}

			if ((mask & Y_COLLISION_MASK) != 0) {
				if (this.velocity.y < 0) {
					tile = tileFromCoordinate(this.boundingBox.x + this.boundingBox.width * modifier, this.boundingBox.y);
				} else if (this.velocity.y > 0) {
					tile = tileFromCoordinate(this.boundingBox.x + this.boundingBox.width * modifier, this.boundingBox.getBottom());
				}

				if (tile != null && tile.isBlocked) {
					return true;
				}
			}
		}

		return false;
	}

	List<Entity> getCollidingEntities() {
		List<Entity> collidingEntities = [];
		for (Entity e in entities) {
			if (e == this) {
				continue;
			}
			if (this.boundingBox.intersects(e.boundingBox)) {
				collidingEntities.add(e);
			}
		}
		for (Entity e in foreignEntities) {
			if (e == this) {
				continue;
			}
			if (this.boundingBox.intersects(e.boundingBox)) {
				collidingEntities.add(e);
			}
		}
		return collidingEntities;
	}

	num distanceSqToEntity(Entity other) {
		return pow(this.boundingBox.x - other.boundingBox.x, 2) + pow(this.boundingBox.y - other.boundingBox.y, 2);
	}

	Map toJson() {
		this.jsonMap["colorString"] = this.colorString;
		this.jsonMap["boundingBox"] = this.boundingBox.toJson();
		this.jsonMap["velocity"] = this.velocity.toJson();
		this.jsonMap["_finished"] = this._finished;
		return this.jsonMap;
	}
}

abstract class LivingEntity extends Entity {
	num speed, jumpPower, shootingSpeed, shootingPower;
	bool grounded;

	LivingEntity(int type, String colorString, BoundingBox boundingBox, Vector initialVelocity, this.speed, this.jumpPower, this.shootingSpeed, this.shootingPower) : super(type, colorString, boundingBox, initialVelocity) {
		this.grounded = false;
	}

	LivingEntity.fromJson(Map jsonMap) : super.fromJson(jsonMap) {
		this.speed = this.jsonMap["speed"];
		this.jumpPower = this.jsonMap["jumpPower"];
		this.shootingSpeed = this.jsonMap["shootingSpeed"];
		this.shootingPower = this.jsonMap["shootingPower"];
		this.grounded = this.jsonMap["grounded"];
	}

	void moveLeft() {
		this.velocity.x -= speed;
	}

	void moveRight() {
		this.velocity.x += speed;
	}

	void jump() {
		this.velocity.y -= this.jumpPower * Tile.SIZE;
	}

	void shoot(num angle) {
		addEntity(new Projectile(this, [this.UID], new Vector(this.boundingBox.x + this.boundingBox.width / 2 - Projectile.SIZE / 2, this.boundingBox.y + this.boundingBox.height / 2 - Projectile.SIZE / 2), angle, this.shootingSpeed, this.shootingPower));
	}

	void shootPoint(num x, num y) {
		x -= Projectile.SIZE / 2;
		y -= Projectile.SIZE / 2;

		num startX = this.boundingBox.x + this.boundingBox.width / 2 - Projectile.SIZE / 2;
		num startY = this.boundingBox.y + this.boundingBox.height / 2 - Projectile.SIZE / 2;

		this.shoot(atan2(startY - y, x - startX));
	}

	@override
	void update(num delta) {
		this.velocity.y += GRAVITY * (delta / 1000);

		// Tile Collision
		this.boundingBox.x += this.velocity.x * (delta / 1000);
		if (this.collidesWithMap(X_COLLISION_MASK)) {
			if (this.velocity.x < 0) {
				this.boundingBox.x = (this.boundingBox.x / Tile.SIZE).ceil() * Tile.SIZE;
			} else if (this.velocity.x > 0) {
				this.boundingBox.x = (this.boundingBox.getRight() / Tile.SIZE).floor() * Tile.SIZE - this.boundingBox.width;
			}
			this.velocity.x = 0;
		}

		this.boundingBox.y += this.velocity.y * (delta / 1000);
		this.grounded = false;
		if (this.collidesWithMap(Y_COLLISION_MASK)) {
			if (this.velocity.y < 0) {
				this.boundingBox.y = (this.boundingBox.y / Tile.SIZE).ceil() * Tile.SIZE;
			} else if (this.velocity.y > 0) {
				this.boundingBox.y = (this.boundingBox.getBottom() / Tile.SIZE).floor() * Tile.SIZE - this.boundingBox.height;
				this.grounded = true;
			}
			this.velocity.y = 0;
		}

		this.handleEvents();
	}

	Map toJson() {
		this.jsonMap["speed"] = this.speed;
		this.jsonMap["jumpPower"] = this.jumpPower;
		this.jsonMap["shootingSpeed"] = this.shootingSpeed;
		this.jsonMap["shootingPower"] = this.shootingPower;
		this.jsonMap["grounded"] = this.grounded;
		return super.toJson();
	}
}

class Player extends LivingEntity {
	String username;
	num usernameWidth;
	int kills, deaths;

	Player(this.username, String colorString, BoundingBox boundingBox, num speed, num jumpPower) : super(PLAYER_TYPE, colorString, boundingBox, new Vector.zero(), speed, jumpPower, 500, 10) {
		this.jsonMap["username"] = this.username;
		this.usernameWidth = ctx.measureText(this.username).width;
		this.kills = 0;
		this.deaths = 0;
	}

	Player.fromJson(Map jsonMap) : super.fromJson(jsonMap) {
		this.username = this.jsonMap["username"];
		this.kills = this.jsonMap["kills"];
		this.deaths = this.jsonMap["deaths"];
		this.usernameWidth = ctx.measureText(this.username).width;
	}

	@override
	void draw() {
		super.draw();
		ctx.fillStyle = "#FFFFFF";
		ctx.font = "16px Roboto";
		// Username
		ctx.fillText(this.username, this.boundingBox.x + this.boundingBox.width / 2 - this.usernameWidth / 2, this.boundingBox.y - 50);
		// Kills
		String killMessage = "Kills: " + this.kills.toString();
		num killsWidth = ctx.measureText(killMessage).width;
		ctx.fillText(killMessage, this.boundingBox.x + this.boundingBox.width / 2 - killsWidth / 2, this.boundingBox.y - 30);
		// Deaths
		String deathMessage = "Deaths: " + this.deaths.toString();
		num deathsWidth = ctx.measureText(deathMessage).width;
		ctx.fillText(deathMessage, this.boundingBox.x + this.boundingBox.width / 2 - deathsWidth / 2, this.boundingBox.y - 10);
	}

	@override
	void die() {
		this.velocity = new Vector.zero();
		this.boundingBox.setPosition(2 * Tile.SIZE, 1 * Tile.SIZE);
		this.deaths += 1;
		if (this == myPlayer) {
			dieSound.play();
		}
	}

	@override
	Map toJson() {
		this.jsonMap["kills"] = this.kills;
		this.jsonMap["deaths"] = this.deaths;
		return super.toJson();
	}
}

class IdiotEnemy extends LivingEntity {
	bool movingLeft;

	IdiotEnemy(BoundingBox boundingBox, num speed, num jumpPower) : super(IDIOT_ENEMY_TYPE, "purple", boundingBox, new Vector.zero(), speed, jumpPower, 500, 10) {
		this.movingLeft = randomizer.nextInt(2) == 1;
	}

	IdiotEnemy.fromJson(Map jsonMap) : super.fromJson(jsonMap) {
		this.movingLeft = this.jsonMap["movingLeft"];
	}

	@override
	void update(num delta) {
		if (this.velocity.x == 0) {
			if (this.movingLeft) {
				this.moveRight();
			} else {
				this.moveLeft();
			}
			this.movingLeft = !this.movingLeft;
		}

		super.update(delta);
	}

	@override
	void onEntityCollide(Entity sender) {
		if (sender is Player) {
			addPendingEvent(sender.UID, "die");
		}
	}

	Map toJson() {
		this.jsonMap["movingLeft"] = this.movingLeft;
		return super.toJson();
	}
}

class Preda extends LivingEntity {
	Entity target;
	int targetUid, health;
	num shootingTime, theta;

	Preda(this.target, BoundingBox boundingBox, num speed, this.health) : super(PREDA_TYPE, "#CCFFFF", boundingBox, new Vector.zero(), speed, 0, 500, 10) {
		this.targetUid = this.target.UID;
		this.shootingTime = 0;
		this.jsonMap["targetUid"] = this.targetUid;
		predaSpawnSound.play(volume: 5);
	}

	Preda.fromJson(Map jsonMap) : super.fromJson(jsonMap) {
		this.targetUid = this.jsonMap["targetUid"];
		this.target = getEntityByUid(this.targetUid);
		this.health = this.jsonMap["health"];
		this.shootingTime = this.jsonMap["shootingTime"];
	}

	@override
	void update(num delta) {
		this.theta = atan2((this.target.boundingBox.y + this.target.boundingBox.height / 2) - (this.boundingBox.y + this.boundingBox.height / 2), (this.target.boundingBox.x  + this.target.boundingBox.width / 2) - (this.boundingBox.x  + this.boundingBox.width / 2));
		this.velocity.x = this.speed * cos(this.theta);
		this.velocity.y = this.speed * sin(this.theta);

		this.shootingTime += delta;
		if (this.shootingTime > 500) {
			this.shootPoint(this.target.boundingBox.x, this.target.boundingBox.y);
			this.shootingTime = 0;
		}

		this.updatePosition(delta);
		this.handleEvents();
	}

	@override
	void draw() {
		super.draw();
	}

	@override
	void onEntityCollide(Entity sender) {
		if (sender is Player) {
			addPendingEvent(sender.UID, "die");
			this.boundingBox.x += -100 * cos(this.theta);
			this.boundingBox.y += -100 * sin(this.theta);
		}
	}

	@override
	void die() {
		this.health -= 1;
		this.boundingBox.width -= 1;
		this.boundingBox.height -= 1;
		this.speed += 1;
		if(this.health <= 0) {
			super.die();
			dieSound.play();
		}
	}

	// It's a g-g-g-ghost!

	@override
	bool collidesWithMap(int mask) {
		return false;
	}

	@override
	Map toJson() {
		this.jsonMap["health"] = this.health;
		this.jsonMap["shootingTime"] = this.shootingTime;
		return super.toJson();
	}
}

class Projectile extends Entity {
	static const int SIZE = 8;

	int shooterUid;
	List<int> blacklist;
	num angle, shootingSpeed, shootingPower;

	Projectile(Entity shooter, this.blacklist, Vector position, angle, shootingSpeed, shootingPower) : super(PROJECTILE_TYPE, shooter.colorString, new BoundingBox(position.x, position.y, SIZE, SIZE), new Vector(shootingSpeed * cos(angle), -shootingSpeed * sin(angle))) {
		this.shooterUid = shooter.UID;
		this.angle = angle;
		this.shootingSpeed = shootingSpeed;
		this.shootingPower = shootingPower;

		this.jsonMap["shooterUid"] = this.shooterUid;
		this.jsonMap["blacklist"] = this.blacklist;
		this.jsonMap["angle"] = this.angle;
		this.jsonMap["shootingSpeed"] = this.shootingSpeed;
		this.jsonMap["shootingPower"] = this.shootingPower;
	}

	Projectile.fromJson(Map jsonMap) : super.fromJson(jsonMap) {
		this.shooterUid = this.jsonMap["shooterUid"];
		this.blacklist = this.jsonMap["blacklist"];
		this.angle = this.jsonMap["angle"];
		this.shootingSpeed = this.jsonMap["shootingSpeed"];
		this.shootingPower = this.jsonMap["shootingPower"];
	}

	@override
	void update(num delta) {
		super.update(delta);
		if (this.boundingBox.x > window.innerWidth || this.boundingBox.x < 0 || this.boundingBox.y > window.innerHeight || this.boundingBox.y < 0
		|| this.collidesWithMap(X_COLLISION_MASK | Y_COLLISION_MASK)) {
			this.die();
		}
	}

	@override
	void onEntityCollide(Entity sender) {
		if (!this.blacklist.contains(sender.UID)) {
			addPendingEvent(sender.UID, "die");
			if (sender is Player) {
				addPendingEvent(shooterUid, "increaseKills");
			}
			if (getEntityByUid(shooterUid) == myPlayer) {
				hitSound.play();
			}
			this.die();
		}
	}
}

class Vector implements Serializable {
	final int type = VECTOR_TYPE;
	Map jsonMap;

	num x, y;

	Vector(this.x, this.y) {
		this.jsonMap = {
		};
		this.jsonMap["type"] = this.type;
	}

	Vector.zero() : this(0, 0);

	Vector.fromJson(Map jsonMap) {
		this.jsonMap = jsonMap;
		this.x = this.jsonMap["x"];
		this.y = this.jsonMap["y"];
	}

	@override
	Map toJson() {
		this.jsonMap["x"] = this.x;
		this.jsonMap["y"] = this.y;
		return this.jsonMap;
	}
}

class BoundingBox implements Serializable {
	final int type = BOUNDING_BOX_TYPE;
	Map jsonMap;

	num x, y, width, height;

	BoundingBox(this.x, this.y, this.width, this.height) {
		this.jsonMap = {
		};
		this.jsonMap["type"] = this.type;
	}

	BoundingBox.fromJson(this.jsonMap) {
		this.x = this.jsonMap["x"];
		this.y = this.jsonMap["y"];
		this.width = this.jsonMap["width"];
		this.height = this.jsonMap["height"];
	}

	void setPosition(num x, num y) {
		this.x = x;
		this.y = y;
	}

	void setSize(num width, num height) {
		this.width = width;
		this.height = height;
	}

	num getRight() {
		return this.x + this.width;
	}

	num getBottom() {
		return this.y + this.height;
	}

	bool intersects(BoundingBox other) {
		return !(this.x >= other.getRight()
		|| this.getRight() <= other.x
		|| this.y >= other.getBottom()
		|| this.getBottom() <= other.y);
	}

	@override
	Map toJson() {
		this.jsonMap["x"] = this.x;
		this.jsonMap["y"] = this.y;
		this.jsonMap["width"] = this.width;
		this.jsonMap["height"] = this.height;
		return this.jsonMap;
	}
}

abstract class Serializable {
	final int type;

	Serializable(this.type);

	Map toJson();
}
