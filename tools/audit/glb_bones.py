import json, struct, sys, os

def read(path):
    data = open(path,'rb').read()
    off=12; js=None
    while off+8 <= len(data):
        l,t = struct.unpack_from('<II', data, off); off+=8
        chunk=data[off:off+l]; off+=l
        if t==0x4E4F534A: js=json.loads(chunk.rstrip(b'\x00 \t\r\n').decode())
    return js

for p in sys.argv[1:]:
    js=read(p)
    print('='*100)
    print(p)
    skins=js.get('skins',[])
    for si,s in enumerate(skins):
        joints=s.get('joints',[])
        names=[js['nodes'][j].get('name','?') for j in joints]
        print(f'skin {si}: {len(joints)} joints')
        print(names)
    print('nodes:')
    print([n.get('name','?') for n in js.get('nodes',[])][:80])
    print('animations:', [a.get('name') for a in js.get('animations',[])])
