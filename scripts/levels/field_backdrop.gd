extends Node2D
var elapsed := 0.0
func _process(delta: float) -> void:
    elapsed += delta
    queue_redraw()
func _draw() -> void:
    draw_rect(Rect2(-1000,-500,4200,1200),Color("#e4b78b"))
    draw_rect(Rect2(-1000,-500,4200,650),Color("#8196a9"))
    draw_circle(Vector2(1100,160),85,Color("#f8d9a0"))
    for i in range(4):
        var poly := PackedVector2Array([Vector2(-1000,600)])
        for x in range(-1000,3201,80):
            poly.append(Vector2(x,315.0+float(i)*43.0+sin(float(x)*0.003+float(i))*35.0))
        poly.append(Vector2(3200,700))
        draw_colored_polygon(poly,[Color("#a4a397"),Color("#889781"),Color("#788c70"),Color("#677d5c")][i])
    for i in range(12):
        var x := 180.0+float(i)*140.0
        var y := 392.0+sin(float(i)*1.7)*17.0
        draw_rect(Rect2(x,y,80,64),Color("#c8b39b"))
        draw_colored_polygon(PackedVector2Array([Vector2(x-8,y),Vector2(x+40,y-36),Vector2(x+88,y)]),Color("#71584f"))
        draw_rect(Rect2(x+18,y+24,13,22),Color("#5c544b"))
    var hub := Vector2(780,300)
    draw_colored_polygon(PackedVector2Array([Vector2(730,428),Vector2(751,260),Vector2(809,260),Vector2(830,428)]),Color("#d0b99c"))
    draw_colored_polygon(PackedVector2Array([Vector2(741,263),Vector2(780,225),Vector2(819,263)]),Color("#64534d"))
    for i in range(4):
        var angle := float(i)*PI*0.5+elapsed*0.12
        var dir := Vector2(cos(angle),sin(angle))
        var side := Vector2(-dir.y,dir.x)*17.0
        draw_colored_polygon(PackedVector2Array([hub+dir*20.0,hub+dir*90.0,hub+dir*90.0+side,hub+dir*20.0+side]),Color("#e7cc9f"))
        draw_line(hub,hub+dir*94.0,Color("#5b493d"),5)
    draw_circle(hub,9,Color("#4a3b34"))
    draw_rect(Rect2(-1000,448,4200,145),Color("#ad8c4b"))
    for i in range(440):
        var x := -950.0+float(i)*9.3
        var y := 540.0+float(i%4)*12.0
        var sway := sin(elapsed*1.2+float(i)*0.42)*3.0
        var tip := Vector2(x+sway,y-30.0-float(i%5)*3.0)
        draw_line(Vector2(x,y),tip,Color("#d7ad60"),2)
        draw_line(tip,tip+Vector2(-3,8),Color("#f1ce79"),4)
    draw_rect(Rect2(-1000,592,4200,128),Color("#58483b"))
    draw_rect(Rect2(-1000,583,4200,14),Color("#788854"))
    for i in range(18):
        var x := -250.0+float(i)*175.0
        draw_rect(Rect2(x,531,12,58),Color("#73563b"))
        draw_line(Vector2(x,550),Vector2(x+175,550),Color("#806347"),6)
        draw_line(Vector2(x,571),Vector2(x+175,571),Color("#806347"),5)
