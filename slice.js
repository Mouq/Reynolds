$(document).ready(function(){
    var spheres = undefined;
    var dev          = 0;
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
        })
        .drawArc({
            strokeStyle: "#000",
            strokeWidth: 1,
            x: cx, y: cy,
            radius: Math.sqrt(Math.pow(radius,2) - Math.pow(z,2))/radius*h/2
        });
        if (dev) {
            for(var i=0; i<s; i++){
                if((Math.pow(grain_radius,2) - Math.pow(spheres[i][2]-z,2))>0){
                    $('canvas')
                    .drawArc({
                        strokeStyle: "#ccc",
                        strokeWidth: 1,
                        x: cx+spheres[i][0]/radius*h/2,
                        y: cy+spheres[i][1]/radius*h/2,
                        radius: 2*Math.sqrt(Math.pow(grain_radius,2) - Math.pow(spheres[i][2]-z,2))/radius*h/2
                    })
                }
            }
        }
        for(var i=0; i<s; i++){
            if((Math.pow(grain_radius,2) - Math.pow(spheres[i][2]-z,2))>0){
                $('canvas')
                .drawArc({
                    strokeStyle: "#000",
                    strokeWidth: 1,
                    fillStyle: "#"+Math.floor(16*(1-spheres[i][3]/30)).toString(16)+"00",
                    x: cx+spheres[i][0]/radius*h/2,
                    y: cy+spheres[i][1]/radius*h/2,
                    radius: Math.sqrt(Math.pow(grain_radius,2) - Math.pow(spheres[i][2]-z,2))/radius*h/2
                });
                if (dev) {
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
        url:    "6000.json",
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
    $(window).resize(function(){setHeight();drawSlice(0);});
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
    $('#controls input.dev').change(function(){
        dev = $(this).prop('checked');
        drawSlice( ($('#controls input.z').val()-50)/50, $('#controls input.s').val());
    })
})
