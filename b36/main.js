(function() {
    "use strict";

    function gcd(a, b) {
        var r;
        while (true) {
            r = a % b;
            if (r == 0) {
                return b;
            }
            a = b;
            b = r;
        }
    }

    var DIGITS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    function process(message) {
        message = message.replace(/\s/g, "").toUpperCase();
        var n, d, g;
        n = 0;
        for (var i = 0; i < message.length; i++) {
            n = 36 * n + DIGITS.indexOf(message.charAt(i));
        }
        d = Math.pow(36, message.length) - 1;
        g = gcd(n, d);
        n = Math.floor(n / g);
        d = Math.floor(d / g);
        return n + "/" + d;
    }

    window.onload = function() {
        var userInput = document.getElementById("user-input");
        var output = document.getElementById("output");

        userInput.onkeydown = function(event) {
            if (event.keyCode == 13) {
                output.innerHTML = process(userInput.value);
            }
        }
    }
})();
