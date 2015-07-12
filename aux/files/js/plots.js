function show_all_plots(button){
  'use strict';
  var plotBtns = $('.plot_btn');
  if (plotBtns.length > 30){
    $('#alert').modal();
  } else {
    if (window.chrome && (window.location.protocol === 'file:') ) {
      createChromeModal();
    } else {

      // show activity spinner
      $('#spinner1').modal({ backdrop: 'static', keyboard: 'false' });

      if (button.status !== 'pressed'){
        button.status = 'pressed';
        button.innerHTML = '<i class="fa fa-2x fa-bar-chart-o"></i><br>Hide All Charts';
        button.onclick = function() {
          hide_all_plots(button);
        };
      }

      remove_all_plots();       // remove all plots

      //iterate over the plot_btns and add data to each childRow
      $('.plot_btn').each (function(){
        addData(this, 'all');
      });

      $('#spinner1').modal('hide');      // remove activity spinner
    }
  }
}

function createChromeModal() {
  if (($('#browser-alert').length) === 0) {
    $('#browseralertText').html('<stong>Sorry, this feature is not supported in your browser.');
    $('#browseralert').modal();
  }
}

function remove_all_plots() {
  'use strict';
  $('.tablesorter-childRow').each (function(){
    $(this).remove();
  });

  $('.plot_btn').each (function(){
    this.status = 'released';
  });
}

function hide_all_plots(button){
  'use strict';
  button.status = 'released';
  button.innerHTML = '<i class="fa fa-2x fa-bar-chart-o"></i><br>Show All Charts';
  button.onclick = function() {
    show_all_plots(button);
  };
  remove_all_plots();
}

function addData(source, val){
  'use strict';
  if (window.chrome && (window.location.protocol === 'file:') ) {
    createChromeModal();
    return true;
  }
  var graphs      = '',
      graphData   = '',
      $currentRow = $(source).closest('tr'),
      target      = $currentRow.attr("data-target"),
      $childRow   = $('#mainrow' + target);
  
  if ($childRow.length && source.status !== 'pressed') {
    // if you click on another td...
    emptyChildRow($currentRow, target, source);
    addDataToChildRow($currentRow, target, val);
  } else if ($childRow.length === 0){
    createChildRow($currentRow, target, source);
    addDataToChildRow($currentRow, target, val);
  } else if ($childRow.length) {
    removeChildRow($currentRow, $childRow, source);
  }

  $('table').trigger('update');

}

function addOverallPlot(file){
  $.getJSON(file, function( json ) {
    addPlot(json.data, 'report_1', json.type, json.title, json.footer, json.xtitle, json.ytitle);
  });
}

function createChildRow($currentRow, target, source){
  var childRowHTML = '<tr class="tablesorter-childRow" id="mainrow' + target + '"><td colspan="12" id="row' +
                     target + '"><div id="' + target + '" class="expanded-child"></div></td></tr>';
  $currentRow.addClass('tablesorter-hasChildRow');
  $currentRow.after(childRowHTML);
  source.status = 'pressed';
}

function removeChildRow($currentRow, $childRow, source){
  $currentRow.removeClass('tablesorter-hasChildRow');
  $childRow.remove();
  source.status = 'released';
}

function emptyChildRow($currentRow, target, source){
  var targetId = '#' + target;
  var explanationId = '#' + target + 'explanation';
  $(targetId).empty();
  $(explanationId).remove();
  resetStatusOfOtherButtons($currentRow);
  source.status = 'pressed';
}

function resetStatusOfOtherButtons($currentRow){
  $currentRow.find('td').each (function(){
    if (this.status == 'pressed') { this.status = 'released'; }
  });
  $currentRow.find('.plot_btn').each (function(){
    if (this.status == 'pressed') { this.status = 'released'; }
  });
}

function addDataToChildRow($currentRow, target, val){
  var file = $currentRow.attr("data-jsonFile");

  $.getJSON(file, function( json ) {
    if (val === 'all'){
      for (var i in json.validations){
        if (json.validations[i].graphs !== undefined) {
          generatePlotCommands(json.validations[i].graphs, target);
        }
      }
    } else {
      addExplanation(target, json.validations[val]);
      if (json.validations[val].graphs !== undefined) {
        generatePlotCommands(json.validations[val].graphs, target);
      }
    }
  });
}

function generatePlotCommands(graphs, target) {
  for (var g = 0; g < graphs.length; g++) {
    var graphData = graphs[g];
    addPlot(graphData.data, target, graphData.type, graphData.title,
            graphData.footer, graphData.xtitle, graphData.ytitle,
            graphData.aux1, graphData.aux2);
  }
}

