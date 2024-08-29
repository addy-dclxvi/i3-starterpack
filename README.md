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
```

### Preview
My current openSUSE setup. I put it in this branch.
Of course it's also work on other distros. The only differences are
- Aliases in the fish config, replacing commands related with APT with Zypper
- Shortcut of common apps in i3 config, I utilize apps that come with KDE. Like **Super+E** now open Dolphin.
- Autostart in i3 config too, I utilize apps that come with KDE. Like KDE keyring and KDE Polkit. I don't autostart KDE power manager because I cannot wake my laptop after entering sleep mode.

![ufetch](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/aeroplane/preview/ufetch.png)

![ranger](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/aeroplane/preview/ranger.png)

![gimp](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/aeroplane/preview/gimp.png)

![vim](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/aeroplane/preview/vim.png)

![cmus](https://raw.githubusercontent.com/addy-dclxvi/i3-starterpack/aeroplane/preview/cmus.png)
