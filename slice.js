$(document).ready(function(){
    var spheres      = undefined;
    var json_url     = "6000.json";
    var options      = {
        '2x':       0,
        'lines':    1,
        'numbered': 0,
        'circles':  1,
    };
    var radius       = 50;
    var grain_radius = 1;
    var setHeight = function(){
        $('#viewport').height(.98*$(window).height()-$('#controls').height());
        //$('#controls').height();
    }
    var drawSlice = function(z,s){
        if(typeof spheres === 'undefined'){ return };
        var h = $('#viewport').height() < $('#viewport').width() ? $('#viewport').height() : $('#viewport').width();
        var w = h;
        var cx = $('#viewport').width()/2,
            cy = $('#viewport').height()/2;
        var r = h*grain_radius/radius;
        z *= radius;
        $('canvas')
        .clearCanvas({
            x:cx, y:cy,
            height: $('#viewport').height(),
            width: $('#viewport').width()
        }).drawArc({
            strokeStyle: "#000",
            strokeWidth: 1,
            x: cx, y: cy,
            radius: Math.sqrt(Math.pow(radius,2) - Math.pow(z,2))/radius*h/2
        });
        if (options['2x']) {
            for(var i=0; i<s; i++){
                if((Math.pow(2*grain_radius,2) - Math.pow(spheres[i][2]-z,2))>0){
                    $('canvas')
                    .drawArc({
                        strokeStyle: "#ccc",
                        strokeWidth: 1,
                        x: cx+spheres[i][0]/radius*h/2,
                        y: cy+spheres[i][1]/radius*h/2,
                        radius: Math.sqrt(Math.pow(2*grain_radius,2) - Math.pow(spheres[i][2]-z,2))/radius*h/2
                    })
                }
            }
        }
        for(var i=0; i<s; i++){
            if((Math.pow(grain_radius,2) - Math.pow(spheres[i][2]-z,2))>0){
                if (options['circles']) {
                    $('canvas')
                    .drawArc({
                        strokeStyle: "#000",
                        strokeWidth: 1,
                        fillStyle: "#"+Math.floor(16*(1-(spheres[i].length-3)/30)).toString(16)+"00",
                        x: cx+spheres[i][0]/radius*h/2,
                        y: cy+spheres[i][1]/radius*h/2,
                        radius: Math.sqrt(Math.pow(grain_radius,2) - Math.pow(spheres[i][2]-z,2))/radius*h/2
                    });
                }
                if (options['lines']){
                    for (var j=3; j<spheres[i].length; j++){
                        $('canvas').drawLine({
                            opacity: 0.4,
                            rounded: true,
                            strokeStyle: '#000',
                            x1: cx+spheres[i][0]/radius*h/2,
                            y1: cy+spheres[i][1]/radius*h/2,
                            x2: cx+spheres[spheres[i][j]][0]/radius*h/2,
                            y2: cy+spheres[spheres[i][j]][1]/radius*h/2,
                            strokeWidth: Math.sqrt(Math.pow(grain_radius,2) - Math.pow(spheres[i][2]-z,2))/radius*h/6,
                        })
                    }
                }
                if (options['numbered']) {
                    $('canvas').drawText({
                        strokeStyle: "#000",
                        x: cx+spheres[i][0]/radius*h/2,
                        y: cy+spheres[i][1]/radius*h/2,
                        fromCenter: true,
                        text: i,
                        fontSize: Math.sqrt(Math.pow(grain_radius,2) - Math.pow(spheres[i][2]-z,2))/radius*h/2,
                        fontFamily: "monospace"
                    })
                }
            }
        }
    }
    $.ajax({
        url:        json_url,
        dataType:   'json',
        success: function(j){
            spheres = j;
            console.log("JSON loaded");
            drawSlice( ($('#controls input.z').val()-50)/50, $('#controls input.s').val());
        },
        error: function(_,e){
            console.log("JSON not loaded. Error: "+e)
        },
        async:  false,
        
    });
    if(!(typeof spheres === 'undefined')){$('#controls input.s').attr('max', spheres.length).val(spheres.length)};
    setHeight();
    drawSlice( ($('#controls input.z').val()-50)/50, $('#controls input.s').val());
    $('#viewport').mousemove(function(e){
        m = $('#viewport').height() < $('#viewport').width() ? $('#viewport').height() : $('#viewport').width();
        $('#pos').html(
            '{'+(e.pageX-$('#viewport').width()/2)/m*2*radius+', '+(e.pageY-$('#viewport').height()/2)/m*2*radius+', '+($('#controls input.z').val()-50)/50*radius+'}'
        )
    })
    $(window).resize(function(){setHeight();drawSlice( ($('#controls input.z').val()-50)/50, $('#controls input.s').val());});
    $('#controls div.z').html(($("#controls input.z").val()-50)/50+"R");
    $('#controls div.s').html($("#controls input.s").val());
    $('#controls input.z').change(function(){ // 'Instantaneous' if switch to jQuery UI
        $('#controls div.z').html(($(this).val()-50)/50+"R");
        drawSlice( ($(this).val()-50)/50, $('#controls input.s').val() )
    });
    $('#controls input.s').change(function(){
        $('#controls div.s').html($(this).val());
        drawSlice( ($('#controls input.z').val()-50)/50, $(this).val() )
    });
    $('#options input').change(function(){
        options[$(this).attr('class')] = $(this).prop('checked');
        drawSlice( ($('#controls input.z').val()-50)/50, $('#controls input.s').val());
    })
})
