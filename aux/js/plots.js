/*
var previous_scroll = $(window).scrollTop();

window.onscroll = function (event) {

    	var scroll = $(window).scrollTop();
    	scroll_change = scroll - previous_scroll;
   	previous_scroll = scroll;

    	if(scroll_change > 0)
		console.log("down");
    	else
		console.log("up");

    	var button =  document.getElementById("show_all_plots");

    	if(button.status == "pressed"){
		show_all_plots(button);
    	}
}*/

function show_all_plots(button){

	var expand_children = document.getElementsByClassName('expand-child');

	if(expand_children.length < 30){

		alert("This may take a while. Please wait...");

		if(button.status != "pressed"){
			button.status = "pressed";
			button.innerHTML = "<i class='icon-bar-chart' style='font-size: 25px;'></i> <br> <b>Hide all plots</b>"
			button.onclick = function() { 
				hide_all_plots(button) 
			};
   		}

		//display plots in the dom
		var buttons_dom = document.querySelectorAll('button')

		// remove all plots
		remove_all_plots();

		for (var i = 0; i < buttons_dom.length; i++) {
			expand_child_div = expand_children[i].getElementsByTagName('div')[0];
			show_plot(buttons_dom[i], expand_child_div);
		}
	}
	else{
		alert("Operation not posible. Too many queries...");
	}

}

function show_plot(pressedButton, expand_child_div){

	//expand_child_div.innerHTML = "";

	if(pressedButton.status != "pressed"){
		eval(pressedButton.onclick.toString().replace("function onclick(event) {","").replace("}",""));
		pressedButton.status="pressed";
		expand_child_div.style.display = "block";
	}

}

function remove_all_plots(){

	var extensions = document.querySelectorAll('div')
	for (var i = 0; i < extensions.length; i++) {
		if(extensions[i].id.search(/toggle*/) == 0){
			d3.select("#".concat(extensions[i].id)).selectAll("svg").remove();
		}
	}

	var buttons = document.getElementsByTagName('button');
	for (var i = 0; i < buttons.length; i++) {
		buttons[i].status = "released";	
	}
}

function hide_all_plots(button){

	button.status = "released";
	button.innerHTML = "<i class='icon-bar-chart' style='font-size: 25px;'></i> <br> <b>Show all plots</b>"
  	button.onclick = function() { 
        	show_all_plots(button) 
        };

	remove_all_plots();
}

function getElementByAttributeValue(attribute, value)
{
  var allElements = document.getElementsByTagName('*');
  for (var i = 0; i < allElements.length; i++)
   {
    if (allElements[i].getAttribute(attribute) == value)
    {
      return allElements[i];
    }
  }
  return null;
}

function showDiv(source, target){

   var button = document.getElementById(target)

   if(source.status == "pressed"){
     button.style.display = "none";
   }
   else{
     d3.select("#".concat(target)).selectAll("svg").remove();    
     button.style.display = "block";
     var pressedButtons = document.querySelectorAll('td')
     for (var i = 0; i < pressedButtons.length; i++) {
        if(pressedButtons[i].status == "pressed"){
           pressedButtons[i].status = "released"
        }
     }
   }

   if(source.status=="pressed")
     source.status="released"
   else
     source.status="pressed"

}

function addPlot(target, filename, type, title, footer, xtitle, ytitle, aux1, aux2){

        if (footer == '')
          var legend = []
        else
	  var legend = footer.split(";");

	switch(type){
		case "scatter":
		  plot_scatter(filename, target, title, footer, xtitle, ytitle, aux1, aux2)
		  break;
		case "bars":
		  plot_bars(filename, target, title, legend, xtitle, ytitle, aux1)
		  break;
		case "simplebars":
		  plot_simple_bars(filename, target, title, legend, xtitle, ytitle)	
		  break;
		case "lines":
                  if(aux2 != "")
	              aux2 = aux2.split(",");
		  plot_lines(filename, target, title, legend, xtitle, ytitle, aux1, aux2)
		  break;
		case "align":
                  if(aux2 != "")
	              aux2 = aux2.split(",");
		  plot_align(filename, target, title, legend, xtitle, ytitle, aux1, aux2)
		  break;
		default:
		  break;
	}	
}


