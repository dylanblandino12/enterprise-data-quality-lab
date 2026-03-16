-- =====================================================
-- Project: Enterprise Data Quality Lab
-- File: scorecard_organizations.sql
-- Author: Dylan Blandino
-- Created: 2026-02-23
--
-- Description:
-- Data Quality scorecard for enterprise_raw.organizations.
--
-- Output:
-- One row per DQ rule with KPI metrics.
-- =====================================================

WITH total_organizations AS (

    SELECT COUNT(*) AS total_records
    FROM enterprise_raw.organizations

),

rule_results AS (

    -- RULE 1: Missing org_name
    SELECT
        'DQ_ORG_001' AS dq_rule_id,
        'Missing org_name' AS rule_name,
        COUNT(*) AS failed_records
    FROM enterprise_raw.organizations
    WHERE org_name IS NULL


    UNION ALL


    -- RULE 2: Missing tax_id
    SELECT
        'DQ_ORG_002',
        'Missing tax_id',
        COUNT(*)
    FROM enterprise_raw.organizations
    WHERE tax_id IS NULL


    UNION ALL


    -- RULE 3: Invalid country format
    SELECT
        'DQ_ORG_003',
        'Invalid country format',
        COUNT(*)
    FROM enterprise_raw.organizations
    WHERE country IS NOT NULL
      AND (
            LENGTH(country) > 2
         OR country LIKE '%.%'
         OR country LIKE '%,%'
         OR country <> UPPER(country)
      )


    UNION ALL


    -- RULE 4: Duplicate org_name + country
    SELECT
        'DQ_ORG_004',
        'Duplicate organization',
        COUNT(*)
    FROM (
        SELECT
            COUNT(*) OVER (
                PARTITION BY org_name, country
            ) AS duplicate_count
        FROM enterprise_raw.organizations
        WHERE org_name IS NOT NULL
          AND country IS NOT NULL
    ) t
    WHERE duplicate_count > 1


    UNION ALL


    -- RULE 5: Invalid parent_org_id
    SELECT
        'DQ_ORG_005',
        'Invalid parent_org_id',
        COUNT(*)
    FROM enterprise_raw.organizations p
    LEFT JOIN enterprise_raw.organizations o
        ON p.parent_org_id = o.org_id
    WHERE o.org_id IS NULL
      AND p.parent_org_id IS NOT NULL

)

SELECT

    r.dq_rule_id,
    r.rule_name,
    t.total_records,
    r.failed_records,

    ROUND(
        1 - (r.failed_records::NUMERIC / NULLIF(t.total_records, 0)),
        4
    ) AS pass_rate,

    ROUND(
        r.failed_records::NUMERIC / NULLIF(t.total_records, 0),
        4
    ) AS fail_rate

FROM rule_results r
CROSS JOIN total_organizations t

ORDER BY r.dq_rule_id;


import keyboard
import pyperclip
import webbrowser
import urllib.parse
import re
import time
import subprocess

