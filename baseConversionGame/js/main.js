$(document).ready(
	function()
	{
		// JavaScript is obviously enabled
		$("#needJavaScript").hide();

		var firebaseDataRef = new Firebase("https://jpl-baseconversiongame.firebaseio.com");

		// Elements
		var canvases = $("#boardArea").children("canvas");

		// If canvas is supported
		if(canvases[0].getContext)
		{
			// Firebase
			var numPlayers = 3;
			var playerNumber = 0;
			var userCanvas = canvases[playerNumber];

			// Settings
			var rows = 5;
			var cols = 6;
			var masterCardTextArray = shuffle(["0000", "0001", "0010", "0011", "0100", "0101", "0110", "0111", "1000", "1001", "1010", "1011", "1100", "1101", "1110", "1111"]);

			// Actual Boards
			var boards = [];

			// Initialize boards
			for(var i = 0; i < canvases.length; i++)
			{
				canvases[i].width = window.innerWidth * 0.4;
				canvases[i].height = window.innerHeight* 0.4;
				var context = canvases[i].getContext("2d");
				boards[i] = new Board(context, masterCardTextArray, i === playerNumber, rows, cols, "red", 100, 40, "#CCCCCC", "#111111", "20px Arial", 10);
				boards[i].draw();
			}

			// Clicks
			$(userCanvas).mousedown(
				function(event)
				{
					event.preventDefault();
					console.log("yes");
					var board = boards[$(this).index()];
					var x = event.pageX - this.offsetLeft;
					var y = event.pageY - this.offsetTop;

					for(var row = 0; row < board.cardArray.length; row++)
					{
						for(var col = 0; col < board.cardArray[row].length; col++)
						{
							card = board.cardArray[row][col];
							if(
								x >= this.offsetLeft + board.convertToXCoord(card.col)
								// && x <= this.offsetLeft + board.convertToXCoord(card.col) + board.cardWidth
								// && y >= this.offsetTop + board.convertToYCoord(card.row)
								// && y <= this.offsetTop + board.convertToYCoord(card.row) + board.cardHeight
							)
							{
								//console.log(this.offsetLeft);
							}
						}
					}
				}
			);
		}
		else
		{
			alert("Sorry, but your browser is outdated and you cannot play this game.");
		}

		firebaseDataRef.push({f:"1"});
	}
);

function shuffle(array)
{
	var m = array.length, t, i;

	while(m)
	{
		i = Math.floor(Math.random() * m--);

		t = array[m];
		array[m] = array[i];
		array[i] = t;
	}

	return array;
}

/* Board */

function Board(context, masterCardTextArray, isUserCanvas, rows, cols, backgroundStyle, cardWidth, cardHeight, cardBackgroundStyle, cardTextStyle, cardFont, cardMargin)
{
	this.context = context;
	this.isUserCanvas = isUserCanvas;
	this.backgroundStyle = backgroundStyle;

	this.cardWidth = cardWidth;
	this.cardHeight = cardHeight;
	this.cardBackgroundStyle = cardBackgroundStyle;
	this.cardTextStyle = cardTextStyle;
	this.cardFont = cardFont;
	this.cardMargin = cardMargin;

	this.cardArray = new Array(rows);
	var counter = 0;
	for(var row = 0; row < rows; row++)
	{
		this.cardArray[row] = new Array(cols);
		for(var col = 0; col < cols; col++)
		{
			if(counter > masterCardTextArray.length - 1)
			{
				this.cardArray[row][col] = undefined;
			}
			else
			{
				this.cardArray[row][col] = new Card(this, row, col, masterCardTextArray[counter]);
			}
			counter += 1;
		}
	}
	console.log(this.cardArray);
}

Board.prototype.draw = function()
{
	this.drawCards();
	if(!this.isUserCanvas)
	{
		this.context.save();
		this.context.fillStyle = "rgba(0, 0, 0, 0.7)";
		this.context.fillRect(0, 0, this.context.canvas.width, this.context.canvas.height);
		this.context.restore();
	}
};

Board.prototype.drawCards = function()
{
	for(var row = 0; row < this.cardArray.length; row++)
	{
		for(var col = 0; col < this.cardArray[row].length; col++)
		{
			if(this.cardArray[row][col] === undefined)
			{
				continue;
			}

			this.drawCard(this.cardArray[row][col]);
		}
	}
};

Board.prototype.drawCard = function(card)
{
	this.context.save();

	this.context.textBaseline = "middle";
	this.context.textAlign = "center";
	this.context.font = this.cardFont;

	var xCoord = this.convertToXCoord(card.col);
	var yCoord = this.convertToYCoord(card.row);

	this.context.fillStyle = this.cardBackgroundStyle;
	this.context.fillRect(xCoord, yCoord, this.cardWidth, this.cardHeight);

	this.context.fillStyle = this.cardTextStyle;
	this.context.fillText(card.displayText, xCoord + (this.cardWidth / 2), yCoord + (this.cardHeight / 2));

	this.context.restore();
}

Board.prototype.convertToXCoord = function(col)
{
	return (this.cardWidth + this.cardMargin) * col;
};

Board.prototype.convertToYCoord = function(row)
{
	return (this.cardHeight + this.cardMargin) * row;
};

/* Card */

function Card(board, row, col, displayText)
{
	this.board = board;
	this.row = row;
	this.col = col;
	this.displayText = displayText;
}