function color_beautification(color){

   	switch(color){
		case "red":
      			return d3.rgb(189,54,47);
        	case "blue":
			return d3.rgb(58,135,173);
		case "green":
			return d3.rgb(70,136,71);
		case "yellow":
			return d3.rgb(255,255,51);
		case "orange":
			return d3.rgb(248,148,6);
		case "violet":
			return d3.rgb(153,0,153);
		case "gray":
			return d3.rgb(160,160,160);
		default:
		  	return color;
	}

}

// bars plot
function plot_bars(filename, target, title, footer, xTitle, yTitle, bar){

	var margin = {top: 70, right: 50, bottom: 75, left: 50},
		width = 600 - margin.left - margin.right,
		height = 500 - margin.top - margin.bottom;		
	var legend_width = 15

	var svg = d3.select("#".concat(target)).append("svg")
		.attr("width", width + margin.left + margin.right)
		.attr("height", height + margin.top + margin.bottom)
	  	.append("g")
			.attr("transform", "translate(" + margin.left + "," + margin.top + ")");
		
	svg.append("text")
		.attr("x", (width / 2))             
		.attr("y", -45)
		.attr("text-anchor", "middle")  
		.style("font-size", "16px") 
		.text(title);	
		
	var colors = new Array("orange", "blue", "green", "yellow", "brown");
	var no_colors = colors.length

        var padding = 100

	d3.json(filename, function(error, alldata) {
		
		flattened_data = [].concat.apply([], alldata)			
		var yMax = d3.max(flattened_data, function(d) { return d.value; }) + 3
		var y = d3.scale.linear()
                     .domain([0, yMax + yMax/10])
                     .range([height, 0]);

		var xMin = d3.min(flattened_data, function(d) { return d.key; })
		if(bar!=undefined){
                	var xMin = Math.min(xMin, bar); 
		}
 
                var xMax = d3.max(flattened_data, function(d) { return d.key; })
		if(bar!=undefined){
			var xMax = Math.max(xMax, bar); 
		}

		var x = d3.scale.linear()
                     .domain([xMin-padding, xMax+padding])
                     .range([13, width]);

		var xAxis = d3.svg.axis()
		        .scale(x)
		        .orient("bottom")
			.ticks(8)

	        var yAxis = d3.svg.axis()
			.scale(y)
			.orient("left")
			.tickFormat(d3.format("d"))
			.ticks(8)

	  	svg.append("g")
			  .attr("class", "x axis")
			  .attr("transform", "translate(0," + height + ")")
			  .call(xAxis)
			.append("text")
			  .attr("class", "label")
			  .attr("x", (width-xTitle.length)/2-50)
			  .attr("y", 35)
			  .style("text-anchor", "start")
			  .text(xTitle)

	 	 svg.append("g")
			   .attr("class", "y axis")
			  .call(yAxis)
			.append("text")
			  .attr("class", "label")
			  .attr("transform", "rotate(-90)")
			  .attr("x", -(height+yTitle.length)/2-50)
			  .attr("y", -40)
			  .style("text-anchor", "start")
			  .text(yTitle)
			  
		alldata.map( function(data, i) {
		 
			color = colors[i % (no_colors - 1)];
			svg.selectAll(".bar")
				.data(data)
				.enter().append("rect")
				  .attr("x", function(d) { return x(d.key); })
				  .attr("width", 6)
				  .attr("y", function(d) { return y(d.value); })
				  .attr("height", function(d) { return height - y(d.value); })
				  .attr("fill", function(d) { if (d.main == true) return color_beautification("red"); return color_beautification("blue");});
		});	

		if(bar!=undefined){
			svg.append("rect")
				.attr("x", x(bar))
				.attr("width", 4)
				.attr("y", y(yMax + yMax/10))
				.style("opacity",0.6)
				.attr("height", height - y(yMax + yMax/8))
				.attr("fill", color_beautification("black"));

			svg.append("text")
				.attr("transform", "rotate(-90)")
				.attr("x", -yMax/10 - 35)
				.attr("y", x(bar) - 5)
			      	.text("query");

				}	
	});

   
      
    var offset = 0
    var total_len = 0
    for (var i = 0; i < footer.length; i++) {
	var array = footer[i].split(","); 
	total_len = total_len + array[0].length*8 + 15;
    }

    for (var i = 0; i < footer.length; i++) {

	var array = footer[i].split(","); 
	svg.append("rect")
	      .attr("x", (width-total_len)/2 + offset)             
	      .attr("y", -30)
	      .attr("width", 10)
	      .attr("height", 10)
	      .style("fill", color_beautification(array[1].replace(/\s+/g, '')))
        
	svg.append("text")
	      .attr("x", (width-total_len)/2 + offset + 15)             
	      .attr("y", -20)
	      .text(array[0]);
        offset = offset + array[0].length*8 + 15

    }



}	

