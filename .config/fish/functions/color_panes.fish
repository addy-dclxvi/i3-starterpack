function color_panes -d "Display a color palette panes"
	# Define ANSI foreground colors
	set -l f0 "\e[30m" # Black
	set -l f1 "\e[31m" # Red
	set -l f2 "\e[32m" # Green
	set -l f3 "\e[33m" # Yellow
	set -l f4 "\e[34m" # Blue
	set -l f5 "\e[35m" # Magenta
	set -l f6 "\e[36m" # Cyan
	set -l f7 "\e[37m" # White

	set -l d "\e[1m"   # Bold (creates the bright/shadow effect)
	set -l t "\e[0m"   # Reset

	echo
	echo -e " $f0████$d▄$t  $f1████$d▄$t  $f2████$d▄$t  $f3████$d▄$t  $f4████$d▄$t  $f5████$d▄$t  $f6████$d▄$t  $f7████$d▄$t  "
	echo -e " $f0████$d█$t  $f1████$d█$t  $f2████$d█$t  $f3████$d█$t  $f4████$d█$t  $f5████$d█$t  $f6████$d█$t  $f7████$d█$t  "
	echo -e " $f0████$d█$t  $f1████$d█$t  $f2████$d█$t  $f3████$d█$t  $f4████$d█$t  $f5████$d█$t  $f6████$d█$t  $f7████$d█$t  "
	echo -e " $d$f0 ▀▀▀▀$t  $d$f1 ▀▀▀▀$t  $d$f2 ▀▀▀▀$t  $d$f3 ▀▀▀▀$t  $d$f4 ▀▀▀▀$t  $d$f5 ▀▀▀▀$t  $d$f6 ▀▀▀▀$t  $d$f7 ▀▀▀▀$t  "
	echo
end
