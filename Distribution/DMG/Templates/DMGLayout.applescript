on run arguments
    set volumeName to item 1 of arguments
    set backgroundName to item 2 of arguments

    tell application "Finder"
        tell disk volumeName
            open
            set backgroundFile to file (".background:" & backgroundName)

            tell container window
                set current view to icon view
                set toolbar visible to false
                set statusbar visible to false
                set pathbar visible to false
                set sidebar width to 0
                set bounds to {120, 120, 780, 540}
            end tell

            tell icon view options of container window
                set arrangement to not arranged
                set icon size to 104
                set text size to 13
                set background picture to backgroundFile
            end tell

            set position of item "BookmarkBridge.app" to {180, 280}
            set position of item "Applications" to {480, 280}

            update without registering applications
            delay 2
            close
            open
            delay 2
            update without registering applications
        end tell
    end tell
end run