// bars plot
function plot_simple_bars(filename, target, title, footer, xTitle, yTitle){

	var margin = {top: 70, right: 50, bottom: 75, left: 50},
		width = 600 - margin.left - margin.right,
		height = 500 - margin.top - margin.bottom;		
	var legend_width = 15

	var svg = d3.select("#".concat(target)).append("svg")
		.attr("width", width + margin.left + margin.right)
		.attr("height", height + margin.top + margin.bottom)
	  	.append("g")
			.attr("transform", "translate(" + margin.left + "," + margin.top + ")");
		
	svg.append("text")
		.attr("x", (width / 2))             
		.attr("y", -45)
		.attr("text-anchor", "middle")  
		.style("font-size", "16px") 
		.text(title);	
		
	var colors = new Array("orange", "blue", "green", "yellow", "brown");
	var no_colors = colors.length

        var padding = 0

	d3.json(filename, function(error, alldata) {
		
		flattened_data = [].concat.apply([], alldata)			
		var yMax = d3.max(flattened_data, function(d) { return d.value; }) + 3
		var y = d3.scale.linear()
                     .domain([0, yMax])
                     .range([height, 0]);

		var xMin = d3.min(flattened_data, function(d) { return d.key; })
                var xMax = d3.max(flattened_data, function(d) { return d.key; })

		var x = d3.scale.linear()
                     .domain([xMin-padding, xMax+padding])
                     .range([13, width]);

		var xAxis = d3.svg.axis()
		        .scale(x)
		        .orient("bottom")
			.ticks(8)

	        var yAxis = d3.svg.axis()
			.scale(y)
			.orient("left")
			.tickFormat(d3.format("d"))
			.ticks(8)

	  	svg.append("g")
			  .attr("class", "x axis")
			  .attr("transform", "translate(0," + height + ")")
			  .call(xAxis)
			.append("text")
			  .attr("class", "label")
			  .attr("x", (width-xTitle.length)/2-50)
			  .attr("y", 35)
			  .style("text-anchor", "start")
			  .text(xTitle)

	 	 svg.append("g")
			   .attr("class", "y axis")
			  .call(yAxis)
			.append("text")
			  .attr("class", "label")
			  .attr("transform", "rotate(-90)")
			  .attr("x", -(height+yTitle.length)/2-50)
			  .attr("y", -40)
			  .style("text-anchor", "start")
			  .text(yTitle)
			  
		alldata.map( function(data, i) {
		 
			color = colors[i % (no_colors - 1)];
			svg.selectAll(".bar")
				.data(data)
				.enter().append("rect")
				  .attr("x", function(d) { return x(d.key); })
				  .attr("width", 6)
				  .attr("y", function(d) { return y(d.value); })
				  .attr("height", function(d) { return height - y(d.value); })
				  .attr("fill", function(d) { if (d.main == true) return color_beautification("red"); return color_beautification("blue");});
		});	

	});

}


