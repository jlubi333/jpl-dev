$(document).ready(
	function()
	{
		var mapOptions =
		{
			center: new google.maps.LatLng(26.7467132, -80.0385207),
			zoom: 8,
			mapTypeId: google.maps.MapTypeId.ROADMAP
		};
		var map = new google.maps.Map(document.getElementById("mapCanvas"), mapOptions);
	}
);