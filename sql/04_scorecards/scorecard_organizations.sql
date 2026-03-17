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
import tkinter as tk
import threading

def detect_type(text):
    text = text.strip()
    if re.match(r'^[A-Z0-9]{20}$', text):
        return "LEI"
    if re.match(r'^\d{1,10}$', text):
        return "CIK"
    if re.match(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$', text):
        return "ISIN"
    return "Name"

def open_url(url):
    if '#' in url:
        subprocess.Popen(['start', '', url], shell=True)
    else:
        webbrowser.open(url)

def build_urls_financial(text):
    encoded_text = urllib.parse.quote(text)
    return [
        f"https://sanctionssearch.ofac.treas.gov/Details.aspx?id={encoded_text}",
        f"https://banks.data.fdic.gov/api/institutions?filters=NAME%3A{encoded_text}&fields=NAME%2CCERT%2CCITY%2CSTNAME&limit=10&output=json",
        f"https://www.ffiec.gov/nicpubweb/content/searchform.aspx?rpt=BHC&selectedyear=2024",
        f"https://www.nmlsconsumeraccess.org/Home.aspx/SubSearch?searchText={encoded_text}&x=0&y=0",
        f"https://www.occ.gov/topics/charters-and-licensing/index-charters-and-licensing.html",
        f"https://efts.sec.gov/LATEST/search-index?q={encoded_text}",
    ]

def build_urls_non_financial(text):
    encoded_text = urllib.parse.quote(text)
    return [
        f"https://sanctionssearch.ofac.treas.gov/Details.aspx?id={encoded_text}",
        f"https://efts.sec.gov/LATEST/search-index?q={encoded_text}",
        f"https://opencorporates.com/companies?utf8=%E2%9C%93&q={encoded_text}&jurisdiction_code=&type=companies",
    ]

def build_urls_id(text):
    encoded_text = urllib.parse.quote(text)
    entity_type = detect_type(text)
    if entity_type == "LEI":
        return [f"https://search.gleif.org/#/record/{encoded_text}"]
    if entity_type == "CIK":
        return [
            f"https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK={encoded_text}",
            f"https://efts.sec.gov/LATEST/search-index?q={encoded_text}",
        ]
    if entity_type == "ISIN":
        return [f"https://www.isin.org/isin/{encoded_text}"]
    return [
        f"https://search.gleif.org/#/record/{encoded_text}",
        f"https://efts.sec.gov/LATEST/search-index?q={encoded_text}",
    ]

BG = "#F4F6FB"
CARD = "#FFFFFF"
NAVY = "#1B2A4A"
BLUE = "#2B4C8C"
TEXT_PRIMARY = "#1B2A4A"
TEXT_SECONDARY = "#7A8AA0"
GREEN = "#2ECC71"

class EntityValidatorApp:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Entity Validator")
        self.root.geometry("360x560")
        self.root.resizable(False, False)
        self.root.attributes('-topmost', True)
        self.root.configure(bg=BG)
        self.build_ui()
        self.register_hotkeys()

    def build_ui(self):
        header = tk.Frame(self.root, bg=NAVY, padx=20, pady=16)
        header.pack(fill=tk.X)
        tk.Label(header, text="Entity Validator", font=("Segoe UI", 15, "bold"),
                 fg="white", bg=NAVY).pack(anchor="w")
        status_frame = tk.Frame(header, bg=NAVY)
        status_frame.pack(fill=tk.X, pady=(4, 0))
        tk.Label(status_frame, text="●", fg=GREEN, font=("Segoe UI", 9), bg=NAVY).pack(side=tk.LEFT)
        tk.Label(status_frame, text="  Active — Esc to exit", fg="#A0B0C8",
                 font=("Segoe UI", 9), bg=NAVY).pack(side=tk.LEFT)

        main = tk.Frame(self.root, bg=BG, padx=16, pady=16)
        main.pack(fill=tk.BOTH, expand=True)

        text_card = tk.Frame(main, bg=CARD, padx=14, pady=12)
        text_card.pack(fill=tk.X, pady=(0, 10))
        tk.Label(text_card, text="Selected text", fg=TEXT_SECONDARY,
                 font=("Segoe UI", 8), bg=CARD, anchor="w").pack(fill=tk.X)
        self.text_box = tk.Label(text_card, text="—", font=("Segoe UI", 12, "bold"),
                                  fg=TEXT_PRIMARY, bg=CARD, anchor="w", wraplength=290)
        self.text_box.pack(fill=tk.X, pady=(4, 0))

        type_card = tk.Frame(main, bg=CARD, padx=14, pady=12)
        type_card.pack(fill=tk.X, pady=(0, 16))
        tk.Label(type_card, text="Detected type", fg=TEXT_SECONDARY,
                 font=("Segoe UI", 8), bg=CARD, anchor="w").pack(fill=tk.X)
        self.type_badge = tk.Label(type_card, text="—", font=("Segoe UI", 11, "bold"),
                                    fg=BLUE, bg=CARD, anchor="w")
        self.type_badge.pack(fill=tk.X, pady=(4, 0))

        tk.Label(main, text="Search options", fg=TEXT_SECONDARY,
                 font=("Segoe UI", 8), bg=BG, anchor="w").pack(fill=tk.X, pady=(0, 8))

        btn_frame = tk.Frame(main, bg=BG)
        btn_frame.pack(fill=tk.X)
        btn_frame.columnconfigure(0, weight=1)
        btn_frame.columnconfigure(1, weight=1)

        self.make_button(btn_frame, "Financial", "Ctrl+Shift+V", 0, 0, self.on_financial)
        self.make_button(btn_frame, "Non-financial", "Ctrl+Shift+B", 0, 1, self.on_non_financial)
        self.make_button(btn_frame, "By ID", "Ctrl+F1", 1, 0, self.on_id)
        self.make_button(btn_frame, "Google AI", "Ctrl+F2", 1, 1, self.on_google_ai)

        last_card = tk.Frame(main, bg=CARD, padx=14, pady=14)
        last_card.pack(fill=tk.X, pady=(16, 0))
        tk.Label(last_card, text="Last search", fg=TEXT_SECONDARY,
                 font=("Segoe UI", 8), bg=CARD, anchor="w").pack(fill=tk.X)
        self.last_search = tk.Label(last_card, text="—", font=("Segoe UI", 10),
                                     fg=TEXT_PRIMARY, bg=CARD, anchor="w",
                                     wraplength=290, justify="left")
        self.last_search.pack(fill=tk.X, pady=(6, 0))

    def make_button(self, parent, label, shortcut, row, col, command):
        frame = tk.Frame(parent, bg=NAVY, padx=10, pady=12, cursor="hand2")
        frame.grid(row=row, column=col, padx=4, pady=4, sticky="nsew")
        tk.Label(frame, text=label, font=("Segoe UI", 11, "bold"),
                 fg="white", bg=NAVY).pack()
        tk.Label(frame, text=shortcut, fg="#A0B0C8",
                 font=("Segoe UI", 8), bg=NAVY).pack()
        frame.bind("<Button-1>", lambda e: command())
        for widget in frame.winfo_children():
            widget.bind("<Button-1>", lambda e: command())

    def update_ui(self, text, entity_type):
        self.text_box.config(text=text if text else "—")
        self.type_badge.config(text=entity_type if entity_type else "—")

    def update_last_search(self, text, search_type, tab_count):
        self.last_search.config(text=f"{text} → {search_type} → {tab_count} tabs opened")

    def get_clipboard_text(self):
        time.sleep(0.1)
        return pyperclip.paste().strip()

    def run_search(self, search_type, urls, text):
        self.root.after(0, self.update_last_search, text, search_type, len(urls))
        for url in urls:
            open_url(url)
            time.sleep(0.3)

    def monitor_clipboard(self):
        last_text = ""
        while True:
            try:
                current = pyperclip.paste().strip()
                if current != last_text and current:
                    last_text = current
                    entity_type = detect_type(current)
                    self.root.after(0, self.update_ui, current, entity_type)
            except:
                pass
            time.sleep(0.3)

    def on_financial(self):
        text = self.get_clipboard_text()
        if not text:
            return
        self.update_ui(text, detect_type(text))
        urls = build_urls_financial(text)
        threading.Thread(target=self.run_search, args=("Financial", urls, text), daemon=True).start()

    def on_non_financial(self):
        text = self.get_clipboard_text()
        if not text:
            return
        self.update_ui(text, detect_type(text))
        urls = build_urls_non_financial(text)
        threading.Thread(target=self.run_search, args=("Non-financial", urls, text), daemon=True).start()

    def on_id(self):
        text = self.get_clipboard_text()
        if not text:
            return
        self.update_ui(text, detect_type(text))
        urls = build_urls_id(text)
        threading.Thread(target=self.run_search, args=("By ID", urls, text), daemon=True).start()

    def on_google_ai(self):
        text = self.get_clipboard_text()
        if not text:
            return
        self.update_ui(text, detect_type(text))
        encoded_text = urllib.parse.quote(text)
        query_ids = urllib.parse.quote(f"What is the LEI, ORBIS, CIK or TAX ID for {text}")
        urls = [
            f"https://www.google.com/search?q={query_ids}&udm=50",
            f"https://www.google.com/search?q={encoded_text}&udm=50",
        ]
        threading.Thread(target=self.run_search, args=("Google AI", urls, text), daemon=True).start()

    def register_hotkeys(self):
        keyboard.add_hotkey('ctrl+shift+v', self.on_financial)
        keyboard.add_hotkey('ctrl+shift+b', self.on_non_financial)
        keyboard.add_hotkey('ctrl+f1', self.on_id)
        keyboard.add_hotkey('ctrl+f2', self.on_google_ai)
        keyboard.add_hotkey('esc', self.root.quit)
        threading.Thread(target=self.monitor_clipboard, daemon=True).start()

    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    app = EntityValidatorApp()
    app.run()
