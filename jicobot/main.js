(function() {
    "use strict";

    var codeInterval;

    function throwError(error) {
        alert(error);
    }

    function removeAllWhitespace(string) {
        return string.replace(/\s/g, "");
    }

    function occursGreaterThan(string, character, limit) {
        var count = 0;
        for(var i = 0; i < string.length; i++) {
            if(string.charAt(i) === character) {
                count += 1;
            }
            if(count > limit) {
                return true;
            }
        }
        return false;
    }

    function deleteChildren(element) {
        // Source: http://stackoverflow.com/a/3955238
        while(element.firstChild) {
            element.removeChild(element.firstChild);
        }
    }

    function vectorFromDirection(direction) {
        if(direction === "N") {
            return [-1, 0];
        } else if(direction === "E") {
            return [0, 1];
        } else if(direction === "S") {
            return [1, 0];
        } else if(direction === "W") {
            return [0, -1];
        } else {
            return [0, 0];
        }
    }

    function getBlocked(a, i, j) {
        if(i < 0 || i >= a.length || j < 0 || j >= a[i].length || a[i][j] === 1) {
            return "1";
        } else {
            return "0";
        }
    }

    //
    // Map Specification
    // ~~~~~~~~~~~~~~~~~
    // 
    // Format:
    // r,c,string
    //
    // Notes:
    // - r * c == string.length
    // - Arbitrary whitespace is permitted
    // - 2 represents a player (only a single 2 should be present)
    // - 3 represents a visited tile and should not be manually programmed in
    //
    // Example:
    //                     1111
    // 3,4,111100011101 -> 0001
    //                     1101
    //

    function loadMap(map) {
        var data = removeAllWhitespace(map).split(",");
        var rows = data[0];
        var cols = data[1];
        var mapString = data[2];

        if(rows * cols != mapString.length) {
            throwError("Error: r * c != mapString.length\nr = " + rows + "\nc = " + cols + "\nmapString.length = " + mapString.length);
            return;
        }
        if(occursGreaterThan(mapString, "2", 1)) {
            throwError("Error: 2 occurs more than once in mapString");
            return;
        }

        var mapData = [];

        var count = 0;
        for(var r = 0; r < rows; r++) {
            var row = [];
            for(var c = 0; c < cols; c++) {
                var indicator = parseInt(mapString.charAt(count));
                if(indicator === 0 || indicator === 1) {
                    row.push(indicator)
                } else {
                    row.push(0);
                }
                count += 1;
            }
            mapData.push(row);
        }

        var emptySpots = [];
        for(var r = 0; r < rows; r++) {
            for(var c = 0; c < cols; c++) {
                if(mapData[r][c] === 0) {
                    emptySpots.push([r, c]);
                }
            }
        }

        var randomLocation = emptySpots[Math.floor(Math.random() * emptySpots.length)];
        mapData[randomLocation[0]][randomLocation[1]] = 2;

        return mapData;
    }

    // Updates the HTML of the board

    function updateBoard(board, mapData, recreate) {
        if(recreate) {
            deleteChildren(board);
        }
        var count = 0;
        for(var r = 0; r < mapData.length; r++) {
            for(var c = 0; c < mapData[r].length; c++) {
                var indicator = mapData[r][c];
                var tileClass = "";
                if(indicator === 1) {
                    tileClass = "blocked";
                } else if(indicator === 2) {
                    tileClass = "player";
                } else if(indicator === 3) {
                    tileClass = "visited";
                }

                if(recreate) {
                    var tile = document.createElement("div");
                    tile.className = tileClass;
                    board.appendChild(tile);
                } else {
                    var tile = board.getElementsByTagName("div")[count];
                    tile.className = tileClass;
                }
                
                count += 1;
            }
            if(recreate) {
                board.appendChild(document.createElement("br"));
            }
        }
    }

    //
    // Jico Language Specification
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    //
    // Format:
    // [program]        :: start::[state]\n[line]+
    // [line]           :: [rule | comment]\n
    // [rule]           :: [state]:[blocked string]->[direction]&[state]
    // [state]          :: {String}
    // [blocked string] :: [indicator][indicator][indicator][indicator]
    // [indicator]      :: 0 | 1 | *
    // [direction]      :: N | E | S | W | X
    // [comment]        :: # {String}
    //
    // Explanation:
    // A program is made up of a start state and a series of lines, which can be a rule or a comment.
    // The start state is the entry state for the program.
    // Every line ends with a newline character ('\n').
    // A rule is a single instruction in a Jico program.
    // The state serves an identifier for a rule.
    // A blocked string is a string that contains information about which surrounding tiles are blocked.
    // A blocked string is ordered as follows: North, East, South, West
    // An indicator can be:
    //     0: empty tile
    //     1: blocked tile
    //     *: wildcard (any tile)
    // A direction can be any of the following: north (N), east (E), south (S), west (W), or stationary (X).
    // A comment is a line prefixed with a pound sign (#) and is ignored by the interpreter.
    //
    // The program interpreter will analyze all rules in a Jico program and find those that match.
    // If more than one rule matches the current scenario, an OverhandledStateError will be thrown.
    // The program will then execute the rule and update the board until the board is completed or
    // the program is terminated by a user. If a move is impossible to make (i.e. a wall blocks the
    // user), an ImpossibleMoveError will be thrown.
    //
    // Notes:
    // - Arbitrary whitespace is permitted
    //
    // Examples:
    // # State 0: if there is nothing to the north, go north and back into State 0.
    // 0 : 0*** -> N & 0
    //
    // # State 0: if there is something to the north, go west and into State 1.
    // 0 : 1*** -> W & 1
    //
    // # State 1: if there is nothing to the south, go south and back into State 1.
    // 1 : ***0 -> S & 1
    //
    // # State 1: if there is something to the south, remain stationary and go into State 0.
    // 1 : ***1 -> X & 0
    //

    //
    // Returns the program in the format:
    // {
    //     "startState": startState,
    //     "rules": rules
    // }
    //

    function parseProgram(program) {
        var lines = program.split("\n");

        var startStateLine = removeAllWhitespace(lines[0]);
        var startStateDoubleColonIndex = startStateLine.indexOf("::");
        var startState = startStateLine.substring(startStateDoubleColonIndex + 2);

        var unsortedRules = [];
        for(var i = 1; i < lines.length; i++) {
            // Comment
            if(lines[i].indexOf("#") === 0) {
                continue;
            } else { // Rule
                var rule = parseRule(lines[i]);
                unsortedRules.push(rule);
            }
        }

        var rules = {};

        for(var i = 0; i < unsortedRules.length; i++) {
            if(unsortedRules[i]["state"] in rules) {
                rules[unsortedRules[i]["state"]].push(unsortedRules[i]);
            } else {
                rules[unsortedRules[i]["state"]] = [unsortedRules[i]];
            }
        }

        return {
            "startState": startState,
            "rules": rules
        };
    }

    //
    // Returns a rule in the format of:
    // {
    //     "state": state,
    //     "blockedMap": {
    //         "N": indicator,
    //         "E": indicator,
    //         "S": indicator,
    //         "W": indicator
    //     },
    //     "direction": direction,
    //     "nextState": nextState
    // }
    //

    function parseRule(ruleString) {
        var strippedRule = removeAllWhitespace(ruleString);
        var colonIndex = strippedRule.indexOf(":");
        var arrowIndex = strippedRule.indexOf("->");
        var ampersandIndex = strippedRule.indexOf("&");

        var state = strippedRule.substring(0, colonIndex);
        var blockedString = strippedRule.substring(colonIndex + 1, arrowIndex);
        var direction = strippedRule.substring(arrowIndex + 2, ampersandIndex);
        var nextState = strippedRule.substring(ampersandIndex + 1);

        var blockedMap = {
            "N": blockedString.charAt(0),
            "E": blockedString.charAt(1),
            "S": blockedString.charAt(2),
            "W": blockedString.charAt(3)
        }

        return {
            "state": state,
            "blockedMap": blockedMap,
            "direction": direction,
            "nextState": nextState
        }
    }

    function matchesBlocked(blockedMap, ruleBlockedMap) {
        var directions = Object.keys(ruleBlockedMap);
        for(var i = 0; i < directions.length; i++) {
            var direction = directions[i];
            if(ruleBlockedMap[direction] === "*") {
                continue;
            } else if(ruleBlockedMap[direction] !== blockedMap[direction]) {
                return false;
            }
        }

        return true;
    }

    function matchRule(blockedMap, rules, state) {
        var stateRules = rules[state];
        for (var i = 0; i < stateRules.length; i++) {
            if(matchesBlocked(blockedMap, stateRules[i]["blockedMap"])) {
                return stateRules[i];
            }
        }
        return null;
    }

    // Returns a blockedMap of the current location
    function currentBlockedMap(mapData) {
        for(var r = 0; r < mapData.length; r++) {
            for(var c = 0; c < mapData[r].length; c++) {
                var indicator = mapData[r][c];
                if(indicator === 2) {
                    return {
                        "N": getBlocked(mapData, r - 1, c),
                        "E": getBlocked(mapData, r, c + 1),
                        "S": getBlocked(mapData, r + 1, c),
                        "W": getBlocked(mapData, r, c - 1)
                    }
                }
            }
        }
    }

    function step(mapData, rules, state) {
        var rule = matchRule(currentBlockedMap(mapData), rules, state);
        if(rule === null) {
            throwError("Error: no rule matched.");
            return;
        }

        for(var r = 0; r < mapData.length; r++) {
            for(var c = 0; c < mapData[r].length; c++) {
                var indicator = mapData[r][c];
                if(indicator === 2) {
                    var vector = vectorFromDirection(rule["direction"]);
                    var nextIndicator = getBlocked(mapData, r + vector[0], c + vector[1]);
                    if(nextIndicator === "1") {
                        throwError("Cannot move into blocked tile.");
                        return null;
                    }

                    mapData[r][c] = 3;
                    mapData[r + vector[0]][c + vector[1]] = 2;

                    return rule["nextState"];
                }
            }
        }

        return null;
    }

    function isWon(mapData) {
        for(var r = 0; r < mapData.length; r++) {
            for(var c = 0; c < mapData[r].length; c++) {
                if(mapData[r][c] === 0) {
                    return false;
                }
            }
        }
        return true;
    }

    function runCode(board, program, mapData) {
        var programData = parseProgram(program);
        var state = programData["startState"];
        var rules = programData["rules"];

        codeInterval = window.setInterval(function() {
            state = step(mapData, rules, state);
            if(state === null) {
                window.clearInterval(codeInterval);
                return;
            }
            updateBoard(board, mapData, false);
            if(isWon(mapData)) {
                alert("You win!");
                window.clearInterval(codeInterval);
            }
        }, 25);
    }
    
    window.onload = function() {
        var board = document.getElementById("board");

        var codeTextArea = document.getElementById("code");
        var runCodeButton = document.getElementById("run-code");
        var stopCodeButton = document.getElementById("stop-code");

        var mapTextArea = document.getElementById("custom-map");
        var updateMapButton = document.getElementById("update-map");
       
        function getMapData() {
            return loadMap(mapTextArea.value);
        }

        // So it looks nice on startup
        var defaultMapData = getMapData();
        updateBoard(board, defaultMapData, true);

        function updateAndRun(mapData) {
            updateBoard(board, mapData, true);

            window.clearInterval(codeInterval);
            runCode(board, codeTextArea.value, mapData);
        }

        runCodeButton.onclick = function(e) {
            updateAndRun(getMapData());
        }

        stopCodeButton.onclick = function(e) {
            window.clearInterval(codeInterval);
        }

        updateMapButton.onclick = function(e) {
            var mapData = loadMap(mapTextArea.value);
            updateBoard(board, mapData, true);
            closeSettingsPanel();
        }

        var settingsButton = document.getElementById("settings-button");
        var settingsPanel = document.getElementById("settings-panel");
        var settingsPanelShowing = false;

        function closeSettingsPanel() {
            settingsPanel.className = "hidden";
        }

        function openSettingsPanel() {
            settingsPanel.className = "visible";
        }

        function toggleSettingsPanel() {
            if(settingsPanelShowing) {
                closeSettingsPanel();
            } else {
                openSettingsPanel();
            }
            settingsPanelShowing = !settingsPanelShowing;
        }

        settingsButton.onclick = toggleSettingsPanel;

        window.onkeydown = function(event) {
            if(event.keyCode === 27) {
                closeSettingsPanel();
            }
        }
    }
})();
