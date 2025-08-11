# CNV Analýza 

Aplikace v **R Shiny** pro zpracování pokrytí genů z panelového sekvenování (výstupů z CLC).  
Umožňuje:

- Sloučit pokrytí všech vzorků do jednoho přehledného souboru (coverage.csv)
- Detekovat možné CNV abnormality odděleně pro muže a ženy
- Anotovat podezřelé geny pomocí databáze **OMIM**

---

## Výstupy

Aplikace generuje tři CSV soubory:

| Soubor       | Popis |
|--------------|-------|
| coverage.csv | Pokrytí všech vzorků – sloupce Chromosome, Region, Name + 1 sloupec na vzorek |
| CNV_M.csv    | Geny s extrémní hodnotou pokrytí u mužů + anotace z OMIM |
| CNV_Z.csv    | Geny s extrémní hodnotou pokrytí u žen + anotace z OMIM |

---

## Instalace

### Požadavky
- **R** verze 4.3 nebo novější
- (doporučeno) **RStudio**
- R balíčky:

    install.packages(c("shiny", "bslib", "magrittr"))

### Struktura projektu
Složka cnv_analyza obsahuje:
- app.R – hlavní skript aplikace
- helpers.R – pomocné funkce
- soubor s OMIM geny

---

## Spuštění

### 1. Spuštění přes ikonu na ploše
Na Windows přes launch_app.bat - změnit cestu k R systému.
Na Linuxu přes launch.sh - změnit cestu k R skriptu.

### 2. Spuštění v R Studiu

    setwd("D:/cnv_analyza/app") # nastavit pracovní adresář
    shiny::runApp()

---

## Použití

### 1. Nahraj vstupní soubory
- Klikni na „Vybrat soubory“ v levém panelu
- Vyber jeden nebo více souborů (např. dNS1308vT_cov.txt)
- Po nahrání se zobrazí modrý pruh „Upload complete“ a počet souborů

### 2. Zadej pohlaví vzorků
- U každého souboru vyber z rozbalovacího seznamu „Muž“ nebo „Žena“

### 3. Klikni na zelené tlačítko „Zpracovat“
- Spustí se výpočet normalizovaného pokrytí
- Vygeneruje se coverage.csv a CNV tabulky s OMIM anotacemi
- Zpracování může trvat déle podle počtu vzorků

### 4. Stáhni výsledky
- V levém panelu klikni na Coverage, CNV M nebo CNV Z pro stažení výsledků

