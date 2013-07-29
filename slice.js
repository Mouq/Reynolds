$(document).ready(function(){
    var spheres = [ // ajax later
[1.70130161670408138104, 0.00000000000000000000, 0],
[0.52573111211913617069, 1.61803398874989560963, 0],
[-1.37638192047117217446, 1.00000000000000445738, 0],
[-1.37638192047117865138, -0.99999999999999554264, 0],
[0.52573111211912569079, -1.61803398874989901475, 0],
[0.91758794698078016325, -0.00000000000000113504, 1.84005241335371649139],
[0.91758794698078016325, -0.00000000000000113504, -1.84005241335371649139],
[-0.36264441684472749494, 2.05745319101594570552, 1.73715275212574313890],
[-0.36264441684472749494, 2.05745319101594570552, -1.73715275212574313890],
    ];
    var radius       = 5;
    var grain_radius = 2;
    var setHeight = function(){
        $('#viewport').height(.98*$(window).height()-$('#controls').height());
        //$('#controls').height();
    }
    var drawSlice = function(z,s){
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
        for(var i=0; i<s; i++){
            if((Math.pow(grain_radius,2) - Math.pow(spheres[i][2]-z,2))>0){
                $('canvas')
                .drawArc({
                    strokeStyle: "#000",
                    strokeWidth: 1,
                    x: cx+spheres[i][0]/radius*h/2,
                    y: cy+spheres[i][1]/radius*h/2,
                    radius: Math.sqrt(Math.pow(grain_radius,2) - Math.pow(spheres[i][2]-z,2))/radius*h/2
                });
            }
        }
    }
    $('#controls input.s').attr('max', spheres.length).val(spheres.length);
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
})