function addExplanation(target, jsonData){
  'use strict';
  var row = '#row' + target;
  var approach_html = '<p><b>Approach:</b> ' + jsonData.approach + '</p>';
  var explanation_html = '<p><b>Explanation:</b> ' + jsonData.explanation + '</p>';
  var conclusion_html = '<p><b>Conclusion:</b> ' + jsonData.conclusion + '</p>';

  var explain = $('<div id="' + target + 'explanation" class="alert alert-info explanation_alert" role="alert">' +
                approach_html + explanation_html + conclusion_html + '</div>');
  $(row).prepend(explain);
}

function addPlot(jsonData, target, type, title, footer, xtitle, ytitle, aux1, aux2){
  'use strict';
  var legend;
  if (footer === '') {
    legend = [];
  } else {
    legend = footer.split(';');
  }

  switch(type) {
    case 'scatter':
      plot_scatter(jsonData, target, title, footer, xtitle, ytitle, aux1, aux2);
      break;
    case 'bars':
      plot_bars(jsonData, target, title, legend, xtitle, ytitle, aux1);
      break;
    case 'simplebars':
      plot_simple_bars(jsonData, target, title, legend, xtitle, ytitle);
      break;
    case 'lines':
      if (aux2 !== null) {
        aux2 = aux2.split(',');
      }
      plot_lines(jsonData, target, title, legend, xtitle, ytitle, aux1, aux2);
      break;
    case 'align':
      if (aux2 !== null) {
        aux2 = aux2.split(',');
      }
      plot_align(jsonData, target, title, legend, xtitle, ytitle, aux1, aux2);
      break;
    default:
      break;
  }
}

function color_beautification(color){
  'use strict';
  switch(color){
    case 'red':
      return d3.rgb(189,54,47);
    case 'blue':
      return d3.rgb(58,135,173);
    case 'green':
      return d3.rgb(70,136,71);
    case 'yellow':
      return d3.rgb(255,255,51);
    case 'orange':
      return d3.rgb(248,148,6);
    case 'violet':
      return d3.rgb(153,0,153);
    case 'gray':
      return d3.rgb(160,160,160);
    default:
      return color;
  }
}

// bars plot
function plot_bars(alldata, target, title, footer, xTitle, yTitle, bar){
  var margin = {top: 70, right: 50, bottom: 75, left: 50},
    width = 600 - margin.left - margin.right,
    height = 500 - margin.top - margin.bottom;
  var legend_width = 15;

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
  var no_colors = colors.length;

  var padding = 100;

  flattened_data = [].concat.apply([], alldata);
  var yMax = d3.max(flattened_data, function(d) { return d.value; }) + 3;
  var y = d3.scale.linear()
    .domain([0, yMax + yMax/10])
    .range([height, 0]);

  var xMin = d3.min(flattened_data, function(d) { return d.key; });
  if (bar!=undefined){
    var xMin = Math.min(xMin, bar);
  }

  var xMax = d3.max(flattened_data, function(d) { return d.key; });
  if (bar!=undefined){
    var xMax = Math.max(xMax, bar);
  }

  var x = d3.scale.linear()
    .domain([xMin-padding, xMax+padding])
    .range([13, width]);

  var xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom")
    .ticks(8);

  var yAxis = d3.svg.axis()
    .scale(y)
    .orient("left")
    .tickFormat(d3.format("d"))
    .ticks(8);

  svg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + height + ")")
      .call(xAxis)
    .append("text")
      .attr("class", "label")
      .attr("x", (width-xTitle.length)/2-50)
      .attr("y", 35)
      .style("text-anchor", "start")
      .text(xTitle);

   svg.append("g")
       .attr("class", "y axis")
      .call(yAxis)
    .append("text")
      .attr("class", "label")
      .attr("transform", "rotate(-90)")
      .attr("x", -(height+yTitle.length)/2-50)
      .attr("y", -40)
      .style("text-anchor", "start")
      .text(yTitle);

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

    if (bar!=undefined){
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

  var offset = 0;
  var total_len = 0;
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
      .style("fill", color_beautification(array[1].replace(/\s+/g, '')));

  svg.append("text")
      .attr("x", (width-total_len)/2 + offset + 15)
      .attr("y", -20)
      .text(array[0]);
    offset = offset + array[0].length*8 + 15;
  }
}