// scatter plot
// ecuation of the line: slope * x + yLine
function plot_scatter(filename, target, title, footer, xTitle, yTitle, yLine, slope){

	var margin = {top: 50, right: 30, bottom: 75, left: 50},
		width = 500 - margin.left - margin.right,
		height = 500 - margin.top - margin.bottom;		

	var x = d3.scale.linear()
		.range([0, width]);
	var y = d3.scale.linear()
		.range([height, 0]);

	var color = d3.scale.category10();

	var xAxis = d3.svg.axis()
		.scale(x)
		.orient("bottom")
		.ticks(8);
	var yAxis = d3.svg.axis()
		.scale(y)
		.orient("left")
		.tickFormat(d3.format("d"))
		.ticks(8);

	var svg = d3.select("#".concat(target)).append("svg")
		.attr("width", width + margin.left + margin.right)
		.attr("height", height + margin.top + margin.bottom)
	  	.append("g")
			.attr("transform", "translate(" + margin.left + "," + margin.top + ")");
		
	svg.append("text")
		.attr("x", (width / 2))             
		.attr("y", -25)
		.attr("text-anchor", "middle")  
		.style("font-size", "16px") 
		.text(title);	

	svg.append("text")
		.attr("x", (width / 2))             
		.attr("y", height+ 55)
		.attr("text-anchor", "middle")  
		.style("font-size", "12px") 
		.text(footer);	

	d3.json(filename, function(error, data) {

          var xMax = d3.max(data, function(d) { return d.x; })
          var xMin = d3.min(data, function(d) { return d.x; })
          var yMax = d3.max(data, function(d) { return d.y; })
          var yMin = d3.min(data, function(d) { return d.y; })
	  x.domain(d3.extent(data, function(d) { return d.x; })).nice();
	  y.domain(d3.extent(data, function(d) { return d.y; })).nice();

	  svg.append("g")
		  .attr("class", "x axis")
		  .attr("transform", "translate(0," + height + ")")
		  .call(xAxis)
		.append("text")
		  .attr("class", "label")
		  .attr("x", (width-xTitle.length)/2-50)
		  .attr("y", 35)
		  .style("text-anchor", "start")
		  .text(xTitle)

	  svg.append("g")
		  .attr("class", "y axis")
		  .call(yAxis)
		.append("text")
		  .attr("class", "label")
		  .attr("transform", "rotate(-90)")
		  .attr("x", -(height+yTitle.length)/2-50)
		  .attr("y", -40)
		  .style("text-anchor", "start")
		  .text(yTitle)

	  svg.selectAll(".dot")
		  .data(data)
		.enter().append("circle")
		  //.attr("class", "dot")
		  .attr("r", 2)
		  .attr("cx", function(d) { return x(d.x); })
		  .attr("cy", function(d) { return y(d.y); })
		  .style("fill", function(d) { return color_beautification("red"); })
		  .style("opacity",0.6);

           if(slope!=undefined && yLine!=undefined){

                yLine = parseFloat(yLine.replace(",", "."));
                var xMaxValue = xMax
                var yMaxValue = yLine + slope * xMax
                if (yMaxValue > yMax){
                        xMaxValue = (yMax-yLine)/slope
                        yMaxValue = yMax
                }

                if (yMaxValue < yMin){
                        xMaxValue = (yMin-yLine)/slope
                        yMaxValue = yMin
                }

                var xMinValue = xMin
                var yMinValue = yLine + slope * xMin
                if (yMinValue > yMax){
                        xMinValue = (yMax-yLine)/slope
                        yMinValue = yMin
                }

                if (yMinValue < yMin){
                        xMinValue = (yMin-yLine)/slope
                        yMinValue = yMin
                }

                svg.append("line")
                  .attr("x1", x(xMinValue))
                  .attr("y1", y(yMinValue))
                  .attr("x2", x(xMaxValue))
                  .attr("y2", y(yMaxValue))
                  .attr("stroke-width", 2)
                  .attr("stroke", "black")
          }


	});
}

