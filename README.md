## Introduction
A simple guide (and example of configuration) to install i3 and its and essential packages and make them look eye candy, 
or at least make them not ugly.

Example configuration in this repo is pretty simple, minimal, and easy to be understood, without reducing the usability.
Only contains about 140 lines of i3 configuration, pretty stock without any custom script, custom packages, and custom patch.
This is my daily i3 configuration by the way. 
And this configuration only use packages that available on most Distros main repository.
So You don't need AUR, PPA, xbps-src, or sudo make install. 

I'm using Debian, with i3 stock metapackages (i3wm, i3bar, i3status, i3lock, i3-sensible-terminal, and i3-dmenu-desktop), so does this guide.
Hence I name this repo *i3-starterpack*.
So, the installation guide here will use Debian command & package name. <br />

## Preview
![clean](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/master/preview/clean.png) <br />
**Clean**, without any opened app. Only i3bar is visible. <br />

![rofi](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/master/preview/launcher.png) <br />
**dmenu**, for launching app. The i3-dmenu-desktop version only shows desktop apps. A minimal start menu replacement. <br />

![fullscreen](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/master/preview/monocle.png) <br />
**Fullscreen**, when I write this guide using Vim inside URxvt. When only one window opened, the gaps and borders automatically disappear. <br />

![splitscreen](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/master/preview/split.png) <br />
**Splitscreen**, I open cmus music player on the right. When two windows opened, they will be separated by gaps and borders. <br />

![floating](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/master/preview/floating.png) <br />
**Floating**, for show-off. <br />

![floating](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/master/preview/lockscreen.png) <br />
**Lockscreen**. using i3lock
## Disclaimer
I'm not a Pro. I just started learning Linux a couple yesars ago. And I'm not an IT guy. So, probably this guide will have some mistakes.

## Why i3?
i3 is (arguably) the most easiest tiling window manager to learn and configure. 
And i3 has a really good documentation, including example command and troubleshooting.
The community is also quite large. You will easily get more customization examples.
So, I really recommend You to start from i3 if You want learn Linux customization.
After You can handle i3, You can try more advanced window managers. 
i3 is my first tiling window manager by the way :relaxed: <br />

