#!/usr/bin/env python3
"""Construit l'index des épisodes TF1+ et M6+ utilisé par StreamHub.

Sur ces plateformes, le lien d'un épisode contient un identifiant interne impossible à deviner :
  TF1+ : https://www.tf1.fr/tf1/demain-nous-appartient/videos/…-episode-2299-33917459.html
  M6+  : https://www.m6.fr/elementary-p_3100/saison-4-episode-21-c_11668702
et elles interdisent aux autres sites de lire leurs pages. Ce script lit leurs plans de site publics et
écrit, pour chaque programme, data/<plateforme>/<programme>.json :

    {"base": "…",                          # début du lien, commun aux épisodes du programme
     "e": {"2299": "<fin du lien>"},        # numéro absolu d'épisode
     "s": {"10-17": "<fin du lien>"},       # saison-épisode
     "d": {"2026-09-24": "<fin du lien>"}}  # date de diffusion

Lien complet = base + fin du lien. Lancé par .github/workflows/pages.yml toutes les 6 heures.

Usage : build_episode_index.py <dossier de sortie>
"""
import concurrent.futures
import json
import re
import sys
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


def main():
    out = Path(sys.argv[1])
    failed = False
    for name, videos in [('tf1', tf1_videos), ('m6', m6_videos)]:
        try:
            build(videos(), out / name)
        except Exception as err:  # une plateforme en panne ne bloque pas l'autre
            print(f'::warning::Index {name} non construit : {err}', flush=True)
            failed = True
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
