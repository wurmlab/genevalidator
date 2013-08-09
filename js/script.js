function showDiv(toggle){
   var button = document.getElementById(toggle)
   if(button.style.display == "block"){
     button.style.display = "none";
   }
   else{
      button.style.display = "block";
   }
}

$(document).ready(function() { 
    $("#myTable").tablesorter( {sortList: [[2,0]]} ); 
}); 
