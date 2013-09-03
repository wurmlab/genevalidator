
$(document).ready(function() { 
    $("#sortable_table").tablesorter( {sortList: [[0,0]]} ); 
}); 

$(function (){
	$( ".my_popover" ).popover();
});

$(document).ready(function() { $('#sortable_table tr th').each(function(i) {
        //select all tds in this column
        var tds = $(this).parents('table')
            .find('tr td:nth-child(' + (i + 1) + ')');
        if(tds.is(':empty')) {
            //hide header
            $(this).hide();
            //hide cells
            tds.hide();
        } 
    }); 
});


