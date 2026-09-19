function color_blocks -d "Show the terminal colorscheme as blocks"
	# Define ANSI foreground colors
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
	echo -e " $f1██████$d██$t $f2██████$d██$t $f3██████$d██$t $f4██████$d██$t $f5██████$d██$t $f6██████$d██$t "
	echo -e " $f1██████$d██$t $f2██████$d██$t $f3██████$d██$t $f4██████$d██$t $f5██████$d██$t $f6██████$d██$t "
	echo -e " $f1██████$d██$t $f2██████$d██$t $f3██████$d██$t $f4██████$d██$t $f5██████$d██$t $f6██████$d██$t "
	echo -e " $t██████$d$f7██$t $t██████$d$f7██$t $t██████$d$f7██$t $t██████$d$f7██$t $t██████$d$f7██$t $t██████$d$f7██$t "
	echo
end
