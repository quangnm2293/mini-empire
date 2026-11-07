from PIL import Image, ImageDraw, ImageFont
import math, os, random
ROOT=os.path.expanduser('~/workspace/mini-empire')
A=os.path.join(ROOT,'assets'); S=os.path.join(ROOT,'sounds')
os.makedirs(A,exist_ok=True); os.makedirs(S,exist_ok=True)
try: font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',28)
except: font=ImageFont.load_default()
BLUE=(38,92,190,255); RED=(190,45,38,255); DARK=(35,35,40,255); SKIN=(238,190,145,255); GOLD=(245,185,35,255)

def canvas(w,h): return Image.new('RGBA',(w,h),(0,0,0,0))
def person(kind,team):
    im=canvas(96,96); d=ImageDraw.Draw(im); main=BLUE if team==0 else RED
    # legs/boots
    d.line([(40,68),(35,86)],fill=(70,48,30,255),width=6); d.line([(56,68),(62,86)],fill=(70,48,30,255),width=6)
    # body tunic/armor
    if kind=='swordsman': body=(105,118,135,255)
    else: body=main
    d.polygon([(48,27),(29,70),(67,70)],fill=body,outline=DARK)
    d.line([(33,43),(18,59)],fill=SKIN,width=6); d.line([(63,43),(78,59)],fill=SKIN,width=6)
    # head
    d.ellipse([36,5,60,31],fill=SKIN,outline=DARK,width=2)
    if kind=='villager':
        d.pieslice([33,0,63,25],180,360,fill=(245,190,45,255),outline=DARK)
        d.line([(76,48),(88,76)],fill=(120,75,35,255),width=5); d.line([(82,43),(91,51)],fill=(150,150,150,255),width=4)
    elif kind=='swordsman':
        d.pieslice([33,0,63,30],180,360,fill=(155,163,175,255),outline=DARK)
        d.polygon([(73,28),(88,8),(82,38),(70,48)],fill=(210,220,230,255),outline=DARK)
        d.rounded_rectangle([5,43,25,70],4,fill=main,outline=(230,200,80,255),width=2)
    else:
        d.pieslice([32,-2,64,28],180,360,fill=(45,120,65,255) if team==0 else (110,35,35,255),outline=DARK)
        d.arc([58,28,91,76],-80,100,fill=(120,75,35,255),width=5); d.line([(75,30),(75,75)],fill=(240,240,220,255),width=2); d.line([(75,52),(89,52)],fill=(240,240,220,255),width=2)
    return im

def save(im,name): im.save(os.path.join(A,name))
for team,tname in [(0,'blue'),(1,'red')]:
    for kind in ['villager','swordsman','archer']: save(person(kind,team),f'{kind}_{tname}.png')

def building(kind,team):
    main=BLUE if team==0 else RED
    if kind=='tc': w=h=240
    elif kind=='barracks': w=h=200
    elif kind=='house': w=h=150
    else: w=h=150
    im=canvas(w,h); d=ImageDraw.Draw(im)
    cx=w//2
    if kind=='tower':
        d.polygon([(35,h-8),(45,55),(105,55),(115,h-8)],fill=(145,145,150,255),outline=DARK)
        for x in range(35,106,18): d.rectangle([x,38,x+12,58],fill=(145,145,150,255),outline=DARK)
        d.rectangle([63,82,88,125],fill=(90,55,32,255),outline=DARK)
        d.polygon([(75,10),(75,48),(105,30)],fill=main)
        d.line([(75,8),(75,52)],fill=DARK,width=3)
    elif kind=='house':
        d.rectangle([28,68,122,132],fill=(226,199,145,255),outline=DARK,width=3)
        d.polygon([(12,72),(75,22),(138,72)],fill=(152,72,45,255),outline=DARK)
        d.rectangle([63,94,88,132],fill=(95,56,30,255),outline=DARK); d.rectangle([39,83,57,103],fill=(130,200,235,255),outline=DARK)
    elif kind=='barracks':
        d.rectangle([22,75,178,168],fill=(190,164,116,255),outline=DARK,width=3)
        d.polygon([(8,80),(100,25),(192,80)],fill=(105,65,45,255),outline=DARK)
        d.rectangle([82,112,118,168],fill=(90,55,32,255),outline=DARK)
        d.line([(145,88),(166,112)],fill=(215,220,225,255),width=5); d.line([(166,88),(145,112)],fill=(215,220,225,255),width=5)
        d.rectangle([88,42,112,66],fill=main,outline=DARK)
    else:
        d.rectangle([30,82,210,218],fill=(205,178,125,255),outline=DARK,width=4)
        d.polygon([(12,88),(120,20),(228,88)],fill=(130,62,42,255),outline=DARK)
        d.rectangle([48,112,88,150],fill=(125,190,225,255),outline=DARK); d.rectangle([152,112,192,150],fill=(125,190,225,255),outline=DARK)
        d.rectangle([98,145,142,218],fill=(92,52,28,255),outline=DARK)
        d.rectangle([104,38,136,76],fill=main,outline=(245,205,70,255),width=3)
        d.text((120,57),'★',font=font,anchor='mm',fill=(255,225,80,255))
    return im
