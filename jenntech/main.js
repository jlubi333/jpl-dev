(function() {
    "use strict";

    var elementMap = {
        "H":   ["Hydrogen", 1, 1.00794],
        "He":  ["Helium", 2, 4.002602],
        "Li":  ["Lithium", 3, 6.941],
        "Be":  ["Beryllium", 4, 9.012182],
        "B":   ["Boron", 5, 10.811],
        "C":   ["Carbon", 6, 12.011],
        "N":   ["Nitrogen", 7, 14.00674],
        "O":   ["Oxygen", 8, 15.9994],
        "F":   ["Fluorine", 9, 18.9984032],
        "Ne":  ["Neon", 10, 20.1797],
        "Na":  ["Sodium", 11, 22.989768],
        "Mg":  ["Magnesium", 12, 24.305],
        "Al":  ["Aluminum", 13, 26.981539],
        "Si":  ["Silicon", 14, 28.0855],
        "P":   ["Phosphorus", 15, 30.973762],
        "S":   ["Sulfur", 16, 32.066],
        "Cl":  ["Chlorine", 17, 35.4527],
        "Ar":  ["Argon", 18, 39.948],
        "K":   ["Potassium", 19, 39.0983],
        "Ca":  ["Calcium", 20, 40.078],
        "Sc":  ["Scandium", 21, 44.95591],
        "Ti":  ["Titanium", 22, 47.88],
        "V":   ["Vanadium", 23, 50.9415],
        "Cr":  ["Chromium", 24, 51.9961],
        "Mn":  ["Manganese", 25, 54.93805],
        "Fe":  ["Iron", 26, 55.847],
        "Co":  ["Cobalt", 27, 58.9332],
        "Ni":  ["Nickel", 28, 58.6934],
        "Cu":  ["Copper", 29, 63.546],
        "Zn":  ["Zinc", 30, 65.39],
        "Ga":  ["Gallium", 31, 69.723],
        "Ge":  ["Germanium", 32, 72.61],
        "As":  ["Arsenic", 33, 74.92159],
        "Se":  ["Selenium", 34, 78.96],
        "Br":  ["Bromine", 35, 79.904],
        "Kr":  ["Krypton", 36, 83.8],
        "Rb":  ["Rubidium", 37, 85.4678],
        "Sr":  ["Strontium", 38, 87.62],
        "Y":   ["Yttrium", 39, 88.90585],
        "Zr":  ["Zirconium", 40, 91.224],
        "Nb":  ["Niobium", 41, 92.90638],
        "Mo":  ["Molybdenum", 42, 95.94],
        "Tc":  ["Technetium", 43, 98],
        "Ru":  ["Ruthenium", 44, 101.07],
        "Rh":  ["Rhodium", 45, 102.9055],
        "Pd":  ["Palladium", 46, 106.42],
        "Ag":  ["Silver", 47, 107.8682],
        "Cd":  ["Cadmium", 48, 112.411],
        "In":  ["Indium", 49, 114.82],
        "Sn":  ["Tin", 50, 118.71],
        "Sb":  ["Antimony", 51, 121.757],
        "Te":  ["Tellurium", 52, 127.6],
        "I":   ["Iodine", 53, 126.90447],
        "Xe":  ["Xenon", 54, 131.29],
        "Cs":  ["Cesium", 55, 132.90543],
        "Ba":  ["Barium", 56, 137.327],
        "La":  ["Lanthanum", 57, 138.9055],
        "Ce":  ["Cerium", 58, 140.115],
        "Pr":  ["Praseodymium", 59, 140.90765],
        "Nd":  ["Neodymium", 60, 144.24],
        "Pm":  ["Promethium", 61, 145],
        "Sm":  ["Samarium", 62, 150.36],
        "Eu":  ["Europium", 63, 151.965],
        "Gd":  ["Gadolinium", 64, 157.25],
        "Tb":  ["Terbium", 65, 158.92534],
        "Dy":  ["Dysprosium", 66, 162.5],
        "Ho":  ["Holmium", 67, 164.93032],
        "Er":  ["Erbium", 68, 167.26],
        "Tm":  ["Thulium", 69, 168.93421],
        "Yb":  ["Ytterbium", 70, 173.04],
        "Lu":  ["Lutetium", 71, 174.967],
        "Hf":  ["Hafnium", 72, 178.49],
        "Ta":  ["Tantalum", 73, 180.9479],
        "W":   ["Tungsten", 74, 183.85],
        "Re":  ["Rhenium", 75, 186.207],
        "Os":  ["Osmium", 76, 190.2],
        "Ir":  ["Iridium", 77, 192.22],
        "Pt":  ["Platinum", 78, 195.08],
        "Au":  ["Gold", 79, 196.96654],
        "Hg":  ["Mercury", 80, 200.59],
        "Tl":  ["Thallium", 81, 204.3833],
        "Pb":  ["Lead", 82, 207.2],
        "Bi":  ["Bismuth", 83, 208.98037],
        "Po":  ["Polonium", 84, 209],
        "At":  ["Astatine", 85, 210],
        "Rn":  ["Radon", 86, 222],
        "Fr":  ["Francium", 87, 223],
        "Ra":  ["Radium", 88, 226.025],
        "Ac":  ["Actinium", 89, 227.028],
        "Th":  ["Thorium", 90, 232.0381],
        "Pa":  ["Protactinium", 91, 231.0359],
        "U":   ["Uranium", 92, 238.0289],
        "Np":  ["Neptunium", 93, 237.048],
        "Pu":  ["Plutonium", 94, 244],
        "Am":  ["Americium", 95, 243],
        "Cm":  ["Curium", 96, 247],
        "Bk":  ["Berkelium", 97, 247],
        "Cf":  ["Californium", 98, 251],
        "Es":  ["Einsteinium", 99, 252],
        "Fm":  ["Fermium", 100, 257],
        "Md":  ["Mendelevium", 101, 258],
        "No":  ["Nobelium", 102, 259],
        "Lr":  ["Lawrencium", 103, 262],
        "Rf":  ["Rutherfordium", 104, 261],
        "Db":  ["Dubnium", 105, 262],
        "Sg":  ["Seaborgium", 106, 263],
        "Bh":  ["Bohrium", 107, 262],
        "Hs":  ["Hassium", 108, 265],
        "Mt":  ["Meitnerium", 109, 266]
    }

    var CAPS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    var LOWERS = "abcdefghijklmnopqrstuvwxyz";
    var NUMS = "1234567890";

    var ENTER_KEY = 13;

    window.onload = function() {
        var outputTable = document.getElementById("output-table");

        var elementInput = document.getElementById("element-input");
        elementInput.onkeydown = function(e) {
            if (e.keyCode == ENTER_KEY) {
                calculateMolarMass(elementInput.value, outputTable);
            }
        }

        var elementButton = document.getElementById("element-button");
        elementButton.onclick = function(e) {
            calculateMolarMass(elementInput.value, outputTable);
        }
    }

    function calculateMolarMass(elementString, outputTable) {
        deleteAllChildren(outputTable);
        
        addDataRow(outputTable, "Atom", "#", "Molar Mass");

        var els = toElementHistogram(elementString);
        var total = 0;
        var m;
        var row, cols;
        for (var e in els) {
            if (els.hasOwnProperty(e)) {
                m = els[e] * elementMap[e][2];
                total += m;
                addDataRow(outputTable, e, els[e], m);
            }
        }

        addDataRow(outputTable, "Total", "", total);
    }

    function deleteAllChildren(e) {
        while (e.firstChild) {
            e.removeChild(e.firstChild);
        }
    }

    function addDataRow(outputTable, a, b, c) {
        var row = document.createElement("tr"); 

        var cols = [];
        for (var i = 0; i < 3; i++) {
            cols.push(document.createElement("td"));
        }

        cols[0].innerHTML = a;
        cols[1].innerHTML = b;
        cols[2].innerHTML = c;

        for (var i = 0; i < 3; i++) {
            row.appendChild(cols[i]);
        }

        outputTable.appendChild(row);
    }

    function isUpper(c) {
        return CAPS.indexOf(c) != -1;
    }

    function isLower(c) {
        return LOWERS.indexOf(c) != -1;
    }

    function isNumber(c) {
        return NUMS.indexOf(c) != -1;
    }

    function addToHistogram(h, v, amount) {
        if (v in h) {
            h[v] += amount;
        } else {
            h[v] = amount;
        }
    }

    function toElementHistogram(elementString) {
        var els = {};
        var currentChar, nextChar, element;
        for (var i = 0; i < elementString.length - 1; i++) {
            currentChar = elementString.charAt(i);
            nextChar = elementString.charAt(i + 1);
            if (isUpper(currentChar)) { 
                if (isLower(nextChar)) {
                    element = currentChar + nextChar;
                } else {
                    element = currentChar;
                }
                var num = 1;
                if (isNumber(nextChar)) {
                    num = parseInt(nextChar);
                }
                addToHistogram(els, element, num);
            } else {
                if (currentChar == "(") {
                    var rightParen = elementString.indexOf(")", i);
                    var charAfterRightParen = elementString.charAt(rightParen + 1);
                    var num = 1;
                    if (isNumber(charAfterRightParen)) {
                        num = parseInt(charAfterRightParen);
                    }
                    var miniEls = toElementHistogram(elementString.substring(i+1, elementString.indexOf(")", i)));
                    for (var e in miniEls) {
                        if (miniEls.hasOwnProperty(e)) {
                            addToHistogram(els, e, num);
                        }
                    }
                    i = rightParen;
                }
                continue;
            }
        }

        var lastChar = elementString.charAt(elementString.length - 1);
        if (isUpper(lastChar)) {
            addToHistogram(els, lastChar, 1);
        }

        return els;
    }
})();
