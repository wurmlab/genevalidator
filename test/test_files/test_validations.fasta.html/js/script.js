//sort table

$(document).ready(function() { 
    $("#sortable_table").tablesorter( {cssHeader: "header", sortList: [[0,0]]} ); 
}); 

//popover
$(function (){
	$( ".my_popover" ).popover();
});

//hide empty columns
$(document).ready(function() { $('#sortable_table tr th').each(function(i) {
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

//fill stars
$(document).ready(function() {
      $.fn.raty.defaults.path = 'css/img';
      var cells = document.getElementsByName('ranking');
      for (var i = 0; i < cells.length; i++) {
      	var sc = cells[i].getAttribute("score")*5/100
        $(cells[i]).raty({ readOnly: true, score: sc, title:sc.toString().concat("%") });
      }
});

