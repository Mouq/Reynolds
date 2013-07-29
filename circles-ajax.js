var spheres = [[]];
$.ajax({'url': "http://localhost:5334/",'success': function(j){
    $(document).ready(function(){
        console.log("Successful ajax!");
        spheres = j;
        var dev          = 0;
        var radius       = 30;
        var grain_radius = 1;
        var setHeight = function(){
            $('#viewport').height(.98*$(window).height()-$('#controls').height());
            //$('#controls').height();
        }
        var drawSlice = function(s){
            if(!spheres[0][0]){console.log("Fail! "+spheres)}
            else{
                var h = $('#viewport').height() < $('#viewport').width() ? $('#viewport').height() : $('#viewport').width();
                var w = h;
                var cx = $('#viewport').width()/2,
                    cy = $('#viewport').height()/2;
                var r = h*grain_radius/radius;
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
                    radius: h/2
                });
                if (dev) {
                    for(var i=0; i<s; i++){
                        $('canvas')
                        .drawArc({
                            strokeStyle: "#ccc",
                            strokeWidth: 1,
                            x: cx+spheres[i][0]/radius*h/2,
                            y: cy+spheres[i][1]/radius*h/2,
                            radius: 2*grain_radius/radius*h/2,
                        }).drawText({
                            strokeStyle: "#000",
                            x: cx+spheres[i][0]/radius*h/2,
                            y: cy+spheres[i][1]/radius*h/2,
                            fromCenter: true,
                            text: i,
                            fontSize: grain_radius/radius*h/2.1,
                            fontFamily: "monospace"
                        })
                    }
                }
                for(var i=0; i<s; i++){
                    $('canvas')
                    .drawArc({
                        strokeStyle: "#000",
                        strokeWidth: 1,
                        x: cx+spheres[i][0]/radius*h/2,
                        y: cy+spheres[i][1]/radius*h/2,
                        radius: grain_radius/radius*h/2,
                    })
                }
            }
        }
        $('#controls input.s').attr('max', spheres.length).val(spheres.length);
        setHeight();
        drawSlice( $('#controls input.s').val());
        $('#viewport').mousemove(function(e){
            m = $('#viewport').height() < $('#viewport').width() ? $('#viewport').height() : $('#viewport').width();
            $('#pos').html(
                '{'+(e.pageX-$('#viewport').width()/2)/m*2*radius+', '+(e.pageY-$('#viewport').height()/2)/m*2*radius+'}'
            )
        })
        $(window).resize(function(){setHeight();drawSlice( $('#controls input.s').val() );});
        $('#controls div.s').html( $("#controls input.s").val() );
        $('#controls input.s').change(function(){
            $('#controls div.s').html($(this).val());
            drawSlice( $(this).val() )
        });
        $('#controls input.dev').change(function(){
            dev = $(this).prop('checked');
            drawSlice( $('#controls input.s').val() );
        })
    })
}}).done(function(){console.log("I'm done")}).fail(function(){console.log("GASP! Failure!")});
