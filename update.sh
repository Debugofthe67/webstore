#!/bin/bash

# Exit instantly if a critical command fails
set -e

echo "=== 1. Creating Target Directories ==="
mkdir -p apps manifest version
echo "Folders created: /apps, /manifest, /version"
echo ""

echo "=== 2. Add Your IPA Files ==="
read -p "Please drag/drop or add your .ipa files into the 'apps' folder now. Press [ENTER] when you are completely done..."
echo ""

echo "=== 3. Configuration Setup ==="
read -p "Enter your site domain (e.g., iosapps.litten.ca or localhost): " DOMAIN
# Strip any trailing slashes or protocols if entered by mistake
DOMAIN=$(echo "$DOMAIN" | sed -e 's|^https://||' -e 's|^http://||' -e 's|/$||')
echo "Using Domain: https://$DOMAIN"
echo ""

echo "=== 4. Managing Systems & Dependencies ==="
# Adding standard universal universe repo repository and installing plist conversion tools
if [ -f /etc/debian_version ]; then
    echo "Updating system registries and acquiring libplist-utils..."
    sudo apt-get update -y
    sudo apt-get install -y libplist-utils unzip
elif [ -f /etc/arch-release ]; then
    sudo pacman -Sy --noconfirm libplist unzip
else
    echo "Notice: Non-Debian/Arch environment detected. Ensuring 'unzip' and 'plistutil' are present locally..."
fi
echo ""

# Temporary file mapping associative keys to bundle IDs to track duplicates
cat /dev/null > .app_tracking.txt

