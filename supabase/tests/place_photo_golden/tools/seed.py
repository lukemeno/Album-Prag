"""Entwurf der goldenen Testliste. Erzeugt golden.json (nach Abgleich mit Wikidata via resolve_wikidata.py)."""
# Felder: query, region (Reisekontext), kind, category, tags, lat/lng (ungefähre Referenz, nur wo sicher), wd (Suchbegriff), lang
L = []
WIDE = {"Kampa-Insel", "East Side Gallery", "故宫"}  # Flächenobjekte: Mittelpunkt weicht von meinem Referenzpunkt ab
def add(query, region, kind, category, tags=(), lat=None, lng=None, wd=None, lang="en", same_as=None, note=""):
    L.append(dict(query=query, region=region, kind=kind, category=category, tags=list(tags), lat=lat, lng=lng, wd=wd, lang=lang, same_as=same_as, note=note, tol=600 if query in WIDE else 300))

# --- 1. Prag: Sehenswürdigkeiten (25) ---
P = "Prag"
for q, wd, la, lo in [
 ("Karlsbrücke","Charles Bridge",50.0865,14.4114),("Altstädter Ring","Old Town Square",50.0875,14.4213),
 ("Prager Burg","Prague Castle",50.0910,14.4005),("Strahov-Bibliothek","Strahov Monastery",50.0864,14.3883),
 ("Tanzendes Haus","Dancing House",50.0755,14.4140),("Franz-Kafka-Museum","Franz Kafka Museum",50.0869,14.4101),
 ("Letná Park","Letná",50.0966,14.4165),("Petřín-Aussichtsturm","Petřín Lookout Tower",50.0834,14.3953),
 ("Vyšehrad","Vyšehrad",50.0640,14.4200),("Wenzelsplatz","Wenceslas Square",50.0810,14.4280),
 ("Astronomische Uhr","Prague astronomical clock",50.0870,14.4208),("Nationaltheater","National Theatre",50.0812,14.4136),
 ("Pulverturm","Powder Tower",50.0875,14.4287),("Spanische Synagoge","Spanish Synagogue",50.0902,14.4180),
 ("Lennon-Mauer","Lennon Wall",50.0866,14.4066),("Veitsdom","St. Vitus Cathedral",50.0909,14.4005),
 ("Rudolfinum","Rudolfinum",50.0897,14.4152),("Schloss Troja","Troja Chateau",50.1167,14.4167),
 ("Goldenes Gässchen","Golden Lane",50.0905,14.4048),("Nationalmuseum","National Museum Prague",50.0790,14.4300),
 ("Žižkov-Fernsehturm","Žižkov Television Tower",50.0810,14.4500),("Gemeindehaus","Municipal House",50.0877,14.4283),
 ("Kampa-Insel","Kampa Island",50.0838,14.4076),("Vrtba-Garten","Vrtba Garden",50.0877,14.4047),
 ("Klementinum","Klementinum",50.0865,14.4160)]:
    add(q, P, "landmark", "Sehenswert", ["prag"], la, lo, wd)

# --- 2. Prag: Lokale (12), Referenz nur per Mensch ---
for q, cat, tags in [
 ("Café Savoy","Essen & Trinken",["cafe","prag"]),("Kavárna Slavia","Essen & Trinken",["cafe","tschechisch"]),
 ("Café Louvre","Essen & Trinken",["cafe","prag"]),("Café Imperial","Essen & Trinken",["cafe","hotel"]),
 ("Lokál Dlouhááá","Essen & Trinken",["kette-klein","diakritik"]),("Bake Shop Praha","Essen & Trinken",["bäckerei"]),
 ("Hergetova Cihelna","Essen & Trinken",["restaurant","diakritik"]),("Eska Karlín","Essen & Trinken",["restaurant"]),
 ("Mlýnec","Essen & Trinken",["restaurant","diakritik"]),("Field Restaurant","Essen & Trinken",["restaurant","mehrdeutig"]),
 ("Letná-Biergarten","Essen & Trinken",["biergarten","mehrdeutig"]),("U Fleků","Essen & Trinken",["brauerei","historisch"])]:
    add(q, P, "venue", cat, tags, wd=q)