// line plot
// maximum 80 lines
function plot_lines(filename, target, title, footer, xTitle, yTitle, no_lines, yValues){

	var margin = {top: 50, right: 50, bottom: 75, left: 50},
		width = 600 - margin.left - margin.right,
		height = 500 - margin.top - margin.bottom;		
        var legend_width = 17   

	var x = d3.scale.linear()
		.range([0, width]);
	var y = d3.scale.linear()
		.range([height, 0]);

	var color = d3.scale.category10();

	var xAxis = d3.svg.axis()
		.scale(x)
		.orient("bottom")
		.ticks(5);

	var yAxis = d3.svg.axis()
		.scale(y)
		.orient("left")
		.ticks(5)

	var svg = d3.select("#".concat(target)).append("svg")
		.attr("width", width + margin.left + margin.right)
		.attr("height", height + margin.top + margin.bottom)
	  	.append("g")
		.attr("transform", "translate(" + margin.left + "," + margin.top + ")");
		
	svg.append("text")
		.attr("x", (width / 2))             
		.attr("y", -35)
		.attr("text-anchor", "middle")  
		.style("font-size", "16px") 
		.text(title);	

	d3.json(filename, function(error, data) {

	  var idx = -1

	  x.domain([0, d3.max(data, function(d) { return d.stop; })]);
	  y.domain(d3.extent(data, function(d) { return d.y; })).nice();

	  svg.append("g")
		  .attr("class", "x axis")
		  .attr("transform", "translate(0," + (height + height/no_lines) + ")")
		  .call(xAxis)
		.append("text")
		  .attr("class", "label")
		  .attr("x", (width-xTitle.length)/2-50)
		  .attr("y", 35)
		  .style("text-anchor", "start")
		  .text(xTitle)
		  
          if(yValues != ""){
		  svg.append("g")
			  .attr("class", "y axis")
			  .call(yAxis
		                .ticks(yValues.length)
				.tickFormat(function (d) {		               
		                   idx = idx + 1;
				   return yValues[idx];
	    			}))
			.append("text")
			  .attr("class", "label")
			  .attr("transform", "rotate(-90)")
			  .attr("x", -(height+yTitle.length)/2-50)
			  .attr("y", -40)
			  .style("text-anchor", "start")
			  .text(yTitle)
	  }
	  else{
		  svg.append("g")
			  .attr("class", "y axis")
			  .call(yAxis)
			.append("text")
			  .attr("class", "label")
			  .attr("transform", "rotate(-90)")
			  .attr("x", -(height+yTitle.length)/2)
			  .attr("y", -40)
			  .style("text-anchor", "start")
			  .text(yTitle)
	  }

	  svg.selectAll(".dot")
		  .data(data)
		.enter().append("line")
				  .attr("x1", function(d) { return x(d.start); })
				  .attr("y1", function(d) { return y(d.y); })				  
				  .attr("x2", function(d) { return x(d.stop); })
				  .attr("x2", function(d) { return x(d.stop); })
				  .attr("y2", function(d) { return y(d.y); })				  
				  .attr("stroke-width", function(d) { if(d.dotted == undefined) return height/no_lines; return height/no_lines/5;})
			          .style("stroke-dasharray", function(d) { if(d.dotted == undefined) return ("0, 0"); return ("2, 6");}) 
				  .attr("stroke", function(d) { return color_beautification(d.color); })
	});

	// add legend   
	var legend = svg.append("g")
	  .attr("class", "legend")
	  .attr("height", 100)
	  .attr("width", 100)
          .attr('transform', 'translate(-20,50)')    
      
    var h = 0

    for (var i = 0; i < footer.length; i++) {
        
	var array = footer[i].split(","); 
	legend
	      .append("rect")
		  .attr("x", width + margin.left)
	      .attr("y", 15*h)
		  .attr("width", 10)
		  .attr("height", 10)
		  .style("fill", color_beautification(array[1].replace(/\s+/g, '')))

	var chunkSize = legend_width
 	var length = array[0].length 
        
	for (var j = 0; j < length; j += chunkSize) {
           var substr = array[0].substring(j, Math.min(length, j + chunkSize));
	   legend
	      .append("text")
		  .attr("x", width + margin.left + 15)
	      .attr("y", 15*h + 9)
		  .text(substr);
            h += 1
    	}
    }

}

