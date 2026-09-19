function font_test -d "Print common characters to test terminal fonts"
	# Clean the characters
	clear

	# Check if xrdb is installed (prevents errors on Wayland or minimal setups)
	if command -sq xrdb
		# Print the URxvt.font in the Xresources databases
		# Improved the parsing to cleanly strip the key and any trailing spaces/tabs
		xrdb -query | awk -F ':[ \t]*' '/URxvt\.font/ {print $2}'
	end
	
	# Line break
	echo ''
	# Hello world!
	echo 'Hello World!'
	# Check the hardest characters to distinguish
	echo 'Iil1 | 0Oo'
	# Print A-Z
	echo 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
	# Print a-z
	echo 'abcdefghijklmnopqrstuvwxyz'
	# Print numbers & some symbols
	echo '1234567890 "`~!@#$%^&*_-=+"'
	# Now symbols with some spaces
	echo '" ` ~ ! @ # $ % ^ & * _ - = + "'
	# Print other punctuations/operators
	echo ', . () <> [] {} \ | ? / : ;'
	# Line break
	echo ''
	# Print common font test text
	echo 'The quick brown fox jumps over the lazy dog.'
	# Line break
	echo ''
	# Other common font test text
	echo 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. In lacinia dui interdum,'
	echo 'dapibus eros vel, posuere turpis. Nulla cursus neque sed dignissim porttitor.'
	echo 'Vestibulum sit amet dolor turpis. Integer bibendum vulputate convallis. Quisque'
	echo 'nulla lacus, aliquam eget libero congue, commodo dignissim neque. Etiam quis felis'
	echo 'erat. Nullam sagittis tempor augue, pharetra fringilla nunc varius vitae. Morbi'
	echo 'condimentum justo finibus feugiat laoreet. Nullam finibus sem semper nunc commodo'
	echo 'hendrerit. Maecenas suscipit magna sit amet augue pharetra, a iaculis nunc sagittis.'
	# Linebreak
	echo ''

	# Powerline characters
	# Just put any argument when launching this script (e.g. `fonttest powerline`)
	if test (count $argv) -gt 0
		echo '           '
		# Linebreak
		echo ''
	end
end
