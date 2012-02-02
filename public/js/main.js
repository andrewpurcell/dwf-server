$(document).ready(function() {
    $("#time").focus(function(e) {
        if ($(this).val() === "in minutes") {
            $(this).val("");
            $(this).css('color', '#000');
        }
    });
    $("#time").blur(function(e) {
        if ($(this).val() === "") {
            $(this).val("in minutes");
            $(this).css('color', '#888');
        }
    });

});