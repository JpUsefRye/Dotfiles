# transparency
compton --blur-background &
# notification engine
dunst &
# Media Player Daemon (mpd)
mpd &
# setting the wallpaper
feh --bg-fill ~/Pictures/wallpaper.jpg
# toggle nnatural scrolling
xinput --set-prop "SynPS/2 Synaptics TouchPad" "libinput Natural Scrolling Enabled" 1
# toggle tab to click
xinput set-prop "SynPS/2 Synaptics TouchPad" "libinput Tapping Enabled" 1
# Alt shift to toggle arabic or english
setxkbmap -layout us,ar
setxkbmap -option 'grp:alt_shift_toggle'