## Requirements
- At least a working Desktop Environtment or Window Manager (I'm sure You already have it).
Why? Just to make sure already have some essential packages like Xorg, Display Manager, Sound Mixer, Network Manager, etc.
- My recommendation is start from Xfce. It's quite minimal for a Desktop Environtment. And We can use some of its useful components later.
Like file manager, text editor, power manager, clipman, task manager, or maybe its settings daemon.
- Willing to learn, patience, and ability to use Google for fixing problems.
- Not give up easily.
- Some great musics for companion. 
- :coffee: <br />

## Installation
- **First, install i3 of course** <br />
`sudo apt-get install i3` <br />
It will give You i3-wm, dunst, i3lock, i3status, and suckless-tools.
If i3-wm, dunst, i3lock, i3status, and suckless-tools are not installed automatically, just install them manually. <br />
`sudo apt-get install i3-wm dunst i3lock i3status suckless-tools` <br />

- Then install some additional packages to make your desktop enjoyable <br />
`sudo apt-get install hsetroot rxvt-unicode xsel lxappearance scrot`

- I use CMUS Music Player, Ranger File Manager, Vim Text Editor, and Fish Interactive Shell. If you're interested, also install them (optional). I also put my configurations of those apps in this repo. <br />
`sudo apt-get install cmus ranger vim fish` <br />
To activate Fish interative shell `sudo chsh -s /usr/bin/fish addy` (replace addy with your own username). Fish will be available after next login.
I have written an article about Fish interactive shell [here](https://addy-dclxvi.github.io/post/fish-shell/).

## Explanations of Additional Packages
- Hsetroot is a wallpaper handler. i3 has no wallpaper handler by default.
- URxvt is a lightweight terminal emulator, part of *i3-sensible-terminal*.
- Xsel is a program to access X clipboard. We need it to make copy-paste in URxvt available. Hit Alt+C to copy, and Alt+V to paste. 
- LXAppearance is used for changing GTK theme icons, fonts, and some other preferences (Unnecessary if you already have Xfce Settings).
- Scrot is for taking screenshoot. I use it in my configuration for Print Screen button.
I set my Print Screen button to take screenshoot using scrot, then automatically open it any installed image viewer. <br />

## Copying Configurations
`git clone https://github.com/addy-dclxvi/i3-starterpack.git` <br />

Or if You don't have git package installed, and have no willing to install it. 
Just use download as zip button on the top-right of this page, then extract it.
After that, Open *i3-starterpack* folder. Then copy the configurations to your home.
I mean if it's on *i3-starterpack/.config/i3/config*, copy it to *~/.config/i3/*.
If the folder doesn't exist on your home, just make it.
Do the same with all of the files inside *i3-starterpack* folder.
My dotfiles contains font, so refresh your fontconfig cache `fc-cache -fv` after You copy the font. <br />

**Note :** You can deploy this repository recursively using 
`git clone https://github.com/addy-dclxvi/i3-starterpack.git && cp -a i3-starterpack/. ~`
but I recommend You to copy the configuration files one by one to make yourself have more control.

## Inspect and Edit The Configurations Files
- **~/.config/i3/config** <br />
This is the main configuration file of i3 window manager. Contains keybinding, autostart, colors, and window rules.
I suggest You to leave it default for now. I will explain it later. <br />
- **~/.config/i3status/config** <br />
This is the statusline configuration for i3bar, top right part of i3bar. I set it to load many module by default.
It looks like christmast tree. So, I suggest You to disable some module You don't need. <br />
```
order += "load"
order += "cpu_temperature 0"
order += "wireless wlp2s0"
order += "volume master"
order += "battery 0"
order += "time"
```
You can remove or comment out the module You want to disable. <br />
Then now You have to configure the variable. Don't forget to change both in *order* list and in function list. <br />

**Update 2018 July** : And remember, i3status supports Pango Markup. Not many customization options, but still interesting.
Here is my current i3status customization (I remove the lines I don't use instead comment them out). <br />

```
general {
	output_format = "i3bar"
	colors = false
	markup = pango
	interval = 5
}

order += "load"
order += "cpu_temperature 0"
order += "wireless wlp2s0"
order += "volume master"
order += "battery 0"
order += "time"

load {
	format = "<span background='#b08500'>    </span><span background='#bfbaac'>  %5min Load  </span>"
}

cpu_temperature 0 {
	format = "<span background='#d12f2c'>    </span><span background='#bfbaac'>  %degrees °C  </span>"
	path = "/sys/class/thermal/thermal_zone0/temp"
}

wireless wlp2s0 {
	format_up = "<span background='#819400'>    </span><span background='#bfbaac'>  %essid  </span>"
	format_down = "<span background='#819400'>    </span><span background='#bfbaac'>  Disconnected  </span>"
}

volume master {
	format = "<span background='#696ebf'>    </span><span background='#bfbaac'>  %volume  </span>"
	format_muted = "<span background='#696ebf'>    </span><span background='#bfbaac'>  Muted  </span>"
	device = "default"
	mixer = "Master"
	mixer_idx = 0
}

battery 0 {
	last_full_capacity = true
	format = "<span background='#819400'>  %status  </span><span background='#bfbaac'>  %percentage  </span>"
	format_down = "No Battery"
	status_chr = ""
	status_bat = ""
	status_unk = ""
	status_full = ""
	path = "/sys/class/power_supply/BAT%d/uevent"
	low_threshold = 10
	integer_battery_capacity = true
}

time {
	format = "<span background='#2587cc'>    </span><span background='#bfbaac'>  %b %d at %H:%M  </span>"
}
```

## i3status Variables
- My wireless interface is *wlp2s0*, You can find yours by `/sbin/iwconfig` or `iwconfig` or `ip a` command.
- My battery id is *BAT0*, You can find yours by `ls /sys/class/power_supply/` command.
- My volume mixer is Alsa, probably also work for You. If not, You can see the [manual page](https://i3wm.org/docs/i3status.html#_volume) to configure PulseAudio.
- To use CPU temperature, You need your CPU temperature path. 
If `/sys/class/thermal/thermal_zone0/temp` doesn't work try `/sys/devices/platform/coretemp.0/temp1_input`. Still doesn't work? Try `/sys/class/thermal/thermal_zone1/temp`.
- You can add more module, just read the manual page `man i3status`. <br />

## Launching i3
Logout your current session. Then login again with i3 session. <br />

## Some Cheatsheet
My keybind is pretty weird, I'm more focus on easy to memorize,
and essential operations can be handled using left hand only.
So it's easier to use softwares that need mouse like image editor, office suite, and web browser. <br />
- **Super + D** Launch dmenu program launcher (replacement of start menu)
- **Super + Enter** Launch i3-sensible-terminal, URxvt in this case
- **Super + Arrow** Change focused window, if You have two or more windows in the workspace
- **Super + Shift + Arrow** Send focused window to another edge of the screen, if You have two or more windows in the workspace
- **Super + H** and **Super + V** Change split direction to horizontal or vertical
- **Super + S** Change split direction, if You already have splitted windows
- **Super + Space** Float the window, hit it again to back to tiling mode
- **Super + 1-6** Switch to workspace 1-6
- **Super + Shift + 1-6** Send the focused window to workspace 1-6 
- **Super + Control + Left/Right** Switch to previous or next workspace. Only works if You have 2 workspace opened
- **Super + R** Resize mode. In resize mode, hit Arrow keys to do resizing. Hit Enter to back to normal mode
- **Super + C** or **Alt + F4** Close window
- **Super + Q** Quit i3wm
- **Super + L** Lockscreen. To unlock, type your user password then hit Enter
- **Super + Backspace** Fully reload the configuration file. Hit this after do some modifications in the config file
- More keybind look on the configuration file.

## Now What?
Edit the configuration to make it suitable for you, of course. 
Maybe change some keybind, autostart apps, window rules, and more You can find on 
[i3 official documentations](https://i3wm.org/docs/userguide.html).
Also, make yourself getting used with keybinds. It is faster than using mouse.
If you want to change the keybind but don't know the button name,
you can use [xev](https://linux.die.net/man/1/xev). <br />
```
# change volume and brightness
bindsym XF86AudioRaiseVolume exec amixer -q set Master 5%+
bindsym XF86AudioLowerVolume exec amixer -q set Master 5%-
bindsym XF86AudioMute exec amixer set Master toggle
bindsym XF86MonBrightnessUp exec brightnessctl set 5%+
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
```
I use Amixer to change my volume. If it doesn't work for You, change it with Pactl, Pamixer, or anything else.
Just ask Google how to control volume via command line. <br />
```
# common apps keybinds
bindsym Print exec scrot 'Cheese_%a-%d%b%y_%H.%M.png' -e 'xdg-open ~/$f'
bindsym $super+l exec i3lock -i ~/.lock.png
bindsym $super+w exec firefox
bindsym $super+e exec thunar
```
I set keybind to launch my frequently used apps, you can remove what You don't need. 
And add what do You need. **Note:** i3lock need png image <br />
```
# autostart
exec --no-startup-id hsetroot -center ~/.wallpaper.png
```
Maybe You want to add some programs to your autostart, like network manager applet, clipboard manager, power manager, conky, and some goodies.
Probably your network manager applet is nm-applet. So, if want to use it, add `exec --no-startup-id nm-applet &` (exec --no-startup-id means the program will be executed without changing the mouse cursor to circle shape or loading, ampersand means run the command in the background then execute next command without waiting the current command finished).
It will be loaded on next login. I don't put it on my autostart, because usually I only launch it from terminal when I want to switch SSID.
And if You come from Xfce maybe You want use its setting daemon.
Add `exec --no-startup-id xfsettingsd &`.
You will have some Xfce advantage, like mouse settings, appearance settings (LXAppearance will be overiden by this),
font settings, and some other advantage. But it will cost a thing, slightly reduce the performance.
And if the window rendering looks broken, maybe you'll also need to install a compositor like
[compton](https://manpages.debian.org/bookworm/compton/compton.1.en.html) or [picom](https://manpages.debian.org/unstable/picom/picom.1.en.html)
then add it to autostart. With compositor you'll get more advantage like transparancy and window animation. <br />
```
# autostart
exec --no-startup-id hsetroot -center ~/.wallpaper.png
exec --no-startup-id nm-applet &
exec --no-startup-id xfsettingsd &
exec --no-startup-id compton &

```
Next is window rules. i3 has abilities to assign workspace for certain programs, make the window floating by default, make the launched window steals the focus, etc.
```
# window rules, you can find the window class using xprop
for_window [class=".*"] border pixel 4
assign [class=URxvt] 1:I
assign [class=Firefox|Transmission-gtk] 2:II
assign [class=Thunar|File-roller] 3:III
assign [class=Geany|Evince|Gucharmap|Soffice|libreoffice*] 4:IV
assign [class=Audacity|Vlc|mpv|Ghb|Xfburn|Gimp*|Inkscape] 5:V
assign [class=Lxappearance|System-config-printer.py|Lxtask|GParted|Pavucontrol|Exo-helper*|Lxrandr|Arandr] 6:VI
for_window [class=Viewnior|feh|Audacious|File-roller|Lxappearance|Lxtask|Pavucontrol] floating enable
for_window [class=URxvt|Firefox|Geany|Evince|Soffice|libreoffice*|mpv|Ghb|Xfburn|Gimp*|Inkscape|Vlc|Lxappearance|Audacity] focus
for_window [class=Xfburn|GParted|System-config-printer.py|Lxtask|Pavucontrol|Exo-helper*|Lxrandr|Arandr] focus
```
That's my window rules. I use it to group apps on several workspace.
- Workspace 1 for Terminals
- Workspace 2 for Web
- Workspace 3 for File Manager
- Workspace 4 for Office
- Workspace 5 for Multimedia
- Workspace 6 for Settings <br />

And I set some apps to launch in floating mode. You can make your own rules of course.
Maybe my window rules isn't efficient for You. My workspaces are only six, and it's more than enough for me. <br />

**Update 2024 August** Now I no longer use window rules to assign workspace for certains programs.
Now my configuration looks like this.
```
for_window [class=Eog|Sxiv|feh|mpv|Vlc|File-roller|Xarchiver] floating enable
for_window [class=Eog|Sxiv|feh|mpv|Vlc|File-roller|Xarchiver] focus
```

Now let's see the panel coloring
```
# panel
bar {
	status_command i3status
	position top
	workspace_min_width 24
	padding 2px 8px 2px 8px
	strip_workspace_numbers yes

	colors {
	background #141c21
	statusline #141c21
	separator #141c21

	# colour of border, background, and text
	focused_workspace #141c21 #d12f2c #93a1a1
	active_workspace #141c21 #141c21 #93a1a1
	inactive_workspace #141c21 #141c21 #93a1a1
	urgent_workspace #141c21 #b08500 #93a1a1
	}
}  
```
That's my panel colour. I set it has a black background, with white color for workspace name.
Active workspace is highlighted by red colour, and urgent workspace will be highlighted with yellow colour.
If one of your workspaces is highlighted with yellow colour, it means that workspace needs an attention.
You can modify it by yourself of course. <br />
```
# colour of border, background, text, indicator, and child_border
client.focused #d12f2c #263640 #93a1a1 #696ebf #2587cc1
client.focused_inactive #263640 #b08500 #93a1a1 #263640 #263640
client.unfocused #263640 #b08500 #93a1a1 #263640 #263640
client.urgent #263640 #b08500 #93a1a1 #263640 #263640
client.placeholder #263640 #b08500 #93a1a1 #263640 #263640
client.background #263640
```
That's my settings of window border colour. 
I set the focused window border to blue, and unfocused window border to black.
On focused window, the purple border means splitting direction. 
If the purple border is on the right, that means if You launch a new window on that workspace, it will be launched on the right of current focused window.
You can change the splitting direction to bottom using **Super + V**. If You want to split to right again, hit **Super + H**.
If You unsatisfied with it, just modify it :wink: <br />

## That's For Now
I think, this is quite enough for a starter. You can improve it by yourself. <br />
Thanks for reading! :blush:

## Update 1 August 2024

I put some changes to my i3 setup.

- I change the colorscheme
- I change the statusbar
- I cleanup the window rules
- I change some keybinds
- I change the fonts (included in the repo)
- I change the default apps
- And others. Please read the config before use.

I also made a light theme and put it in [this](https://github.com/addy-dclxvi/i3-starterpack/tree/leaf) branch.

### Preview
![clean](https://github.com/addy-dclxvi/i3-starterpack/blob/leaf/screenshots/clean.png) </br>
**Clean** Without any window opened

![floating](https://github.com/addy-dclxvi/i3-starterpack/blob/leaf/screenshots/floating.png) </br>
**Floating** Opening *Vim, Cmus, and Ranger* in floating mode for show off. The bottom line is *i3-dmenu-desktop*.

![tiling-two](https://github.com/addy-dclxvi/i3-starterpack/blob/leaf/screenshots/tiling-two.png) </br>
**Tiling** With two windows opened

![tiling-three](https://github.com/addy-dclxvi/i3-starterpack/blob/leaf/screenshots/tiling-three.png) </br>
**Tiling** With three windows opened

![gimp](https://github.com/addy-dclxvi/i3-starterpack/blob/leaf/screenshots/gimp.png) </br>
![monocle](https://github.com/addy-dclxvi/i3-starterpack/blob/leaf/screenshots/monocle.png) </br>
**Monocle** One windows opened, the gaps and borders are automatically disappeared, so no space wasted

![fullscreen](https://github.com/addy-dclxvi/i3-starterpack/blob/leaf/screenshots/fullscreen.png) </br>
**Fullscreen** Using *Super + F*. The gaps, borders, and statusbar disappeared for maximum reading experience

![dunst](https://github.com/addy-dclxvi/i3-starterpack/blob/leaf/screenshots/dunst.png) </br>
Dunst notification daemon, slightly misplaced to the right.
I tried to change the coordinate from the config file but it's no longer working.
They said it's depreciated.

![lockscreen](https://github.com/addy-dclxvi/i3-starterpack/blob/leaf/screenshots/lockscreen.png) </br>
**Lockscreen** using i3lock

**Note** I make my terminal background has lines by using [~/.pixmap.png](https://github.com/addy-dclxvi/i3-starterpack/blob/update-24.08/.pixmap.png)
as tiled terminal background image. Declared in [~/.Xresources](https://github.com/addy-dclxvi/i3-starterpack/blob/4463f9b38a965c6f240ad970fb464b5815e822f7/.Xresources#L4).
If your want to use it, replace addy in line number four with your own username.

## Update 22 August 2024
I try my config in openSUSE (VM) and the statusline looks broken.
The markup of time is not processed. The solution is to use **tztime** format instead of **time**

<video src="https://github.com/user-attachments/assets/ee55d4ff-74ca-4f2e-9429-be7aee706562"></video>

(In the video I also disable battery, temperature, and wifi since it's a VM).

In the **order** zone :
```
order += "tztime local"
```

In the function zone :
```
tztime local {
	format = "<span background='#289c93'>    </span><span background='#bfbaac'>  %time  </span>"
	format_time = "%b %d at %H:%M"
}
```
## Update 29 August 2024
Doing minimal install is getting harder, I have problems with Network Manager on Debian Bookworm.
On previouses Debian versions, I only need to install proprietary Atheros driver
then my wifi card will be automatically managed by Network Manager.
I only need to open **nmtui** to connect to my wifi.
But now, my wifi card won't appear in **nmtui**.
When I try Debian Bookwork Gnome Live CD, the wifi working out of the box.
It seems that on minimal install, Network Manager needs to be configured manually.
Other than network manager, I also have other issues.
And too lazy to solve them all,
so now I use ISO file with complete desktop environment instead of DE-less ISO like usual.

And for ISO with complete desktop environtment,
I prefer Fedora or openSUSE than Debian because they have better package selection.
Debian put too many unimportant softwares on default Gnome or KDE install.

Now, I use openSUSE default install (KDE) then install some packages I need.

```
sudo zypper install i3 rxvt-unicode xsel ranger cmus hsetroot caca-utils git highlight fish brightnessctl
sudo zypper install opi && sudo opi codecs
sudo chsh -s /usr/bin/fish addy
git clone https://github.com/addy-dclxvi/i3-starterpack
cd i3-starterpack
git checkout aeroplane
cp -a . ~
```

### Preview
My current openSUSE setup. I put it in [aeroplane](https://github.com/addy-dclxvi/i3-starterpack/tree/aeroplane) branch.
Of course it's also work on other distros. The only differences are
- Aliases in the fish config, replacing commands related with APT with Zypper
- Shortcut of common apps in i3 config, I utilize apps that come with KDE. Like **Super+E** now open Dolphin.
- Autostart in i3 config too, I utilize apps that come with KDE. Like KDE keyring and KDE Polkit. I don't autostart KDE power manager because I cannot wake my laptop after entering sleep mode.

![ufetch](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/aeroplane/preview/ufetch.png)

![ranger](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/aeroplane/preview/ranger.png)

![gimp](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/aeroplane/preview/gimp.png)

![vim](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/aeroplane/preview/vim.png)

![cmus](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/aeroplane/preview/cmus.png)

![lock](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/aeroplane/preview/lock.png)