def detectar_tipo(texto):
    texto = texto.strip()
    
    if re.match(r'^[A-Z0-9]{20}$', texto):
        return "LEI"
    
    if re.match(r'^\d{1,10}$', texto):
        return "CIK"
    
    if re.match(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$', texto):
        return "ISIN"
    
    return "nombre"

def abrir_url(url):
    if '#' in url:
        subprocess.Popen(['start', '', url], shell=True)
    else:
        webbrowser.open(url)

def construir_urls_financiero(texto):
    texto_encoded = urllib.parse.quote(texto)
    return [
        f"https://sanctionssearch.ofac.treas.gov/Details.aspx?id={texto_encoded}",
        f"https://banks.data.fdic.gov/api/institutions?filters=NAME%3A{texto_encoded}&fields=NAME%2CCERT%2CCITY%2CSTNAME&limit=10&output=json",
        f"https://www.ffiec.gov/nicpubweb/content/searchform.aspx?rpt=BHC&selectedyear=2024",
        f"https://www.nmlsconsumeraccess.org/Home.aspx/SubSearch?searchText={texto_encoded}&x=0&y=0",
        f"https://www.occ.gov/topics/charters-and-licensing/index-charters-and-licensing.html",
        f"https://efts.sec.gov/LATEST/search-index?q={texto_encoded}",
    ]

def construir_urls_no_financiero(texto):
    texto_encoded = urllib.parse.quote(texto)
    return [
        f"https://sanctionssearch.ofac.treas.gov/Details.aspx?id={texto_encoded}",
        f"https://efts.sec.gov/LATEST/search-index?q={texto_encoded}",
        f"https://opencorporates.com/companies?utf8=%E2%9C%93&q={texto_encoded}&jurisdiction_code=&type=companies",
    ]

def construir_urls_id(texto):
    texto_encoded = urllib.parse.quote(texto)
    tipo = detectar_tipo(texto)

    if tipo == "LEI":
        return [
            f"https://search.gleif.org/#/record/{texto_encoded}",
        ]
    
    if tipo == "CIK":
        return [
            f"https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK={texto_encoded}",
            f"https://efts.sec.gov/LATEST/search-index?q={texto_encoded}",
        ]
    
    if tipo == "ISIN":
        return [
            f"https://www.isin.org/isin/{texto_encoded}",
        ]
    
    # Si no detecta tipo, abre ambos
    return [
        f"https://search.gleif.org/#/record/{texto_encoded}",
        f"https://efts.sec.gov/LATEST/search-index?q={texto_encoded}",
    ]

def buscar_financiero(texto):
    texto = texto.strip()
    if not texto:
        print("No se detectó texto seleccionado.")
        return
    urls = construir_urls_financiero(texto)
    print(f"\nTexto: {texto}")
    print(f"Tipo: Financiero")
    print(f"Abriendo {len(urls)} tabs...")
    for url in urls:
        abrir_url(url)
        time.sleep(0.3)

def buscar_no_financiero(texto):
    texto = texto.strip()
    if not texto:
        print("No se detectó texto seleccionado.")
        return
    urls = construir_urls_no_financiero(texto)
    print(f"\nTexto: {texto}")
    print(f"Tipo: No financiero")
    print(f"Abriendo {len(urls)} tabs...")
    for url in urls:
        abrir_url(url)
        time.sleep(0.3)

def buscar_id(texto):
    texto = texto.strip()
    if not texto:
        print("No se detectó texto seleccionado.")
        return
    tipo = detectar_tipo(texto)
    urls = construir_urls_id(texto)
    print(f"\nTexto: {texto}")
    print(f"Tipo detectado: {tipo}")
    print(f"Abriendo {len(urls)} tabs...")
    for url in urls:
        abrir_url(url)
        time.sleep(0.3)

def buscar_google_ai(texto):
    texto = texto.strip()
    if not texto:
        print("No se detectó texto seleccionado.")
        return
    texto_encoded = urllib.parse.quote(texto)
    query_ids = urllib.parse.quote(f"What is the LEI, ORBIS, CIK or TAX ID for {texto}")
    print(f"\nTexto: {texto}")
    print(f"Abriendo Google AI...")
    webbrowser.open(f"https://www.google.com/search?q={query_ids}&udm=50")
    time.sleep(0.3)
    webbrowser.open(f"https://www.google.com/search?q={texto_encoded}&udm=50")

def on_hotkey_financiero():
    keyboard.send('ctrl+c')
    time.sleep(0.3)
    texto = pyperclip.paste()
    buscar_financiero(texto)

def on_hotkey_no_financiero():
    keyboard.send('ctrl+c')
    time.sleep(0.3)
    texto = pyperclip.paste()
    buscar_no_financiero(texto)

def on_hotkey_id():
    keyboard.send('ctrl+c')
    time.sleep(0.3)
    texto = pyperclip.paste()
    buscar_id(texto)

def on_hotkey_google_ai():
    keyboard.send('ctrl+c')
    time.sleep(0.3)
    texto = pyperclip.paste()
    buscar_google_ai(texto)

print("Script activo:")
print("  Ctrl+Shift+V → Financieros (OFAC, FDIC, FFIEC, NMLS, OCC, SEC)")
print("  Ctrl+Shift+B → No financieros (OFAC, SEC, OpenCorporates)")
print("  Ctrl+Shift+I → Por ID (LEI → GLEIF, CIK → SEC, ISIN → ISIN.org)")
print("  Ctrl+Shift+G → Google AI (búsqueda general + IDs)")
print("Para salir presioná Esc\n")

keyboard.add_hotkey('ctrl+shift+v', on_hotkey_financiero)
keyboard.add_hotkey('ctrl+shift+b', on_hotkey_no_financiero)
keyboard.add_hotkey('ctrl+shift+i', on_hotkey_id)
keyboard.add_hotkey('ctrl+shift+g', on_hotkey_google_ai)
keyboard.wait('esc')