// bars plot
function plot_simple_bars(alldata, target, title, footer, xTitle, yTitle){
  'use strict';

  var margin = {top: 70, right: 50, bottom: 75, left: 50},
    width = 600 - margin.left - margin.right,
    height = 500 - margin.top - margin.bottom;
  var legend_width = 15;

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
  var no_colors = colors.length;

  var padding = 0;

  var flattened_data = [].concat.apply([], alldata);
  var yMax = d3.max(flattened_data, function(d) { return d.value; }) + 3;
  var y = d3.scale.linear()
         .domain([0, yMax])
         .range([height, 0]);

  var xMin = d3.min(flattened_data, function(d) { return d.key; });
  var xMax = d3.max(flattened_data, function(d) { return d.key; });

  var x = d3.scale.linear()
            .domain([xMin-padding, xMax+padding])
            .range([13, width]);

  var xAxis = d3.svg.axis()
                .scale(x)
                .orient("bottom")
                .ticks(8);

  var yAxis = d3.svg.axis()
                .scale(y)
                .orient("left")
                .tickFormat(d3.format("d"))
                .ticks(8);

  svg.append("g")
       .attr("class", "x axis")
       .attr("transform", "translate(0," + height + ")")
       .call(xAxis)
     .append("text")
       .attr("class", "label")
       .attr("x", (width-xTitle.length)/2-50)
       .attr("y", 35)
       .style("text-anchor", "start")
       .text(xTitle);

  svg.append("g")
       .attr("class", "y axis")
       .call(yAxis)
     .append("text")
       .attr("class", "label")
       .attr("transform", "rotate(-90)")
       .attr("x", -(height+yTitle.length)/2-50)
       .attr("y", -40)
       .style("text-anchor", "start")
       .text(yTitle);

  alldata.map( function(data, i) {

  var color = colors[i % (no_colors - 1)];

  svg.selectAll(".bar")
     .data(data)
     .enter().append("rect")
             .attr("x", function(d) { return x(d.key); })
             .attr("width", 6)
             .attr("y", function(d) { return y(d.value); })
             .attr("height", function(d) { return height - y(d.value); })
             .attr("fill", function(d) { if (d.main == true) return color_beautification("red"); return color_beautification("blue");});
    });
}


// scatter plot
// ecuation of the line: slope * x + yLine
function plot_scatter(data, target, title, footer, xTitle, yTitle, yLine, slope){
  'use strict';

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

  var xMax = d3.max(data, function(d) { return d.x; });
  var xMin = d3.min(data, function(d) { return d.x; });
  var yMax = d3.max(data, function(d) { return d.y; });
  var yMin = d3.min(data, function(d) { return d.y; });
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
       .text(xTitle);

  svg.append("g")
       .attr("class", "y axis")
       .call(yAxis)
     .append("text")
       .attr("class", "label")
       .attr("transform", "rotate(-90)")
       .attr("x", -(height+yTitle.length)/2-50)
       .attr("y", -40)
       .style("text-anchor", "start")
       .text(yTitle);

  svg.selectAll(".dot")
       .data(data)
     .enter().append("circle")
       .attr("r", 2)
       .attr("cx", function(d) { return x(d.x); })
       .attr("cy", function(d) { return y(d.y); })
       .style("fill", function(d) { return color_beautification("red"); })
       .style("opacity",0.6);

  if ((slope!=undefined && slope != "") && (yLine!=undefined && yLine != "")){
    yLine = parseFloat(yLine.replace(",", "."));
    var xMaxValue = xMax;
    var yMaxValue = yLine + slope * xMax;
    if (yMaxValue > yMax){
      xMaxValue = (yMax-yLine)/slope;
      yMaxValue = yMax;
    }

    if (yMaxValue < yMin){
      xMaxValue = (yMin-yLine)/slope;
      yMaxValue = yMin;
    }

    var xMinValue = xMin;
    var yMinValue = yLine + slope * xMin;
    if (yMinValue > yMax){
      xMinValue = (yMax-yLine)/slope;
      yMinValue = yMin;
    }

    if (yMinValue < yMin){
      xMinValue = (yMin-yLine)/slope;
      yMinValue = yMin;
    }

    svg.append("line")
         .attr("x1", x(xMinValue))
         .attr("y1", y(yMinValue))
         .attr("x2", x(xMaxValue))
         .attr("y2", y(yMaxValue))
         .attr("stroke-width", 2)
         .attr("stroke", "black");
  }
}

