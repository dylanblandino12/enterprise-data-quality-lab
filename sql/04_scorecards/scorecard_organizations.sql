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


"""
Entity Validator - DQ Automation Tool
======================================
A desktop tool that automates entity validation searches across multiple
regulatory and financial databases. Built for Data Quality teams to reduce
manual research time during entity validation and deduplication processes.

Author: Dylan Blandino
Version: 1.0

Hotkeys:
    Ctrl+Shift+V  ->  Search financial entities (OFAC, FDIC, FFIEC, NMLS, OCC, SEC)
    Ctrl+Shift+B  ->  Search non-financial entities (OFAC, SEC, OpenCorporates)
    Ctrl+F1       ->  Search by ID (LEI -> GLEIF, CIK -> SEC, ISIN -> ISIN.org)
    Ctrl+F2       ->  Search on Google AI (general + ID lookup)
    Esc           ->  Exit the application

Usage:
    1. Run the script as administrator: python main.py
    2. Select any text (entity name or ID) and press Ctrl+C
    3. The tool detects the text and its type automatically
    4. Press the appropriate hotkey to open the search results
    5. Use the red button to close the search window when done

Requirements:
    pip install keyboard pyperclip pygetwindow
"""

import keyboard       # Listens for global hotkeys across all applications
import pyperclip      # Reads and writes clipboard content
import webbrowser     # Opens URLs in the default browser (fallback)
import urllib.parse   # Encodes text into URL-safe format
import re             # Pattern matching for entity type detection
import time           # Handles delays between operations
import subprocess     # Opens Chrome with specific URLs and handles # in URLs
import tkinter as tk  # Builds the graphical user interface
import threading      # Runs background tasks without freezing the UI
import os             # Handles file paths for Chrome detection
import pygetwindow as gw  # Finds and controls open Chrome windows


# ─────────────────────────────────────────────
# ENTITY TYPE DETECTION
# ─────────────────────────────────────────────

