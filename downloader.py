import os
import re
import urllib.request
from bs4 import BeautifulSoup

# The exact target archive link from your screenshot
TARGET_URL = "https://archive.org/download/legacyiosapparchive/"
SAVE_DIR = "./apps"

# Ensure the output folder exists locally
if not os.path.exists(SAVE_DIR):
    os.makedirs(SAVE_DIR)
    print(f"Created directory: {SAVE_DIR}")

print("=== 1. Reading Target Apache Directory ===")
try:
    # Mimic a standard browser header to avoid archive.org bot blocks
    req = urllib.request.Request(
        TARGET_URL, 
        headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
    )
    with urllib.request.urlopen(req) as response:
        html_content = response.read().decode('utf-8')
except Exception as e:
    print(f"❌ Error connecting to the server: {e}")
    exit(1)

print("=== 2. Parsing Extracted Links ===")
soup = BeautifulSoup(html_content, 'html.parser')
links = soup.find_all('a')

# Filter exclusively for real file pathways ending with .ipa
ipa_files = []
for link in links:
    href = link.get('href')
    if href and href.lower().endswith('.ipa'):
        # Ignore upper level directory jumps
        if "Parent Directory" in link.text or "Name" in link.text:
            continue
        ipa_files.append(href)

total_count = len(ipa_files)
print(f"Found {total_count} matching application packages (.ipa) to grab.")

print("\n=== 3. Beginning Sequential File Download Pipeline ===")
for index, file_name in enumerate(ipa_files, 1):
    # Decode special characters like %20 from the URL back into clean spacing
    clean_filename = urllib.parse.unquote(file_name)
    download_url = TARGET_URL + file_name
    save_path = os.path.join(SAVE_DIR, clean_filename)
    
    print(f"[{index}/{total_count}] Fetching: {clean_filename} ...")
    
    try:
        # Stream download directly into our local apps repository folder
        urllib.request.urlretrieve(download_url, save_path)
    except KeyboardInterrupt:
        print("\nProcess stopped by user.")
        exit(0)
    except Exception as e:
        print(f"  ❌ Failed to download {clean_filename}. Error: {e}")

print("\n✅ Execution Finished! All available packages have been fetched locally.")
