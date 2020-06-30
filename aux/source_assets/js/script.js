$(document).ready(function() {
  if (window.location.protocol === 'file:') {
    $('#browseralert').modal();
  }
  GV.toggleOverviewBtn(); // write overview to overview section
  initTableSorter();
  $("[data-toggle='tooltip']").tooltip(); //ToolTip
});

$(document).on( "click", "td, .plot_btn", function( event ) {
    if ($(this).hasClass('success') || $(this).hasClass('danger')){
      var title = $(this).attr('title');
      var val = title.replace(/[ \/]/g, '');
      GV.addData(this, val);
    } else if ($(this).hasClass('plot_btn')){
      GV.addData(this, 'all');
    }
});

function initTableSorter() {
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
}
