(function() {
    "use strict";

    function Pixel(r, g, b) {
        this.r = r;
        this.g = g;
        this.b = b;
    }
    Pixel.prototype.colorString = function() {
        return "rgb(" + this.r + "," + this.g + "," + this.b + ")";
    }

    var paintCanvas;
    var pixels = [];

    window.onload = function() {
        paintCanvas = document.getElementById("main-canvas");
        
        var width = paintCanvas.width;
        var height = paintCanvas.height;

        for (var r = 0; r < height; r++) {
            var row = [];
            for (var c = 0; c < width; c++) {
                row.push(new Pixel(255, 255, 255));
            }
            pixels.push(row);
        }
    }
})();
