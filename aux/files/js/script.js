//sort table
$(function(){
  'use strict';

  // add custom parser to make the stars column to sort according to attr.
  $.tablesorter.addParser({
    id: 'star_scores', // called later when init the tablesorter
    is: function() {
      return false; // return false so this parser is not auto detected
    },
    format: function(s, table, cell, cellIndex) {
      var $cell = $(cell);
      if (cellIndex === 1) {
        return $cell.attr('data-score') || s;
      }
      return s;
    },
    parsed: false,
    type: 'numeric' // Setting type of data...
  });

  $('table').tablesorter({
    headers: {
      1 : { sorter: 'star_scores' } // Telling it to use custom parser...
    },
    sortList: [[0,0]],
  });
});


//ToolTip
$(function () {
  'use strict';
  $("[data-toggle='tooltip']").tooltip();
});

//Hide empty columns
$(document).ready(function() {
  'use strict';
  if (window.chrome && (window.location.protocol === 'file:') )  {
    $('#browseralert').modal();
  }

  $('#sortable_table tr th').each(function(i) {
    //select all tds in this column
    var tds = $(this).parents('table')
    .find('tr td:nth-child(' + (i + 1) + ')');
    //check if all the cells in this column are empty
    //
    if ($(this).hasClass('chart-column')) {
    } else {
      if ($(this).text().trim() === '') {
        //hide header
        $(this).hide();
        //hide cells
        tds.hide();
      }
    }
  });
});

$( document ).on( "click", "td, .plot_btn", function( event ) {
    if ($(this).hasClass('success') || $(this).hasClass('danger')){
      var title = $(this).attr('title');
      var val = title.replace(/[ \/]/g, '');
      addData(this, val);
    } else if ($(this).hasClass('plot_btn')){
      addData(this, 'all');
    }
});

$(function () {
  $(document).ready(function() {
    toggle_overview_btn();
  });
});