echo "=== 5. Reading IPAs & Compiling Plists ==="
for ipa in apps/*.ipa; do
    # Verify files exist inside the directory target
    [ -e "$ipa" ] || continue
    
    ipaname=$(basename "$ipa")
    # Clean the name to create a safe slug for plist/html naming conversions
    cleanname=$(echo "$ipaname" | sed 's/\.ipa$//' | tr -cd 'A-Za-z0-9_-')

    echo "Reading contents of: $ipaname..."

    # Extract binary Info.plist to standard out stream using unzip -p, and pass to plistutil to make JSON
    # This matches the internal Payload/*.app/Info.plist path structure inside an IPA
    raw_json=$(unzip -p "$ipa" "Payload/*.app/Info.plist" | plistutil -f json -i - 2>/dev/null || true)

    if [ -z "$raw_json" ]; then
        echo "❌ Error: Could not read Info.plist from $ipaname. Skipping..."
        continue
    fi

    # Read target tracking properties using clean grep string operations
    bundleid=$(echo "$raw_json" | grep -o '"CFBundleIdentifier": *"[^"]*"' | head -n 1 | cut -d'"' -f4)
    version=$(echo "$raw_json" | grep -o '"CFBundleShortVersionString": *"[^"]*"' | head -n 1 | cut -d'"' -f4)
    appname=$(echo "$raw_json" | grep -o '"CFBundleDisplayName": *"[^"]*"' | head -n 1 | cut -d'"' -f4)

    # Fallback to general Bundle Name if Display Name is completely blank inside the binary
    if [ -z "$appname" ]; then
        appname=$(echo "$raw_json" | grep -o '"CFBundleName": *"[^"]*"' | head -n 1 | cut -d'"' -f4)
    fi
    if [ -z "$appname" ]; then appname="$cleanname"; fi
    if [ -z "$version" ]; then version="1.0"; fi

    echo "Found Asset: $appname (ID: $bundleid | Version: $version)"

    # Generate the over-the-air Apple Manifest plist profile configuration
    cat <<EOF > "manifest/${cleanname}.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://apple.com">
<plist version="1.0">
<dict>
    <key>items</key>
    <array>
        <dict>
            <key>assets</key>
            <array>
                <dict>
                    <key>kind</key>
                    <key>url</key>
                    <string>https://${DOMAIN}/apps/${ipaname}</string>
                </dict>
            </array>
            <key>metadata</key>
            <dict>
                <key>bundle-identifier</key>
                <string>${bundleid}</string>
                <key>bundle-version</key>
                <string>${version}</string>
                <key>kind</key>
                <string>software</string>
                <key>title</key>
                <string>${appname}</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF

    # Track compiled app references to catch multi-version variants later
    echo -e "$bundleid\t$appname\t$version\t$cleanname\t$ipaname" >> .app_tracking.txt
done

echo ""
echo "=== 6. Assembling Index & Version Cards ==="

# Initialize the main static master catalog file (iOS 6 Skeuomorphic Style)
cat <<EOF > index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>WebStore</title>
    <!-- Standalone Web App Meta Triggers -->
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black">
<meta name="apple-mobile-web-app-title" content="WebStore">

<!-- Home Screen Shortcuts & Web Clips (Legacy iOS 3-6 Compatibility) -->
<link rel="apple-touch-icon" href="icon.png">
<link rel="apple-touch-icon-precomposed" href="icon.png">

<!-- Desktop Web Browser Tab Icons -->
<link rel="icon" type="image/png" href="icon.png">

    <style>
        /* Classic iOS 6 Gray Linen Background Texture */
        body {
            background-color: #cbd5e1;
            background-image: radial-gradient(#94a3b8 1px, transparent 0);
            background-size: 8px 8px;
            margin: 0;
            padding: 0;
            font-family: Helvetica, Arial, sans-serif;
            -webkit-user-select: none;
        }
        /* Top Navigation Header Bar */
        .ios-navbar {
            background: linear-gradient(to bottom, #7aa1d2 0%, #4672aa 50%, #294f83 51%, #355f97 100%);
            border-bottom: 1px solid #1a3458;
            box-shadow: 0 1px 3px rgba(0,0,0,0.3);
            color: #fff;
            font-size: 20px;
            font-weight: bold;
            text-align: center;
            line-height: 44px;
            height: 44px;
            text-shadow: 0 -1px 0 rgba(0,0,0,0.6);
        }
        /* iOS 6 List Wrapper Group Container */
        .ios-list {
            margin: 15px;
            background-color: #ffffff;
            border: 1px solid #ababab;
            border-radius: 10px;
            padding: 0;
            list-style: none;
            overflow: hidden;
        }
        /* Row Items */
        .ios-item {
            border-bottom: 1px solid #ababab;
            padding: 12px 15px;
            display: block;
            clear: both;
            position: relative;
            background: #fff;
        }
        .ios-item:last-child {
            border-bottom: none;
        }
        /* Text Columns */
        .app-meta {
            float: left;
            max-width: 65%;
        }
        .app-title {
            font-size: 16px;
            font-weight: bold;
            color: #000;
            margin: 0 0 3px 0;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .app-sub {
            font-size: 13px;
            color: #666;
            margin: 0;
        }
        .app-warning {
            font-size: 12px;
            color: #b45309;
            font-weight: bold;
            margin: 3px 0 0 0;
        }
        /* Blue iOS App Store Style Installation Button */
        .ios-btn {
            float: right;
            display: inline-block;
            background: linear-gradient(to bottom, #5ba3eb 0%, #1573db 50%, #005bca 51%, #0060cc 100%);
            border: 1px solid #084999;
            border-radius: 5px;
            color: #fff;
            font-size: 13px;
            font-weight: bold;
            padding: 6px 14px;
            text-decoration: none;
            text-align: center;
            box-shadow: inset 0 1px 0 rgba(255,255,255,0.4), 0 1px 1px rgba(0,0,0,0.2);
            text-shadow: 0 -1px 0 rgba(0,0,0,0.4);
            margin-top: 2px;
        }
        .ios-btn-alt {
            background: linear-gradient(to bottom, #9ca3af 0%, #4b5563 100%);
            border: 1px solid #374151;
        }
        /* Clearfix utility helper for ancient browsers */
        .clear { clear: both; }
    </style>
</head>
<body>
    <div class="ios-navbar">WebStore</div>
    <ul class="ios-list">
EOF

# Process individual unique bundles to group versions together
awk -F'\t' '{print $1}' .app_tracking.txt | sort -u | while read -r unique_id; do
    # Count how many versions exist for this bundle ID
    version_count=$(grep -c "^$unique_id" .app_tracking.txt)
    
    # Grab the common metadata from the first entry
    first_entry=$(grep "^$unique_id" .app_tracking.txt | head -n 1)
    display_title=$(echo "$first_entry" | cut -f2)
    latest_ver=$(echo "$first_entry" | cut -f3)
    safe_slug=$(echo "$first_entry" | cut -f4)

    if [ "$version_count" -gt 1 ]; then
        # MULTIPLE VERSIONS -> Route to a sub-page in /version
        html_filename="version/${safe_slug}.html"
        
        # Add a redirection link card to the main index.html file
        cat <<EOF >> index.html
        <li class="ios-item">
            <div class="app-meta">
                <div class="app-title">${display_title}</div>
                <div class="app-warning">⚠️ ${version_count} Versions Available</div>
            </div>
            <a href="version/${safe_slug}.html" class="ios-btn ios-btn-alt">View</a>
            <div class="clear"></div>
        </li>
EOF

        # Generate the specific child view version.html page layout (iOS 6 Compatible)
        cat <<EOF > "$html_filename"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>${display_title}</title>
    <style>
        body { background-color: #cbd5e1; background-image: radial-gradient(#94a3b8 1px, transparent 0); background-size: 8px 8px; margin: 0; padding: 0; font-family: Helvetica, Arial, sans-serif; }
        .ios-navbar { background: linear-gradient(to bottom, #7aa1d2 0%, #4672aa 50%, #294f83 51%, #355f97 100%); border-bottom: 1px solid #1a3458; color: #fff; font-size: 18px; font-weight: bold; text-align: center; line-height: 44px; height: 44px; text-shadow: 0 -1px 0 rgba(0,0,0,0.6); position: relative; }
        .back-btn { position: absolute; left: 10px; top: 8px; height: 28px; line-height: 26px; padding: 0 10px; background: rgba(0,0,0,0.2); border: 1px solid rgba(0,0,0,0.3); border-radius: 4px; color: #fff; font-size: 12px; text-decoration: none; font-weight: bold; }
        .ios-list { margin: 15px; background-color: #ffffff; border: 1px solid #ababab; border-radius: 10px; padding: 0; list-style: none; overflow: hidden; }
        .ios-item { border-bottom: 1px solid #ababab; padding: 12px 15px; display: block; clear: both; background: #fff; }
        .ios-item:last-child { border-bottom: none; }
        .app-meta { float: left; }
        .app-title { font-size: 16px; font-weight: bold; color: #000; }
        .ios-btn { float: right; display: inline-block; background: linear-gradient(to bottom, #5ba3eb 0%, #1573db 50%, #005bca 51%, #0060cc 100%); border: 1px solid #084999; border-radius: 5px; color: #fff; font-size: 13px; font-weight: bold; padding: 6px 14px; text-decoration: none; }
        .clear { clear: both; }
    </style>
</head>
<body>
    <div class="ios-navbar">
        <a href="../index.html" class="back-btn">Back</a>
        Versions
    </div>
    <ul class="ios-list">
EOF

        # Append each individual card variant inside the sub-page
        grep "^$unique_id" .app_tracking.txt | while read -r line; do
            v_ver=$(echo "$line" | cut -f3)
            v_slug=$(echo "$line" | cut -f4)
            
            cat <<EOF >> "$html_filename"
        <li class="ios-item">
            <div class="app-meta">
                <div class="app-title">Version ${v_ver}</div>
            </div>
            <a href="itms-services://?action=download-manifest&url=https://${DOMAIN}/manifest/${v_slug}.plist" class="ios-btn">Install</a>
            <div class="clear"></div>
        </li>
EOF
        done

        # Close out the file layout template tags cleanly
        cat <<EOF >> "$html_filename"
    </ul>
</body>
</html>
EOF

    else
        # SINGLE VERSION -> Inject simple wireless distribution element card into core dashboard index
        cat <<EOF >> index.html
        <li class="ios-item">
            <div class="app-meta">
                <div class="app-title">${display_title}</div>
                <div class="app-sub">Version: ${latest_ver}</div>
            </div>
            <a href="itms-services://?action=download-manifest&url=https://${DOMAIN}/manifest/${safe_slug}.plist" class="ios-btn">Install</a>
            <div class="clear"></div>
        </li>
EOF
    fi
done

# Close the index template structure
cat <<EOF >> index.html
    </ul>
</body>
</html>
EOF

# Clean up tracking temporary file cache
rm -f .app_tracking.txt

echo "✅ Done! Fixed iOS 6 skeuomorphic pages generated successfully."