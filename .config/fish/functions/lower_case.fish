function lower_case -d "Convert every word in a file to lowercase"
	# Assign the first argument to a local variable for readability
	set -l target_file $argv[1]

	if test -z "$target_file"
		echo (set_color red)"Need a file after "(set_color normal)"lowercase "(set_color red)"command"(set_color normal)
	else
		if test -e "$target_file"
			sed -e 's/\(.*\)/\L\1/' $target_file > "$target_file-lowercase"
			sed -e 's/cursorcolor/cursorColor/g' "$target_file-lowercase" > "$target_file-lowercase2"
			
			mv $target_file "$target_file-old"
			mv "$target_file-lowercase2" $target_file
			rm "$target_file-lowercase"
			
			echo (set_color green)"Done "(set_color normal)
			echo (set_color green)"Original file stored as "(set_color normal)"$target_file-old"
		else
			echo (set_color yellow)"File not found "(set_color normal)
		end
	end
end