// line plot
// maximum 80 lines
function plot_lines(data, target, title, footer, xTitle, yTitle, no_lines, yValues){
  'use strict';
  var margin = {top: 70, right: 50, bottom: 75, left: 50},
  width = 600 - margin.left - margin.right,
  height = 500 - margin.top - margin.bottom;
  var legend_width = 17;

  var x = d3.scale.linear()
            .range([0, width]);
  var y = d3.scale.linear()
            .range([height, 0]);

  var color = d3.scale.category10();

  if (title === 'Open Reading Frames in all 6 Frames') {
    var xAxis = d3.svg.axis()
                  .scale(x)
                  .orient("bottom")
                  .ticks(0);
  } else {
    var xAxis = d3.svg.axis()
                  .scale(x)
                  .orient("bottom")
                  .ticks(5);
  }

  var yAxis = d3.svg.axis()
                .scale(y)
                .orient("left")
                .ticks(5);

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

  var idx = -1;

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
       .text(xTitle);

  if (yValues !== null){
    svg.append("g")
         .attr("class", "y axis")
         .call(yAxis.ticks(yValues.length)
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
         .text(yTitle);
    } else {
      svg.append("g")
           .attr("class", "y axis")
           .call(yAxis)
         .append("text")
           .attr("class", "label")
           .attr("transform", "rotate(-90)")
           .attr("x", -(height+yTitle.length)/2)
           .attr("y", -40)
           .style("text-anchor", "start")
           .text(yTitle);
    }

    svg.selectAll(".dot")
       .data(data)
    .enter().append("line")
            .attr("x1", function(d) { return x(d.start); })
            .attr("y1", function(d) { return y(d.y); })
            .attr("x2", function(d) { return x(d.stop); })
            .attr("x2", function(d) { return x(d.stop); })
            .attr("y2", function(d) { return y(d.y); })
            .attr("stroke-width", function(d) {
              if (d.dotted == undefined) {
                if (d.color == "red" ) {
                  return height/no_lines/2.5;
                } else {
                  return height/no_lines;
                }
              } else {
                return height/no_lines/5;
              }
            })
            .style("stroke-dasharray", function(d) { if (d.dotted == undefined) return ("0, 0"); return ("2, 6");})
            .attr("stroke", function(d) { return color_beautification(d.color); });

  // add legend
  var legend = svg.append("g")
                  .attr("class", "legend")
                  .attr("height", 100)
                  .attr("width", 100)
                  .attr('transform', 'translate(-20,50)');

  var h = 0;

  var offset = 40;
  var total_len = 0;
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
         .style("fill", color_beautification(array[1].replace(/\s+/g, '')));

    svg.append("text")
         .attr("x", (width-total_len)/2 + offset + 15)
         .attr("y", -20)
         .text(array[0]);  
    offset = offset + array[0].length*8 + 15;
  }
}

// line plot
// maximum 80 lines
function plot_align(data, target, title, footer, xTitle, yTitle, no_lines, yValues){
  'use strict';

  var margin = {top: 75, right: 50, bottom: 75, left: 150},
  width = 600 - margin.left - margin.right,
  height = 300 - margin.top - margin.bottom;
  var legend_width = 17;

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
                    .ticks(5);

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

  var idx = -1;

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
       .text(xTitle);

  if (yValues !== null){
    svg.append("g")
         .attr("class", "y axis")
         .call(yAxis.ticks(yValues.length)
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
         .text(yTitle);
  } else {
    svg.append("g")
         .attr("class", "y axis")
         .call(yAxis)
       .append("text")
         .attr("class", "label")
         .attr("transform", "rotate(-90)")
         .attr("x", -(height+yTitle.length)/2-50)
         .attr("y", -40)
         .style("text-anchor", "start")
         .text(yTitle);
  }

  svg.selectAll(".dot")
     .data(data)
     .enter().append("line")
               .attr("x1", function(d) { return x(d.start); })
               .attr("y1", function(d) { return y(d.y); })
               .attr("x2", function(d) { return x(d.stop); })
               .attr("y2", function(d) { return y(d.y); })
               .attr("stroke-width", function(d) { if (d.height == -1) return height/no_lines; return (height/no_lines * d.height) ; })
               .attr("stroke", function(d) { return color_beautification(d.color); });

  var offset = 0;
  var total_len = 0;
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
         .style("fill", color_beautification(array[1].replace(/\s+/g, '')));

    svg.append("text")
         .attr("x", (width-total_len)/2 + offset + 15)
         .attr("y", -20)
         .text(array[0]);
    offset = offset + array[0].length*8 + 15;
  }
}
