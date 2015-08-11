(function (){
    window.onload = function() {
        var gameWheelSound = new Audio("gameWheel.mp3");
        var dingSound = new Audio("ding.wav");
        var buzzerSound = new Audio("buzzer.wav");

        var check = document.getElementById("check");
        var noCheck = document.getElementById("no-check");
        var go = document.getElementById("go");

        var speed = 75;
        var timeLimit = 5100; // Game Wheel Audio Length
        var countLimit = timeLimit / speed;

        var c = 0;
        var running = false;
        go.onclick = function(event) {
            if (running) {
                return;
            }
            running = true;
            gameWheelSound.play();
            check.classList.add("on");
            noCheck.classList.remove("on");
            var flicker = setInterval(function() {
                check.classList.toggle("on")
                noCheck.classList.toggle("on")

                c += 1;

                if (c > countLimit) {
                    check.classList.remove("on");
                    noCheck.classList.remove("on");
                    if (Math.random() > 0.5) {
                        buzzerSound.play();
                        check.classList.add("on");
                    } else {
                        dingSound.play();
                        noCheck.classList.add("on");
                    }

                    clearInterval(flicker);
                    c = 0;
                    running = false;
                }
            }, speed);
        }

    }
})();
