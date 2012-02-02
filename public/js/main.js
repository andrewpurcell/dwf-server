$(document).ready(function() {
    $("#username").focus(function(e) {
        if ($(this).val() === "Your name") {
            $(this).val("");
            $(this).css('color', '#000');
        }
    });
    $("#username").blur(function(e) {
        if ($(this).val() === "") {
            $(this).val("Your name");
            $(this).css('color', '#888');
        }
    });
    
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