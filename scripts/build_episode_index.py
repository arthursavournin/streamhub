#!/usr/bin/env python3
"""Construit l'index des épisodes TF1+ et M6+, et ceux des chaînes de Canal+ (HBO Max, Apple TV, Paramount+),
utilisés par StreamHub.

Sur ces plateformes, le lien d'un épisode contient un identifiant interne impossible à deviner :
  TF1+ : https://www.tf1.fr/tf1/demain-nous-appartient/videos/…-episode-2299-33917459.html
  M6+  : https://www.m6.fr/elementary-p_3100/saison-4-episode-21-c_11668702
et elles interdisent aux autres sites de lire leurs pages. Ce script lit leurs plans de site publics et
écrit, pour chaque programme, data/<plateforme>/<programme>.json :

    {"base": "…",                          # début du lien, commun aux épisodes du programme
     "e": {"2299": "<fin du lien>"},        # numéro absolu d'épisode
     "s": {"10-17": "<fin du lien>"},       # saison-épisode
     "d": {"2026-09-24": "<fin du lien>"}}  # date de diffusion

Lien complet = base + fin du lien.

Chaînes de Canal+ (HBO Max, Apple TV, Paramount+, accessibles par l'abonnement Canal+) : un titre y a sa propre
fiche Canal+, sans rapport avec la fiche Canal VOD (Harry Potter : /cinema/harry-potter-a-l-ecole-des-sorciers/h/
40438941_50889 sur HBO Max, contre …/h/435039_40099 en VOD), et Canal+ interdit aux autres sites d'utiliser sa
recherche. On lit donc les grilles de catalogue (Films, Séries, Tous les programmes…) de la page de chaque chaîne sur
Canal+ (API publique du site) et on écrit data/canal/<chaîne>.json (hbo, appletv, paramount) :

    {"movie": {"harrypotteralecoledessorciers": "/cinema/…/h/40438941_50889"},  # titre simplifié → chemin
     "tv": {"thelastofus": "/series/the-last-of-us/h/40427680_50889"}}

Lancé par .github/workflows/pages.yml toutes les 6 heures.

Usage : build_episode_index.py <dossier de sortie>
"""
import concurrent.futures
import json
import re
import sys
import time
import unicodedata
import urllib.request
from collections import defaultdict
from pathlib import Path

UA = 'Mozilla/5.0 (compatible; StreamHub/1.0; +https://arthursavournin.github.io/streamhub/)'
MONTHS = {m: i + 1 for i, m in enumerate(
    'janvier fevrier mars avril mai juin juillet aout septembre octobre novembre decembre'.split())}

SEASON_EP = re.compile(r'(?:^|-)s(\d{1,2})-?e(\d{1,3})(?:-|$)|saison-(\d{1,2})-episode-(\d{1,4})(?:-|$)')
ABSOLUTE = re.compile(r'(?:^|-)episode-(\d{1,5})(?:-|$)')
DATE = re.compile(r'-du-(?:lundi-|mardi-|mercredi-|jeudi-|vendredi-|samedi-|dimanche-)?(\d{1,2})-([a-z]+)-(\d{4})(?:-|$)')


def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=120) as res:
        return res.read().decode('utf-8', 'replace')


def fetch_all(urls):
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        yield from pool.map(fetch, urls)


def episode_keys(name):
    """Clés d'un épisode d'après la fin de son lien : saison-épisode, numéro absolu, date."""
    name = name.lower()
    keys = []
    if m := SEASON_EP.search(name):
        season, episode = (m.group(1), m.group(2)) if m.group(1) else (m.group(3), m.group(4))
        keys.append(('s', f'{int(season)}-{int(episode)}'))
    elif m := ABSOLUTE.search(name):
        keys.append(('e', str(int(m.group(1)))))
    if (m := DATE.search(name)) and m.group(2) in MONTHS:
        keys.append(('d', f'{m.group(3)}-{MONTHS[m.group(2)]:02d}-{int(m.group(1)):02d}'))
    return keys


def better(new, old):
    """Entre deux vidéos pour le même épisode, on préfère l'épisode normal à l'avant-première."""
    return old is None or ('avant-premiere' in old and 'avant-premiere' not in new)


def build(videos, out):
    """videos : (programme, base du lien, fin du lien) → écrit un fichier JSON par programme."""
    programs = defaultdict(lambda: {'base': None, 'e': {}, 's': {}, 'd': {}})
    for program, base, tail in videos:
        keys = episode_keys(tail)
        if not keys:
            continue  # bonus, extraits, coulisses…
        entry = programs[program]
        entry['base'] = entry['base'] or base
        for kind, key in keys:
            if better(tail, entry[kind].get(key)):
                entry[kind][key] = tail
    out.mkdir(parents=True, exist_ok=True)
    for program, entry in programs.items():
        (out / f'{program}.json').write_text(json.dumps({k: v for k, v in entry.items() if v}, separators=(',', ':')), 'utf-8')
    # Liste des programmes par nom simplifié (lettres et chiffres) : le nom dans le lien ne suit pas
    # toujours le titre (NCIS est « n-c-i-s » sur M6+), StreamHub cherche donc par nom simplifié
    names = {re.sub(r'[^a-z0-9]', '', program): program for program in programs}
    (out / '_programs.json').write_text(json.dumps(names, separators=(',', ':')), 'utf-8')
    print(f'{len(programs)} programmes indexés dans {out}', flush=True)


