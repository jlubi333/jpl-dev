(function() {
    var firstLine = [
        ["How could it be ___?", "Why must it be ___?", "___: it is reason;", "I see now, true ___.", "Behold! It is ___!", "Foreshadowing ___!"],
        ["Why is it ___?", "I foresee ___.", "I'm ___, but you..."],
        ["It is ___.", "Hello, ___.", "Why now, ___?", "During ___:", "The sole ___.", "Only ___;"],
        ["I'm ___.", "The ___!", "___... yes,", "Hark! ___!"],
        ["___.", "___...", "___!", "___?", "___;"]
    ];

    var secondLine = [
        "Forever it will be this.",
        "When it is this, you know all.",
        "It knows me as you know me...",
        "Now, this is the final time,",
        "When it's by me, the only...",
        "For how could it do this act?"
    ];

    var thirdLine = [
        ["It ends with sad ___.", "Eternally ___...", "___ never shall die.", "Why ___ in this world?", "___—stuck in this world."],
        ["Why would you, ___?", "It's ___ and all.", "It's ___; it's done.", "This is it, ___.", "I see the ___."],
        ["I see ___.", "You see ___?", "We all ___...", "For now, ___.", "Goodbye, ___."],
        ["Now, ___.", "Dear ___...", "___ now."],
        ["___.", "___...", "___!", "___?"]
    ];

    var subjectInput, syllablesInput, generatePoemButton;
    var syllables, haiku;
    var subject, syllableCount;

    $(document).ready(function() {
        subjectInput = $("#subject-input");
        syllablesInput = $("#syllables-input");
        generatePoemButton = $("#generate-poem");
        syllables = $("#syllables");
        haiku = $("#haiku");

        var subject = "";
        var syllableCount = 1;

        subjectInput.keypress(function(event) {
            if(event.which == 13) {
                setSubject();
                barge(syllables);
                syllablesInput.focus();
            }
        });
        syllablesInput.keypress(function(event) {
            if(event.which == 13) {
                setSyllableCount();
                barge(generatePoemButton);
                generatePoemButton.focus();
            }
        });
        generatePoemButton.click(function(event) {
            setSubject();
            setSyllableCount();
            setHaiku();
            barge(haiku);
        });
    });

    function barge(element) {
        element.addClass("barge");
    }

    function setSubject() {
        subject = subjectInput.val();
        $(".the-subject").html(subject);
    }

    function setSyllableCount() {
        syllableCount = parseInt(syllablesInput.val());
        if(syllableCount < 1 || syllableCount > 5) {
            syllableCount = 5;
        }
    }

    function setHaiku() {
        haiku.html(makeHaiku(subject, syllableCount));
    }

    function makeHaiku() {
        subject = "<strong>" + subject.toUpperCase() + "</strong>";
        haikuString = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~<br />"

        var firstRandom = Math.floor(Math.random() * firstLine[syllableCount - 1].length);
        haikuString += firstLine[syllableCount - 1][firstRandom].replace("___", subject) + "<br />";

        var secondRandom = Math.floor(Math.random() * secondLine.length);
        haikuString += secondLine[secondRandom].replace("___", subject) + "<br />";

        var thirdRandom = Math.floor(Math.random() * thirdLine[syllableCount - 1].length);
        haikuString += thirdLine[syllableCount - 1][thirdRandom].replace("___", subject) + "<br />";

        haikuString += "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

        return haikuString;
    }

})();