# --- 3. Andere Städte (16) ---
for q, reg, wd, la, lo, kind, cat in [
 ("Schloss Schönbrunn","Wien","Schönbrunn Palace",48.1845,16.3122,"landmark","Sehenswert"),
 ("Café Central","Wien","Café Central",48.2104,16.3655,"venue","Essen & Trinken"),
 ("Hotel Sacher","Wien","Hotel Sacher",48.2040,16.3693,"venue","Essen & Trinken"),
 ("Brandenburger Tor","Berlin","Brandenburg Gate",52.5163,13.3777,"landmark","Sehenswert"),
 ("East Side Gallery","Berlin","East Side Gallery",52.5050,13.4397,"landmark","Sehenswert"),
 ("Torre de Belém","Lissabon","Belém Tower",38.6916,-9.2160,"landmark","Sehenswert"),
 ("Pastéis de Belém","Lissabon","Pastéis de Belém",38.6975,-9.2032,"venue","Essen & Trinken"),
 ("Eiffelturm","Paris","Eiffel Tower",48.8584,2.2945,"landmark","Sehenswert"),
 ("Louvre","Paris","Louvre",48.8606,2.3376,"landmark","Sehenswert"),
 ("Kolosseum","Rom","Colosseum",41.8902,12.4922,"landmark","Sehenswert"),
 ("Trevi-Brunnen","Rom","Trevi Fountain",41.9009,12.4833,"landmark","Sehenswert"),
 ("Sagrada Família","Barcelona","Sagrada Família",41.4036,2.1744,"landmark","Sehenswert"),
 ("Anne-Frank-Haus","Amsterdam","Anne Frank House",52.3752,4.8840,"landmark","Sehenswert"),
 ("Tower Bridge","London","Tower Bridge",51.5055,-0.0754,"landmark","Sehenswert"),
 ("Parlament","Budapest","Hungarian Parliament Building",47.5073,19.0456,"landmark","Sehenswert"),
 ("Wawel","Krakau","Wawel Royal Castle",50.0540,19.9352,"landmark","Sehenswert")]:
    add(q, reg, kind, cat, [reg.lower()], la, lo, wd)

# --- 4. Märkte (6) ---
for q, reg, wd, la, lo in [
 ("Naschmarkt","Wien","Naschmarkt",48.1986,16.3634),("Mercado da Ribeira","Lissabon","Time Out Market Lisboa",38.7062,-9.1457),
 ("Borough Market","London","Borough Market",51.5055,-0.0910),("La Boqueria","Barcelona","La Boqueria",41.3817,2.1719),
 ("Markthalle Neun","Berlin","Markthalle Neun",52.5021,13.4310),("Großer Basar","Istanbul","Grand Bazaar, Istanbul",41.0107,28.9680)]:
    add(q, reg, "landmark", "Sehenswert", ["markt", reg.lower()], la, lo, wd)

# --- 5. Gerichte und Begriffe ohne Ort (10): freies Bild, kein Ortsfoto ---
for q in ["Pasta","Trdelník","Svíčková","Knödel","Gulasch","Pizza Margherita","Pastel de Nata","Ramen","Currywurst","Bier"]:
    add(q, "Prag", "dish", "Essen & Trinken", ["gericht"], note="Kein Ort: erwartet freies Gerichtsbild, kein Lokal-Foto")

# --- 6. Mehrdeutig oder zu allgemein (10): nie blind ein Bild wählen ---
for q, note in [
 ("Fresca","Name von sehr vielen Lokalen weltweit"),("Konzeptbar","Kleiner Eigenname, kaum Quellen"),
 ("Café Central","Ohne Reisekontext Wien oder Prag oder andere"),("Altstadt","Gibt es in jeder Stadt"),
 ("Bakery","Allgemeinwort"),("Mama","Allgemeinwort, viele Lokale"),("Restaurant am Fluss","Beschreibung, kein Name"),
 ("Rooftop Bar","Allgemeinwort"),("Kino","Allgemeinwort"),("Aussichtsturm","Allgemeinwort")]:
    add(q, "Prag", "ambiguous", "Idee", ["mehrdeutig"], note=note)

# --- 7. Ketten (6): richtige Filiale oder neutral, kein falsches Logo-Bild ---
for q in ["Starbucks Wenzelsplatz","McDonald's Hauptbahnhof Prag","IKEA Zličín","Paul Prag Národní","Billa Prag","Lidl Prag"]:
    add(q, "Prag", "chain", "Essen & Trinken", ["kette"], note="Erwartet Filiale, Straßenansicht oder neutral; kein Logo als Hauptbild")

# --- 8. Nicht-lateinische Schrift (8) ---
for q, reg, wd, la, lo, lang in [
 ("東京タワー","Tokio","Tokyo Tower",35.6586,139.7454,"ja"),("浅草寺","Tokio","Sensō-ji",35.7148,139.7967,"ja"),
 ("Красная площадь","Moskau","Red Square",55.7539,37.6208,"ru"),("Эрмитаж","Sankt Petersburg","Hermitage Museum",59.9398,30.3146,"ru"),
 ("故宫","Peking","Forbidden City",39.9163,116.3972,"zh"),("경복궁","Seoul","Gyeongbokgung",37.5796,126.9770,"ko"),
 ("Παρθενώνας","Athen","Parthenon",37.9715,23.7267,"el"),("برج خليفة","Dubai","Burj Khalifa",25.1972,55.2744,"ar")]:
    add(q, reg, "landmark", "Sehenswert", ["schrift"], la, lo, wd, lang)

# --- 9. Schreibvarianten derselben Orte (7): müssen dasselbe Ergebnis liefern ---
for q, same, tags in [("Karlsbrucke","Karlsbrücke",["ohne-umlaut"]),("Karlův most","Karlsbrücke",["landessprache"]),
 ("Charles Bridge","Karlsbrücke",["englisch"]),("Prague Castle","Prager Burg",["englisch"]),
 ("Pražský hrad","Prager Burg",["landessprache"]),("Altstadter Ring","Altstädter Ring",["ohne-umlaut"]),
 ("Prager Burg Aussicht","Prager Burg",["zusatz"])]:
    add(q, "Prag", "variant", "Sehenswert", tags, same_as=same)

assert len(L) == 100, len(L)
