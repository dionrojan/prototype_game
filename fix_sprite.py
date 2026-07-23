from PIL import Image

def fix_sprite():
    path = "/home/Dion/Documents/godot_games/testgame/testgame/sprites/13 - spetial dash.png"
    img = Image.open(path).convert("RGBA")
    new_img = Image.new("RGBA", img.size, (0, 0, 0, 0))
    
    shifts = [-1, -73, -76, -78, -80]
    
    for i in range(5):
        box = (i * 240, 0, (i + 1) * 240, 128)
        frame = img.crop(box)
        new_img.paste(frame, (i * 240 + shifts[i], 0))
        
    new_img.save(path)
    print("Sprite fixed based on head position!")

fix_sprite()
