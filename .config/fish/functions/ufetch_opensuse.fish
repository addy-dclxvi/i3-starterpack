function ufetch_opensuse -d "A simple screenfetch alternative"
	# 1. System Info
	set -l user_host "$USER@"(hostname)
	set -l distro 'openSUSE Leap 16'
	
	# Use Fish's native string manipulation instead of sed
	set -l kernel_val (uname -sr | string replace -r -- '-.*' '')
	
	# Uptime logic
	set -l awk_cmd '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60); printf "%d days %d hours %d minutes\n", d, h, m}'
	set -l uptime_val (awk $awk_cmd /proc/uptime)
	
	# Package count (Removed --last, sorting packages just to count them slows it down)
	set -l packages (rpm -qa | wc -l | string trim)
	
	# Shell
	set -l shell_val (basename $SHELL)
	
	# 2. Window Manager / Desktop Environment Detection
	set -l envtype
	set -l wm_val
	
	if set -q WM; and test -n "$WM"
		set envtype 'WM'
		set wm_val $WM
	else if set -q XDG_CURRENT_DESKTOP; and test -n "$XDG_CURRENT_DESKTOP"
		set envtype 'DE'
		set wm_val $XDG_CURRENT_DESKTOP
	else if set -q DESKTOP_SESSION; and test -n "$DESKTOP_SESSION"
		set envtype 'DE'
		set wm_val $DESKTOP_SESSION
	else
		set envtype 'WM'
		set wm_val (tail -n 1 ~/.xinitrc 2>/dev/null | cut -d ' ' -f 2)
	end
	
	# 3. Define Colors using Fish's built-in set_color
	set -l accent_color green # default
	
	switch "$argv[1]"
		case --red; set accent_color red
		case --yellow; set accent_color yellow
		case --blue; set accent_color blue
		case --magenta; set accent_color magenta
		case --cyan; set accent_color cyan
		case --green; set accent_color green
	end
	
	set -l reset (set_color normal)
	set -l c0 (set_color -o) # bold
	set -l cbg (set_color -b $accent_color; set_color white; set_color -o) # bg, white text, bold
	set -l c1 (set_color $accent_color)
	
	# 4. Output ASCII Art
	echo
    echo "  $c0$cbg              $reset$c1    USER       $reset$user_host"
	echo "  $c0$cbg      /\\      $reset$c1    DISTRO     $reset$distro"
	echo "  $c0$cbg     /  \\     $reset$c1    KERNEL     $reset$kernel_val"
	echo "  $c0$cbg     \\  /     $reset$c1    UPTIME     $reset$uptime_val"
	echo "  $c0$cbg      \\/      $reset$c1    $envtype         $reset$wm_val"
	echo "  $c0$cbg              $reset$c1    SHELL      $reset$shell_val"
	echo "  $reset$c0              $reset$c1    PACKAGES   $reset$packages"
	echo
end