for team,tname in [(0,'blue'),(1,'red')]:
    for kind in ['tc','barracks','house','tower']: save(building(kind,team),f'{kind}_{tname}.png')

def tree():
    im=canvas(110,110); d=ImageDraw.Draw(im); d.rectangle([50,64,61,101],fill=(105,67,35,255),outline=DARK)
    for cx,cy,r,c in [(55,42,31,(42,139,54,255)),(33,55,23,(55,160,65,255)),(76,55,24,(35,125,48,255)),(55,25,22,(70,175,75,255))]: d.ellipse([cx-r,cy-r,cx+r,cy+r],fill=c,outline=(25,90,35,255),width=2)
    return im
def mine():
    im=canvas(130,110); d=ImageDraw.Draw(im)
    for poly in [[(5,92),(30,42),(58,92)],[(42,92),(75,25),(108,92)],[(78,92),(99,52),(124,92)]]: d.polygon(poly,fill=(118,118,125,255),outline=DARK)
    for x,y in [(65,48),(83,66),(48,70),(96,80)]: d.polygon([(x,y),(x+10,y-8),(x+18,y+2),(x+7,y+9)],fill=GOLD,outline=(130,85,0,255))
    return im
def bush():
    im=canvas(110,100); d=ImageDraw.Draw(im)
    for cx,cy,r in [(35,58,25),(58,45,30),(80,60,24),(55,68,28)]: d.ellipse([cx-r,cy-r,cx+r,cy+r],fill=(42,132,62,255),outline=(22,90,38,255),width=2)
    for x,y in [(35,48),(57,36),(75,55),(48,66),(84,72),(28,70)]: d.ellipse([x-6,y-6,x+6,y+6],fill=(218,45,65,255),outline=(120,10,30,255))
    return im
save(tree(),'tree.png'); save(mine(),'gold_mine.png'); save(bush(),'berry_bush.png')
# full grass map
random.seed(42); W=1920; im=Image.new('RGB',(W,W),(91,158,72)); d=ImageDraw.Draw(im,'RGBA')
for _ in range(260):
    x,y=random.randrange(W),random.randrange(W); r=random.randrange(45,170); c=random.choice([(55,130,55,45),(125,180,82,42),(75,145,62,50),(180,170,95,28)])
    d.ellipse([x-r,y-r,x+r,y+r],fill=c)
for _ in range(5200):
    x,y=random.randrange(W),random.randrange(W); col=random.choice([(45,120,48),(130,190,90),(210,200,120),(235,225,150)])
    d.line([(x,y),(x+random.randrange(-3,5),y-random.randrange(4,11))],fill=col,width=1)
for _ in range(160):
    x,y=random.randrange(W),random.randrange(W); d.ellipse([x,y,x+5,y+3],fill=random.choice([(160,160,150),(245,210,80),(235,130,160)]))
# dirt clearings at bases
for cx,cy,r in [(350,1570,270),(1580,350,290)]:
    d.ellipse([cx-r,cy-r//2,cx+r,cy+r//2],fill=(174,142,92,90))
im.save(os.path.join(A,'grass_map.png'),optimize=True)
print('assets done', os.listdir(A))