def tf1_videos():
    # Plans de site vidéo de la France : sitemap-v1.xml, -v2… (les autres ont un code pays : -fr-be1…)
    index = fetch('https://www.tf1.fr/sitemaps/sitemap-v.xml')
    files = re.findall(r'<loc>(https://www\.tf1\.fr/sitemaps/sitemap-v\d+\.xml)</loc>', index)
    video = re.compile(r'<loc>https://www\.tf1\.fr/([a-z0-9-]+)/([a-z0-9-]+)/videos/([a-z0-9-]+\.html)</loc>')
    for text in fetch_all(files):
        for channel, program, tail in video.findall(text):
            yield program, f'https://www.tf1.fr/{channel}/{program}/videos/', tail


def m6_videos():
    index = fetch('https://www.m6.fr/sitemap.xml')
    files = re.findall(r'<loc>(https://www\.m6\.fr/sitemap-\d+\.xml)</loc>', index)
    # https://www.m6.fr/<programme>-p_<id>/<épisode>-c_<id>
    video = re.compile(r'<loc>https://www\.m6\.fr/([a-z0-9-]+)-p_(\d+)/([A-Za-z0-9-]+-c_\d+)</loc>')
    for text in fetch_all(files):
        for program, program_id, tail in video.findall(text):
            yield program, f'https://www.m6.fr/{program}-p_{program_id}/', tail


# Canal+ : jeton public du site (portail France, visiteur non connecté), visible dans les adresses de son API.
# S'il change, les index ne sont pas construits et StreamHub ouvre la page de la chaîne sur Canal+.
CANAL_TOKEN = 'b63a43e7548cb1a6e7c7319084f48af8'
# Pages des chaînes sur Canal+ (/chaines/hbo-max/, /chaines/apple-tv/, /chaines/paramount-plus/)
CANAL_CHANNELS = {'hbo': 125873, 'appletv': 119267, 'paramount': 116426}
# L'API refuse les requêtes qui ne ressemblent pas à celles d'un navigateur sur canalplus.com
CANAL_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/141.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'fr-FR,fr;q=0.9',
    'Origin': 'https://www.canalplus.com',
    'Referer': 'https://www.canalplus.com/',
    'Sec-Fetch-Site': 'cross-site',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Dest': 'empty',
    'sec-ch-ua': '"Chromium";v="141", "Google Chrome";v="141"',
    'sec-ch-ua-platform': '"macOS"',
    'sec-ch-ua-mobile': '?0',
}


def canal_json(url):
    req = urllib.request.Request(url, headers=CANAL_HEADERS)
    with urllib.request.urlopen(req, timeout=60) as res:
        return json.loads(res.read().decode('utf-8'))


def simplify(title):
    """« Harry Potter à l'école des sorciers » → « harrypotteralecoledessorciers » (comme episodes.js)."""
    text = unicodedata.normalize('NFD', str(title)).lower()
    return re.sub(r'[^a-z0-9]', '', ''.join(c for c in text if not unicodedata.combining(c)))


def canal_channel(out, key, page_id):
    """Catalogue d'une chaîne de Canal+ : titre simplifié → chemin de la fiche, films et séries à part."""
    hub = canal_json(f'https://hodor.canalplus.pro/api/v2/mycanal/page/{CANAL_TOKEN}/{page_id}.json?aegon=true')
    # Grilles complètes (« contentGrid ») de la page : une par catégorie. Sur HBO Max, « Tous les programmes » ne
    # contient presque que des séries et émissions : les films sont dans la grille « Films ».
    grids = list(dict.fromkeys(
        c['onClick']['URLPage'] for strate in hub.get('strates', []) for c in strate.get('contents', [])
        if (c.get('onClick') or {}).get('displayTemplate') == 'contentGrid' and c['onClick'].get('URLPage')
    ))
    if not grids:
        raise RuntimeError(f'aucune grille de catégorie sur la page {key} de Canal+')
    index = {'movie': {}, 'tv': {}}
    pages = 0
    for url in grids:
        while url and pages < 300:
            grid = canal_json(url)
            pages += 1
            for content in grid.get('contents', []):
                path = (content.get('onClick') or {}).get('path', '')
                title = simplify(content.get('title', ''))
                if not title or not re.search(r'/h/\d+_\d+$', path):
                    continue
                kind = 'movie' if path.startswith('/cinema/') else 'tv'
                index[kind].setdefault(title, path)
            paging = grid.get('paging') or {}
            url = paging.get('URLPage') if paging.get('hasNextPage') else None
            time.sleep(0.3)
    total = len(index['movie']) + len(index['tv'])
    if total < 50:
        raise RuntimeError(f'catalogue {key} de Canal+ incomplet ({total} titres)')
    (out / 'canal').mkdir(parents=True, exist_ok=True)
    (out / 'canal' / f'{key}.json').write_text(json.dumps(index, ensure_ascii=False, separators=(',', ':')))
    print(f'canal/{key} : {total} titres ({pages} pages)', flush=True)


def main():
    out = Path(sys.argv[1])
    failed = False
    for name, videos in [('tf1', tf1_videos), ('m6', m6_videos)]:
        try:
            build(videos(), out / name)
        except Exception as err:  # une plateforme en panne ne bloque pas l'autre
            print(f'::warning::Index {name} non construit : {err}', flush=True)
            failed = True
    for key, page_id in CANAL_CHANNELS.items():
        try:
            canal_channel(out, key, page_id)
        except Exception as err:  # une chaîne en panne ne bloque pas les autres
            print(f'::warning::Index canal/{key} non construit : {err}', flush=True)
            failed = True
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
