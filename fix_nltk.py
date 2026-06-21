"""
Fix corrupted NLTK data by re-downloading only the needed packages
"""
import nltk
import os

print("Re-downloading NLTK data packages...")
print("This will skip existing files if they're in use.")
print()

downloads = [
    'stopwords',
    'wordnet',
    'omw-1.4',
    'punkt'
]

for item in downloads:
    print(f"Downloading {item}...")
    try:
        nltk.download(item, quiet=True, force=True)
        print(f"  [OK] {item} downloaded")
    except Exception as e:
        print(f"  [ERROR] {item}: {e}")

print()
print("NLTK data download complete!")
print("If errors persist, please close all Python processes and run this script again.")
