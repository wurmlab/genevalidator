//sort table
$(function() {
  $("#sortable_table").tablesorter();
});

//ToolTip
$(function () { 
  $("[data-toggle='tooltip']").tooltip();
});

//Hide empty columns
$(document).ready(function() { 
  $('#sortable_table tr th').each(function(i) {
    //select all tds in this column
    var tds = $(this).parents('table')
    .find('tr td:nth-child(' + (i + 1) + ')');
    //check if all the cells in this column are empty
    if(tds.length == tds.filter(':empty').length) { 
      //hide header
      $(this).hide();
      //hide cells
      tds.hide();
    }
  });
});