def detect_type(text):
    """
    Detects the type of entity based on the format of the input text.

    Patterns:
        LEI  -> Exactly 20 alphanumeric characters (e.g. 529900T8BM49AURSDO55)
        CIK  -> 1 to 10 numeric digits (e.g. 0001234567)
        ISIN -> 2 letters + 9 alphanumeric + 1 digit (e.g. US0378331005)
        Name -> Any other text (e.g. Apple Inc)

    Args:
        text (str): The text copied from the clipboard.

    Returns:
        str: One of "LEI", "CIK", "ISIN", or "Name".
    """
    text = text.strip()
    if re.match(r'^[A-Z0-9]{20}$', text):
        return "LEI"
    if re.match(r'^\d{1,10}$', text):
        return "CIK"
    if re.match(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$', text):
        return "ISIN"
    return "Name"


# ─────────────────────────────────────────────
# CHROME DETECTION
# ─────────────────────────────────────────────

def find_chrome():
    """
    Searches for the Chrome executable in common installation paths.

    Returns:
        str: Full path to chrome.exe if found, None otherwise.
    """
    paths = [
        "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
        "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
        os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"),
    ]
    for path in paths:
        if os.path.exists(path):
            return path
    return None


# ─────────────────────────────────────────────
# URL BUILDERS
# ─────────────────────────────────────────────

def build_urls_financial(text):
    """
    Builds a list of search URLs for financial entities.

    Sources:
        - OFAC Sanctions Search
        - FDIC Bank Search
        - FFIEC Institution Search
        - NMLS Consumer Access
        - OCC Charters and Licensing
        - SEC EDGAR Full-Text Search

    Args:
        text (str): Entity name to search.

    Returns:
        list: List of URLs to open.
    """
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
    """
    Builds a list of search URLs for non-financial entities.

    Sources:
        - OFAC Sanctions Search
        - SEC EDGAR Full-Text Search
        - OpenCorporates Company Search

    Args:
        text (str): Entity name to search.

    Returns:
        list: List of URLs to open.
    """
    encoded_text = urllib.parse.quote(text)
    return [
        f"https://sanctionssearch.ofac.treas.gov/Details.aspx?id={encoded_text}",
        f"https://efts.sec.gov/LATEST/search-index?q={encoded_text}",
        f"https://opencorporates.com/companies?utf8=%E2%9C%93&q={encoded_text}&jurisdiction_code=&type=companies",
    ]


def build_urls_id(text):
    """
    Builds search URLs based on the detected ID type.

    Routing:
        LEI  -> GLEIF record lookup
        CIK  -> SEC EDGAR company search + full-text search
        ISIN -> ISIN.org lookup
        Other -> GLEIF + SEC EDGAR as fallback

    Args:
        text (str): The ID to search.

    Returns:
        list: List of URLs to open.
    """
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


# ─────────────────────────────────────────────
# COLOR PALETTE
# ─────────────────────────────────────────────

BG           = "#F4F6FB"  # App background (light gray-blue)
CARD         = "#FFFFFF"  # Card background (white)
NAVY         = "#1B2A4A"  # Primary color for header and buttons
BLUE         = "#2B4C8C"  # Accent color for detected type label
TEXT_PRIMARY = "#1B2A4A"  # Main text color
TEXT_SECONDARY = "#7A8AA0"  # Muted text color for labels
GREEN        = "#2ECC71"  # Status indicator (active)
RED          = "#E74C3C"  # Close window button


# ─────────────────────────────────────────────
# MAIN APPLICATION
# ─────────────────────────────────────────────

class EntityValidatorApp:
    """
    Main application class. Builds the UI, registers hotkeys,
    monitors the clipboard, and manages the Chrome search window.
    """

    def __init__(self):
        """Initializes the app window and core state variables."""
        self.root = tk.Tk()
        self.root.title("Entity Validator")
        self.root.geometry("360x620")
        self.root.resizable(False, False)
        self.root.attributes('-topmost', True)  # Always on top
        self.root.configure(bg=BG)
        self.chrome = find_chrome()
        self.search_window_title = None  # Tracks the active Chrome search window
        self.build_ui()
        self.register_hotkeys()

    def build_ui(self):
        """Constructs all UI elements: header, cards, buttons, and last search section."""

        # Header
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

        # Selected text display
        text_card = tk.Frame(main, bg=CARD, padx=14, pady=12)
        text_card.pack(fill=tk.X, pady=(0, 10))
        tk.Label(text_card, text="Selected text", fg=TEXT_SECONDARY,
                 font=("Segoe UI", 8), bg=CARD, anchor="w").pack(fill=tk.X)
        self.text_box = tk.Label(text_card, text="—", font=("Segoe UI", 12, "bold"),
                                  fg=TEXT_PRIMARY, bg=CARD, anchor="w", wraplength=290)
        self.text_box.pack(fill=tk.X, pady=(4, 0))

        # Detected type display
        type_card = tk.Frame(main, bg=CARD, padx=14, pady=12)
        type_card.pack(fill=tk.X, pady=(0, 16))
        tk.Label(type_card, text="Detected type", fg=TEXT_SECONDARY,
                 font=("Segoe UI", 8), bg=CARD, anchor="w").pack(fill=tk.X)
        self.type_badge = tk.Label(type_card, text="—", font=("Segoe UI", 11, "bold"),
                                    fg=BLUE, bg=CARD, anchor="w")
        self.type_badge.pack(fill=tk.X, pady=(4, 0))

        # Search buttons
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

        # Close window button
        close_frame = tk.Frame(main, bg=RED, padx=10, pady=12, cursor="hand2")
        close_frame.pack(fill=tk.X, pady=(8, 0))
        tk.Label(close_frame, text="Close Search Window", font=("Segoe UI", 11, "bold"),
                 fg="white", bg=RED).pack()
        tk.Label(close_frame, text="Closes current Chrome search window",
                 fg="#FADBD8", font=("Segoe UI", 8), bg=RED).pack()
        close_frame.bind("<Button-1>", lambda e: self.close_search_window())
        for widget in close_frame.winfo_children():
            widget.bind("<Button-1>", lambda e: self.close_search_window())

        # Last search display
        last_card = tk.Frame(main, bg=CARD, padx=14, pady=14)
        last_card.pack(fill=tk.X, pady=(16, 0))
        tk.Label(last_card, text="Last search", fg=TEXT_SECONDARY,
                 font=("Segoe UI", 8), bg=CARD, anchor="w").pack(fill=tk.X)
        self.last_search = tk.Label(last_card, text="—", font=("Segoe UI", 10),
                                     fg=TEXT_PRIMARY, bg=CARD, anchor="w",
                                     wraplength=290, justify="left")
        self.last_search.pack(fill=tk.X, pady=(6, 0))

    def make_button(self, parent, label, shortcut, row, col, command):
        """
        Creates a clickable button with a label and shortcut hint.

        Args:
            parent: Parent tkinter frame.
            label (str): Button label text.
            shortcut (str): Hotkey hint displayed below the label.
            row (int): Grid row position.
            col (int): Grid column position.
            command (callable): Function to call on click.
        """
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
        """Updates the selected text and detected type labels in the UI."""
        self.text_box.config(text=text if text else "—")
        self.type_badge.config(text=entity_type if entity_type else "—")

    def update_last_search(self, text, search_type, tab_count):
        """Updates the last search label with the most recent search info."""
        self.last_search.config(text=f"{text} → {search_type} → {tab_count} tabs added")

    def get_clipboard_text(self):
        """
        Reads the current clipboard content with a short delay
        to ensure the OS has finished copying.

        Returns:
            str: Stripped clipboard text.
        """
        time.sleep(0.1)
        return pyperclip.paste().strip()

    def find_search_window(self):
        """
        Looks for the active Chrome search window by its saved title.

        Returns:
            Window object if found, None otherwise.
        """
        if self.search_window_title:
            windows = gw.getWindowsWithTitle(self.search_window_title)
            if windows:
                return windows[0]
        return None

    def open_urls(self, urls):
        """
        Opens URLs in Chrome. If a search window already exists,
        adds tabs to it. Otherwise opens a new Chrome window.

        Args:
            urls (list): List of URLs to open.
        """
        existing = self.find_search_window()
        if existing and self.chrome:
            for url in urls:
                subprocess.Popen([self.chrome, url])
                time.sleep(0.3)
        else:
            if self.chrome:
                subprocess.Popen([self.chrome, "--new-window"] + urls)
                time.sleep(1.5)
                chrome_windows = gw.getWindowsWithTitle("Chrome")
                if chrome_windows:
                    self.search_window_title = chrome_windows[0].title
            else:
                for url in urls:
                    if '#' in url:
                        subprocess.Popen(['start', '', url], shell=True)
                    else:
                        webbrowser.open(url)
                    time.sleep(0.3)

    def close_search_window(self):
        """
        Closes the active Chrome search window and resets the window tracker
        so the next search opens a fresh window.
        """
        window = self.find_search_window()
        if window:
            window.close()
            self.search_window_title = None
            self.last_search.config(text="Search window closed.")
        else:
            self.last_search.config(text="No search window found.")

    def run_search(self, search_type, urls, text):
        """
        Runs the search in a background thread to keep the UI responsive.

        Args:
            search_type (str): Label for the type of search (e.g. "Financial").
            urls (list): List of URLs to open.
            text (str): The original search text.
        """
        self.root.after(0, self.update_last_search, text, search_type, len(urls))
        self.open_urls(urls)

    def monitor_clipboard(self):
        """
        Runs in a background thread. Checks the clipboard every 0.3 seconds.
        When new text is detected, updates the UI automatically.
        """
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
        """Triggered by Ctrl+Shift+V. Searches financial entity sources."""
        text = self.get_clipboard_text()
        if not text:
            return
        self.update_ui(text, detect_type(text))
        urls = build_urls_financial(text)
        threading.Thread(target=self.run_search, args=("Financial", urls, text), daemon=True).start()

    def on_non_financial(self):
        """Triggered by Ctrl+Shift+B. Searches non-financial entity sources."""
        text = self.get_clipboard_text()
        if not text:
            return
        self.update_ui(text, detect_type(text))
        urls = build_urls_non_financial(text)
        threading.Thread(target=self.run_search, args=("Non-financial", urls, text), daemon=True).start()

    def on_id(self):
        """Triggered by Ctrl+F1. Searches by entity ID (LEI, CIK, or ISIN)."""
        text = self.get_clipboard_text()
        if not text:
            return
        self.update_ui(text, detect_type(text))
        urls = build_urls_id(text)
        threading.Thread(target=self.run_search, args=("By ID", urls, text), daemon=True).start()

    def on_google_ai(self):
        """Triggered by Ctrl+F2. Opens Google AI with a general search and an ID-specific query."""
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
        """
        Registers all global hotkeys and starts the clipboard monitor thread.
        """
        keyboard.add_hotkey('ctrl+shift+v', self.on_financial)
        keyboard.add_hotkey('ctrl+shift+b', self.on_non_financial)
        keyboard.add_hotkey('ctrl+f1', self.on_id)
        keyboard.add_hotkey('ctrl+f2', self.on_google_ai)
        keyboard.add_hotkey('esc', self.root.quit)
        threading.Thread(target=self.monitor_clipboard, daemon=True).start()

    def run(self):
        """Starts the tkinter main event loop."""
        self.root.mainloop()


# ─────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────

if __name__ == "__main__":
    app = EntityValidatorApp()
    app.run()