// line plot
// maximum 80 lines
function plot_align(filename, target, title, footer, xTitle, yTitle, no_lines, yValues){

	var margin = {top: 75, right: 50, bottom: 75, left: 150},
		width = 600 - margin.left - margin.right,
		height = 300 - margin.top - margin.bottom;		
        var legend_width = 17   

	var x = d3.scale.linear()
		.range([0, width]);
	var y = d3.scale.linear()
		.range([height, 0]);

	var color = d3.scale.category10();

	var xAxis = d3.svg.axis()
		.scale(x)
		.orient("bottom")
		.ticks(5);

	var yAxis = d3.svg.axis()
		.scale(y)
		.orient("left")
		.ticks(5)

	var svg = d3.select("#".concat(target)).append("svg")
		.style("vertical-align", "top") 
		.attr("width", width + margin.left + margin.right)
		.attr("height", height + margin.top + margin.bottom)
	  	.append("g")
		.attr("transform", "translate(" + margin.left + "," + margin.top + ")");
		
	svg.append("text")
		.attr("x", (width / 2))             
		.attr("y", -35)
		.attr("text-anchor", "middle")  
		.style("font-size", "16px") 
		.text(title);	

	d3.json(filename, function(error, data) {

	  var idx = -1

	  x.domain([0, d3.max(data, function(d) { return d.stop; })]);
	  y.domain(d3.extent(data, function(d) { return d.y; })).nice();

	  svg.append("g")
		  .attr("class", "x axis")
		  .attr("transform", "translate(0," + (height+height/no_lines) + ")")
		  .call(xAxis)
		.append("text")
		  .attr("class", "label")
		  .attr("x", (width-xTitle.length)/2-50)
		  .attr("y", 35)
		  .style("text-anchor", "start")
		  .text(xTitle)
		  
          if(yValues != ""){
		  svg.append("g")
			  .attr("class", "y axis")
			  .call(yAxis
		                .ticks(yValues.length)
				.tickFormat(function (d) {		               
		                   idx = idx + 1;
				   return yValues[idx];
	    			}))
			.append("text")
			  .attr("class", "label")
			  .attr("transform", "rotate(-90)")
			  .attr("x", -(height+yTitle.length)/2-50)
			  .attr("y", -40)
			  .style("text-anchor", "start")
			  .text(yTitle)
	  }
	  else{
		  svg.append("g")
			  .attr("class", "y axis")
			  .call(yAxis)
			.append("text")
			  .attr("class", "label")
			  .attr("transform", "rotate(-90)")
			  .attr("x", -(height+yTitle.length)/2-50)
			  .attr("y", -40)
			  .style("text-anchor", "start")
			  .text(yTitle)
	  }

	  svg.selectAll(".dot")
		  .data(data)
		.enter().append("line")
				  .attr("x1", function(d) { return x(d.start); })
				  .attr("y1", function(d) { return y(d.y); })				  
				  .attr("x2", function(d) { return x(d.stop); })
				  .attr("y2", function(d) { return y(d.y); })				  
				  .attr("stroke-width", function(d) { if(d.height == -1) return height/no_lines; return (height/no_lines * d.height) ; })
				  .attr("stroke", function(d) { return color_beautification(d.color); })
	});

    var offset = 0
    var total_len = 0
    for (var i = 0; i < footer.length; i++) {
	var array = footer[i].split(","); 
	total_len = total_len + array[0].length*8 + 15;
    }

    for (var i = 0; i < footer.length; i++) {

	var array = footer[i].split(","); 
	svg.append("rect")
	      .attr("x", (width-total_len)/2 + offset)             
	      .attr("y", -30)
	      .attr("width", 10)
	      .attr("height", 10)
	      .style("fill", color_beautification(array[1].replace(/\s+/g, '')))
        
	svg.append("text")
	      .attr("x", (width-total_len)/2 + offset + 15)             
	      .attr("y", -20)
	      .text(array[0]);
        offset = offset + array[0].length*8 + 15

    }

}


