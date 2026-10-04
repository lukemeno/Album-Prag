#!/usr/bin/env python3
"""Write isolated AlbumData and optional synthetic PDF parser fixtures.

The generated PDF is deterministic local text for parser smoke checks. It is
not an authentic booking confirmation and must not be passed as ALBUM_SAMPLE_PDF
to the real-booking gate.
"""
import argparse, json, pathlib, struct, time, zlib

EPOCH = 978307200.0
def date(): return time.time() - EPOCH
def place(i, title, category, lat, lng, day, order):
    return {"id":i,"title":title,"note":"QA fixture","sourceURL":"","category":category,"author":"Luke","image":None,"address":"Prag","lat":lat,"lng":lng,"franked":True,"deferred":False,"deleted":False,"visited":False,"day":day,"dayOrder":order,"approvals":["Luke"],"passedBy":[],"openingHours":None,"gallery":None,"updatedAt":date()}
def data(unassigned=False):
    day = lambda value: None if unassigned else value
    order = lambda value: None if unassigned else value
    return {"albumID":"qa-full-plan","places":[place("qa-oldtown","Altstädter Ring","Sehenswert",50.0875,14.4213,day(4),order(0)),place("qa-letna","Letná","Aussicht",50.0966,14.4165,day(4),order(1)),place("qa-cafe","Café Savoy","Essen & Trinken",50.0817,14.4125,day(5),order(0)),place("qa-castle","Prager Burg","Sehenswert",50.091,14.4,day(6),order(0)),place("qa-cluster-a","Cluster A","Sehenswert",50.08755,14.42135,day(7),order(0)),place("qa-cluster-b","Cluster B","Aussicht",50.08757,14.42137,day(7),order(1))],"trip":{"hotel":"QA Hotel","outbound":"","arrival":"","route":"","flightNumber":"","notes":"QA fixture","updatedAt":date(),"flights":[{"direction":"outbound","number":"QA100","airline":"QA Air","from":"Berlin","to":"Prag","date":"04.10.2026","departure":"08:10","arrival":"09:20","arriveBy":"06:30","bookingCode":"QA"},{"direction":"inbound","number":"QA101","airline":"QA Air","from":"Prag","to":"Berlin","date":"09.10.2026","departure":"18:05","arrival":"19:15","arriveBy":"16:20","bookingCode":"QA"}],"hotelDetails":{"name":"QA Hotel","address":"Prag","checkIn":"15:00","checkOut":"11:00","included":[]},"bookingNumber":"QA-2026","travelers":["Luke"]},"documents":[],"dirty":[],"collaboration":None,"collectionEntries":[],"collectionSync":{}}
def pdf(path):
    text="BT /F1 12 Tf 72 740 Td (QA Booking Confirmation) Tj 0 -24 Td (QA100 Berlin Prag 04.10.2026 08:10 09:20) Tj 0 -24 Td (QA101 Prag Berlin 09.10.2026 18:05 19:15) Tj 0 -24 Td (Hotel QA Hotel Check-in 15:00 Check-out 11:00) Tj ET"
    objs=[b"<< /Type /Catalog /Pages 2 0 R >>",b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",f"<< /Length {len(text.encode())} >>\nstream\n{text}\nendstream".encode(),b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
    out=bytearray(b"%PDF-1.4\n"); offsets=[0]
    for i,obj in enumerate(objs,1): offsets.append(len(out)); out.extend(f"{i} 0 obj\n".encode()+obj+b"\nendobj\n")
    xref=len(out); out.extend(f"xref\n0 {len(objs)+1}\n0000000000 65535 f \n".encode()+b"".join(f"{o:010d} 00000 n \n".encode() for o in offsets[1:]))
    out.extend(f"trailer\n<< /Size {len(objs)+1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()); path.write_bytes(out)
def main():
    p=argparse.ArgumentParser(); p.add_argument("--app-container",required=True); p.add_argument("--store",default="slot-full-plan"); p.add_argument("--pdf",action="store_true",help="also write a synthetic local parser PDF; not a real booking document"); p.add_argument("--unassigned",action="store_true",help="leave fixture places without a day for automatic-plan tests"); p.add_argument("--known-hours",action="store_true",help="set empty known opening-hours strings for deterministic QA; not a live opening-hours proof")
    a=p.parse_args(); c=pathlib.Path(a.app_container).expanduser().resolve()
    if not c.is_dir(): raise SystemExit(f"not an app container: {c}")
    target=c/"Library/Application Support/AlbumUITests"/a.store; target.mkdir(parents=True,exist_ok=True)
    payload=data(unassigned=a.unassigned)
    if a.known_hours:
        for item in payload["places"]: item["openingHours"]=""
    (target/"album.json").write_text(json.dumps(payload,ensure_ascii=False,separators=(",",":")),encoding="utf-8")
    if a.pdf:
        docs=c/"Documents/QA"; docs.mkdir(parents=True,exist_ok=True); pdf(docs/"qa-valid-booking.pdf")
    print(target)
if __name__=="__main__": main()
