(function() {
    "use strict";

    function ActionStack() {
        this.stack = [];
        this.sp = -1;
    }
    ActionStack.prototype.push = function(a) {
        if (this.sp !== this.stack.length - 1) {
            this.stack = this.stack.slice(0, this.sp + 1);
        }
        this.stack.push(a);
        this.sp++;
    };
    ActionStack.prototype.undo = function() {
        if (this.sp === -1) {
            return;
        }
        this.stack[this.sp].undo();
        this.sp--;
    };
    ActionStack.prototype.redo = function() {
        if (this.sp === this.stack.length - 1) {
            return;
        }
        this.sp++;
        this.stack[this.sp].execute();
    };

    var actionStack = new ActionStack();

    function Action(execute, undo) {
        this.execute = execute;
        this.undo = undo;
    }

    /*
     * Component
     */
    function Component(equation) {
        this.equation = equation;
        this.init();
    }
    Component.prototype.init = function() {};
    Component.prototype.update = function(time, delta) {};

    /*
     * Stock
     */
    function Stock(equation) {
        Component.call(this, equation);
        this.difference = 0;
    }
    Stock.prototype = Object.create(Component.prototype);
    Stock.prototype.init = function() {
        this.value = this.equation(svgComponents, 0, 0);
    };
    Stock.prototype.update = function(time, delta) {
        this.value += this.difference;
        this.difference = 0;
    };

    /*
     * Flow
     */
    function Flow(stock, equation) {
        Component.call(this, equation);
        this.stock = stock;
    }
    Flow.prototype = Object.create(Component.prototype);
    Flow.prototype.init = function() {
        this.value = NaN;
    };
    Flow.prototype.update = function(time, delta) {
        this.value = this.equation(svgComponents, time, delta) * delta;
        this.stock.difference += this.value;
    };

    /*
     * Converter
     */
    function Converter(equation) {
        Component.call(this, equation);
    }
    Converter.prototype = Object.create(Component.prototype);
    Converter.prototype.init = function() {
        this.value = this.equation(svgComponents, 0, 0);
    };
    Converter.prototype.update = function(time, delta) {
        this.value = this.equation(svgComponents, time, delta) * delta;
    };

    var draw;
    var selectedComponentNameElements;
    var selectedSvgComponent;
    var componentNameInput, changePropertiesButton;
    var equationEditor;

    var precision, deltaTime, finalTime, timePrecision;
    var precisionInput, deltaTimeInput, finalTimeInput;

    var runData, minimums, maximums;
    var observedComponentSelector;

    var dataTableOutput;
    var timeplot;

    var workspace;
    var tabs, interfaceTab, modelTab;
    var views, interfaceView, modelView;
    var componentControls;
    var modelButtons, stockButton, flowButton, converterButton, selectedButton;
    var runButton;

    var starterNodes = [];
    var currentNode = null;

    function Node(parent, node) {
        this.parent = parent;
        this.node = node;
    }
    Node.prototype.move = function(x, y) {
        this.node.move(x, y);
        this.touch();
    };
    Node.prototype.touch = function() {};

    function ReceiverNode(parent) {
        Node.call(this, parent, draw.circle(20).stroke({width: 2, color: "#000000"}).fill({opacity: 0}));
        this.link = null;
        var that = this;
        this.node.mouseup(function(event) {
            if (currentNode !== null) {
                that.link = currentNode;
                that.link.link = that;
                that.link.parent.component.stock = that.parent.component;

                that.touch();
            }
        });
    }
    ReceiverNode.prototype = Object.create(Node.prototype);
    ReceiverNode.prototype.touch = function() {
        if (this.link !== null) {
            this.link.touch();
        }
    };

    function StarterNode(parent) {
        Node.call(this, parent, draw.circle(30).stroke({width: 2, color: "#000000"}).fill({opacity: 0}));
        this.line = null;
        this.link = null;
        var that = this;
        this.node.mousedown(function(event) {
            if (that.link !== null) {
                return;
            }
            that.line = draw.line(that.node.cx(), that.node.cy(), that.node.cx(), that.node.cy()).stroke({width: 3, color: "#00C6FF"});
            that.line.back();
            that.node.front();
            currentNode = that;
        });
        starterNodes.push(this);
    }
    StarterNode.prototype = Object.create(Node.prototype);
    StarterNode.prototype.touch = function() {
        if (this.link !== null) {
            this.line.plot(this.node.cx(), this.node.cy(), this.link.node.cx(), this.link.node.cy());
        }
    };

    var svgComponents = [];

    function SvgComponent(x, y, component, name, rawSvg, width) {
        this.component = component;
        this.name = name;
        this.image = draw.svg(rawSvg).roots()[0];
        this.image.size(width);
        this.image.move(x, y);
        this.image.draggable();
        this.equationString = functionBody(this.component.equation);
        var that = this;

        this.image.dblclick(function() {
            if (selectedSvgComponent === that) {
                deselectSvgComponent();
            } else {
                selectSvgComponent(that);
            }
        });

        this.image.dragmove = function(delta, event) {
            that.move(that.image.x(), that.image.y());
        };

        var px, py;
        this.image.beforedrag = function(event) {
            px = that.image.x();
            py = that.image.y();
        };
        this.image.dragend = function(delta, event) {
            (function(px, py, cx, cy) {
                actionStack.push(new Action(
                    function() {
                        that.move(cx, cy);
                    }, function() {
                        that.move(px, py);
                    }
                ));
            })(px, py, that.image.x(), that.image.y());
        };
    }
    SvgComponent.prototype.move = function(x, y) {
        this.image.move(x, y);
    };

    var stockId = 0;
    var stockRawSvg = '<?xml version="1.0" encoding="utf-8"?><!-- Generator: Adobe Illustrator 16.0.0, SVG Export Plug-In . SVG Version: 6.00 Build 0)  --><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px"   width="143.722px" height="143.721px" viewBox="0 0 143.722 143.721" enable-background="new 0 0 143.722 143.721"  xml:space="preserve"><rect x="1" y="1" fill="#35C2F2" stroke="#000000" stroke-width="2" stroke-miterlimit="10" width="141.722" height="141.721"/><rect x="13.36" y="13.36" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-miterlimit="10" width="117" height="117"/></svg>';
    function SvgStock(x, y) {
        SvgComponent.call(this, x, y, new Stock(function() {return 0;}), "Stock" + stockId, stockRawSvg, 100);
        stockId++;

        // ReceiverNode
        this.rns = [];
        for (var i = 0; i < 4; i++) {
            this.rns.push(new ReceiverNode(this));
        }

        this.move(this.image.x(), this.image.y());
    }
    SvgStock.prototype.move = function(x, y) {
        SvgComponent.prototype.move.call(this, x, y);
        this.rns[0].move(this.image.cx() - this.rns[0].node.width() / 2, this.image.y() - this.rns[0].node.height());
        this.rns[1].move(this.image.x() + this.image.width(), this.image.cy() - this.rns[1].node.height() / 2);
        this.rns[2].move(this.image.cx() - this.rns[2].node.width() / 2, this.image.y() + this.image.height());
        this.rns[3].move(this.image.x() - this.rns[3].node.width(), this.image.cy() - this.rns[3].node.height() / 2);
    };

    var flowId = 0;
    var flowRawSvg = '<?xml version="1.0" encoding="utf-8"?><!-- Generator: Adobe Illustrator 16.0.0, SVG Export Plug-In . SVG Version: 6.00 Build 0)  --><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px"    width="143.722px" height="143.723px" viewBox="0 0 143.722 143.723" enable-background="new 0 0 143.722 143.723"  xml:space="preserve"><circle fill="#35C2F2" stroke="#000000" stroke-width="2" stroke-miterlimit="10" cx="71.861" cy="71.861" r="70.861"/><circle fill="#FFFFFF" stroke="#000000" stroke-width="5" stroke-miterlimit="10" cx="71.861" cy="71.861" r="60.166"/><rect x="66.861" y="1" width="10" height="10.695"/><rect x="132.027" y="66.863" width="10.694" height="10"/><rect x="114.152" y="19.995" transform="matrix(0.7071 -0.7071 0.7071 0.7071 17.1001 91.2736)" width="9.151" height="10"/><rect x="20.418" y="113.729" transform="matrix(0.7071 -0.7072 0.7072 0.7071 -76.6388 52.4563)" width="9.153" height="10.001"/><rect x="113.027" y="114.029" transform="matrix(0.7071 -0.7072 0.7072 0.7071 -49.5971 118.3324)" width="10.001" height="10.001"/><rect x="19.694" y="20.694" transform="matrix(0.707 -0.7072 0.7072 0.707 -10.9366 24.9924)" width="10" height="10.002"/><rect x="1" y="66.861" width="10.695" height="10"/><rect x="66.861" y="132.029" width="10" height="10.693"/></svg>';
    function SvgFlow(x, y) {
        SvgComponent.call(this, x, y, new Flow(null, function() {return 0;}), "Flow" + flowId, flowRawSvg, 100);
        flowId++;
        
        // StarterNode
        this.starterNode = new StarterNode(this);
        this.move(this.image.x(), this.image.y());
    }
    SvgFlow.prototype = Object.create(SvgComponent.prototype);
    SvgFlow.prototype.move = function(x, y) {
        SvgComponent.prototype.move.call(this, x, y);
        this.starterNode.move(this.image.cx() - this.starterNode.node.width() / 2,
                                   this.image.cy() - this.starterNode.node.height() / 2);
    };

    var converterId = 0;
    var converterRawSvg = '<?xml version="1.0" encoding="utf-8"?><!-- Generator: Adobe Illustrator 16.0.0, SVG Export Plug-In . SVG Version: 6.00 Build 0)  --><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px"   width="143.722px" height="143.721px" viewBox="0 0 143.722 143.721" enable-background="new 0 0 143.722 143.721"  xml:space="preserve"><circle fill="#35C2F2" stroke="#000000" stroke-width="2" stroke-miterlimit="10" cx="71.861" cy="71.861" r="70.861"/><circle fill="#35C2F2" stroke="#FFFFFF" stroke-width="5" stroke-miterlimit="10" cx="71.861" cy="71.861" r="56.601"/></svg>';
    function SvgConverter(x, y) {
        SvgComponent.call(this, x, y, new Converter(function() {return 0;}), "Converter" + converterId, converterRawSvg, 50);
        converterId++;
    }
    SvgConverter.prototype = Object.create(SvgComponent.prototype);

    /*
     * Main
     */
    window.onload = function() {
        precisionInput = document.getElementById("precision-input");
        deltaTimeInput = document.getElementById("delta-time-input");
        finalTimeInput = document.getElementById("final-time-input");

        function updatePrecision() {
            precision = parseInt(precisionInput.value);
            if (isNaN(precision)) {
                precision = 2;
            }
        }
        precisionInput.oninput = updatePrecision;
        updatePrecision();

        function updateDeltaTime() {
            deltaTime = parseFloat(deltaTimeInput.value);
            if (isNaN(deltaTime)) {
                deltaTime = 1;
            }
            var a = deltaTime;
            timePrecision = 0;
            while (!isInt(a, 0.00000000001)) {
                a *= 10;
                timePrecision += 1;
            }
        }
        deltaTimeInput.oninput = updateDeltaTime;
        updateDeltaTime();

        function updateFinalTime() {
            finalTime = parseFloat(finalTimeInput.value);
            if (isNaN(finalTime)) {
                finalTime = 100;
            }
        }
        finalTimeInput.oninput = updateFinalTime;
        updateFinalTime();

        observedComponentSelector = document.getElementById("observed-component-selector");
        observedComponentSelector.onchange = function(event) {
            updateDataTable(observedComponentSelector.selectedIndex);
        };

        dataTableOutput = document.getElementById("data-table-output");
        timeplot = new Dygraph(
                document.getElementById("timeplot-container"),
                [[0, 0]],
                {
                    labels: ["t", "y"],
                    labelsDiv: document.getElementById("timeplot-labels"),
                    axisLabelColor: "#FFFFFF",
                    legend: "always",
                    "y": {
                        color: "#00C6FF"
                    },
                    drawAxesAtZero: true
                }
        );

        workspace = document.getElementById("workspace");

        interfaceTab = document.getElementById("interface-tab");
        modelTab = document.getElementById("model-tab");
        tabs = [interfaceTab, modelTab];

        interfaceView = document.getElementById("interface");
        modelView = document.getElementById("model");
        views = [interfaceView, modelView];

        componentControls = document.getElementById("component-controls");
        stockButton = document.getElementById("stock-button");
        flowButton = document.getElementById("flow-button");
        converterButton = document.getElementById("converter-button");
        selectedButton = null;
        modelButtons = [stockButton, flowButton, converterButton];

        runButton = document.getElementById("run-button");

        selectedComponentNameElements = document.querySelectorAll(".selected-component-name");

        draw = SVG("workspace");

        for (var i = 0; i < tabs.length; i++) {
            tabs[i].onclick = function(event) {
                displayTab(this);
            };
        }
        displayTab(modelTab);

        for (var i = 0; i < modelButtons.length; i++) {
            modelButtons[i].onclick = function(event) {
                var shouldSelect = selectedButton != this;
                deselectModelButtons();
                if (shouldSelect) {
                    selectModelButton(this);
                }
            };
        }

        runButton.onclick = function(event) {
            if (svgComponents.length === 0) {
                return;
            }

            clearTableData();

            var order = orderedSvg();
            runData = [];
            minimums = [];
            maximums = [];

            for (var i = 0; i < RESET_ORDER.length; i++) {
                for (var j = 0; j < order[RESET_ORDER[i]].length; j++) {
                    order[RESET_ORDER[i]][j].component.init();
                    runData.push([]);
                }
            }

            for (var i = 0; i < svgComponents.length; i++) {
                minimums[i] = +Infinity;
                maximums[i] = -Infinity;
            }

            var val;
            for (var t = 0; t < finalTime + deltaTime / 2; t += deltaTime) {
                for (var i = 0; i < svgComponents.length; i++) {
                    val = svgComponents[i].component.value;
                    if (!isNaN(val)) {
                        if (val < minimums[i]) {
                            minimums[i] = val;
                        } else if (val > maximums[i]) {
                            maximums[i] = val;
                        }
                    }
                    runData[i].push([t.toFixed(timePrecision),
                                     val.toFixed(precision).replace("NaN", "X")]);
                }
                for (var i = 0; i < UPDATE_ORDER.length; i++) {
                    for (var j = 0; j < order[UPDATE_ORDER[i]].length; j++) {
                        order[UPDATE_ORDER[i]][j].component.update(t, deltaTime);
                    }
                }
            }

            setupDataTable(observedComponentSelector.selectedIndex);
        };

        workspace.onmousedown = function(event) {
            var x = wx(event.clientX);
            var y = wy(event.clientY);
            if (selectedButton !== null) {
                var c = null;
                if (selectedButton === stockButton) {
                    c = new SvgStock(x, y);
                } else if (selectedButton === flowButton) {
                    c = new SvgFlow(x, y);
                } else if (selectedButton === converterButton) {
                    c = new SvgConverter(x, y);
                }

                if (c !== null) {
                    svgComponents.push(c);
                    sortSvgComponents();
                }
            }
            deselectModelButtons();
        };

        changePropertiesButton = document.getElementById("change-properties");
        componentNameInput = document.getElementById("component-name-input");

        equationEditor = ace.edit("component-equation-input");
        equationEditor.setTheme("ace/theme/tomorrow_night");
        equationEditor.getSession().setMode("ace/mode/javascript");
        equationEditor.getSession().setUseWorker(false);
        equationEditor.$blockScrolling = Infinity;

        changePropertiesButton.onclick = function(event) {
            selectedSvgComponent.name = componentNameInput.value.replace(/\s/g, "");
            selectedSvgComponent.equationString = equationEditor.getValue();
            selectedSvgComponent.component.equation = new Function("svgComponents", "time", "delta", nameToComponent(selectedSvgComponent.equationString));
            sortSvgComponents();
            updateNames(selectedSvgComponent.name);
        };

        // Shortcut Keys
        var Y_KEY = 89;
        var Z_KEY = 90;
        window.onkeydown = function(event) {
            if (event.keyCode === Y_KEY) {
                actionStack.redo();
            } else if (event.keyCode === Z_KEY) {
                actionStack.undo();
            }
        };

        // Nodes
        window.onmouseup = function(event) {
            for (var i = 0; i < starterNodes.length; i++) {
                if (starterNodes[i].link === null) {
                    if (starterNodes[i].line !== null) {
                        starterNodes[i].line.remove();
                    }
                    starterNodes[i].line = null;
                }
            }
            currentNode = null;
        };
        workspace.onmousemove = function(event) {
            event.preventDefault();
            var x = wx(event.clientX);
            var y = wy(event.clientY);
            for (var i = 0; i < starterNodes.length; i++) {
                if (starterNodes[i].link === null && starterNodes[i].line !== null) {
                    starterNodes[i].line.plot(starterNodes[i].node.cx(), starterNodes[i].node.cy(), x, y);
                }
            }
        };
    };

    function displayTab(tab) {
        for (var i = 0; i < tabs.length; i++) {
            tabs[i].classList.remove("selected-tab");
            views[i].style.display = "none";
        }
        componentControls.style.visibility = "hidden";
        tab.classList.add("selected-tab");
        if (tab === interfaceTab) {
            interfaceView.style.display = "block";
        } else if (tab === modelTab) {
            modelView.style.display = "block";
            componentControls.style.visibility = "visible";
        }
    }

    function deselectModelButtons() {
        for (var i = 0; i < modelButtons.length; i++) {
            modelButtons[i].classList.remove("selected-control");
        }
        selectedButton = null;
    }

    function selectModelButton(button) {
        button.classList.add("selected-control");
        selectedButton = button;
    }

    var UPDATE_ORDER = [0, 1, 2];
    var RESET_ORDER = [0, 2, 1];
    function orderedSvg() {
        var ordered = [[], [], []];
        for (var i = 0; i < svgComponents.length; i++) {
            var c = svgComponents[i];
            if (c instanceof SvgConverter) {
                ordered[0].push(c);
            } else if (c instanceof SvgFlow) {
                ordered[1].push(c);
            } else if (c instanceof SvgStock) {
                ordered[2].push(c);
            }
        }
        return ordered;
    }

    function selectSvgComponent(c) {
        selectedSvgComponent = c;
        updateNames(selectedSvgComponent.name);

        equationEditor.setValue(c.equationString);
        equationEditor.clearSelection();

        for (var i = 0; i < svgComponents.length; i++) {
            svgComponents[i].image.unfilter();
        }
        selectedSvgComponent.image.filter(function(add) {
            add.colorMatrix('hueRotate', 180);
        });
    }

    function deselectSvgComponent() {
        selectedSvgComponent = null;
        updateNames("");
        equationEditor.setValue("");
        for (var i = 0; i < svgComponents.length; i++) {
            svgComponents[i].image.unfilter();
        }
    }

    function sortSvgComponents() {
        svgComponents.sort(function(a, b) {
            if (a.name < b.name) {
                return -1;
            } else if (a.name > b.name) {
                return 1;
            } else {
                return 0;
            }
        });
        deleteAllChildren(observedComponentSelector);
        var option;
        for (var i = 0; i < svgComponents.length; i++) {
            option = document.createElement("option");
            option.innerHTML = svgComponents[i].name;
            observedComponentSelector.appendChild(option);
            if (svgComponents[i] === selectedSvgComponent) {
                observedComponentSelector.selectedIndex = i;
            }
        }
    }

    function updateNames(name) {
        for (var i = 0; i < selectedComponentNameElements.length; i++) {
            selectedComponentNameElements[i].innerHTML = name;
            selectedComponentNameElements[i].value = name;
        }

        var ni = findName(name);
        if (ni !== -1) {
            observedComponentSelector.childNodes[ni].innerHTML = name;
        }
    }

    function findName(name) {
        for (var i = 0; i < svgComponents.length; i++) {
            if (svgComponents[i].name == name) {
                return i;
            }
        }
        return -1;
    }

    function nameToComponent(s) {
        var leftFind = "{{";
        var rightFind = "}}";
        var ret = "";
        var left = s.indexOf(leftFind);
        var right = 0 - rightFind.length;
        while (left != -1) {
            ret += s.substring(right + rightFind.length, left);
            right = s.indexOf(rightFind, right + 1);
            if (right == -1) {
                alert("parse error");
            }
            var name = s.substring(left + leftFind.length, right);
            var ni = findName(name);
            if (ni != -1) {
                ret += "svgComponents[" + ni + "].component.value";
            }
            left = s.indexOf(leftFind, left + 1);
        }
        ret += s.substring(right + rightFind.length);
        return ret;
    }

    function functionBody(f) {
        var s = f.toString();
        s = s.replace("\"use strict\";\n", "");
        return s.substring(s.indexOf("{") + 1, s.lastIndexOf("}")).trim();
    }

    function deleteAllChildren(e) {
        while (e.firstChild) {
            e.removeChild(e.firstChild);
        }
    }
 
    function clearTableData() {
        deleteAllChildren(dataTableOutput);
    }

    function addRow(table, cData) {
        var row = document.createElement("tr");
        var col;
        for (var i = 0; i < cData.length; i++) {
            col = document.createElement("td");
            col.innerHTML = cData[i];
            row.appendChild(col);
        }
        table.appendChild(row);
    }

    function updateRow(table, r, cData) {
        for (var i = 0; i < cData.length; i++) {
            table.childNodes[r].childNodes[i].innerHTML = cData[i];
        }
    }

    function setupDataTable(i) {
        for (var r = 0; r < runData[i].length; r++) {
            addRow(dataTableOutput, runData[i][r]);
        }
        updateTimeplot(i);
    }

    function updateDataTable(i) {
        for (var r = 0; r < runData[i].length; r++) {
            updateRow(dataTableOutput, r, runData[i][r]);
        }
        updateTimeplot(i);
    }

    function updateTimeplot(i) {
        var options = {
            file: runData[i],
            labels: ["t", svgComponents[i].name],
            valueRange: [minimums[i] - 10, maximums[i] + 10]
        }
        options[svgComponents[i].name] = {
            color: "#00C6FF"
        }
        timeplot.updateOptions(options);
    }

    function isInt(n, p) {
        return n - Math.floor(n) < p;
    }

    function wx(x) {
        return x - workspace.offsetLeft;
    }

    function wy(y) {
        return y - workspace.offsetTop;
    }
})();
