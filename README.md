# i3-yosemite
My i3 setup's called Yosemite
## Preview
![alt text](https://raw.githubusercontent.com/addy-dclxvi/i3-yosemite/master/preview.png)
## Getting Started
Install these required packages from AUR, You know to install packages from AUR don't You? :)
 ```
i3-gaps powerline-i3-git siji-git feh terminus-font-ttf powerline-fonts-git ttf-font-awesome
```
And optional packages, if you need. Some of these packages are available in repo, and the rest are available in AUR.
 ```
compton mpd mpc ncmpcpp mpdviz bash-pipes neofetch
```
## Installation
If You have a previous i3 config, move it to a safe-place. literally :D
```
mkdir ~/.config/safe-place
```
```
mv -r ~/.config/i3 ~/.config/safe-place
```
Then clone this setup
```
git clone https://github.com/addy-dclxvi/i3-yosemite
```
Move my config to ~/.config folder 
```
mv -r i3-yosemite ~/.config
```
Rename the directory
```
mv ~/.config/i3-yosemite  ~/.config/i3
```
Then logout from your current session
```
kill -9 -1
```
Then login with i3 session
## Based On
[Steal this config](https://www.reddit.com/r/unixporn/comments/5dbn8s/i3gaps_steal_this_config/)
## What If..
Q : What if my lemonbar doesn't want to be appeared?
<br />
A :
```
kill lemonbar
```
Then logout and login your session again.
<br />
<br />
Q : I want to make my ncmpcpp like yours, where I can get it?
<br />
A : I get that sweet config from [Mazhar](https://github.com/m47h4r/dot_files)
<br />
<br />
Q : I can't get my workspaces appeared on the lemonbar
<br />
A : Ohh, me too. I have spent days to figure out why the heck my workspaces won't be appeared, but still no result >_<
<br />
<br />
Q : My usual keybind doesn't work here
<br />
A : I have a weird keybinds to make everything work more efficient for me, You should read the config file. Not only copy and paste. And don't forget to comment out every startup lines that You don't need.
<br />
<br />
Q : How to make my mpdviz like yours?
<br />
A :
```
mpdviz -i -v spectrum
```
Q : Very good readme instruction!! But can You make it more simple??
<br />
A : Thank You!! Yes, The core instruction is only, download my config from github then place it to your i3 config folder. Just that!


## License
Feel free to modify and share this setup
## My Links
[Google+](https://plus.google.com/+AdhiPambudi)
[Deviant Art](http://addy-dclxvi.deviantart.com/)

