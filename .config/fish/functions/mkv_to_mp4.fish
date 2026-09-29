function mkv_to_mp4 -d "Convert video to mp4 using ffmpeg"
	set -l target_file $argv[1]

	if test -z "$target_file"
		echo (set_color red)"Need a file after "(set_color normal)"tomp4 "(set_color red)"command"(set_color normal)
	else if not test -e "$target_file"
		echo (set_color yellow)"File not found "(set_color normal)
	else
		# Strip the last extension to create the new filename
		set -l base_name (string replace -r '\.[^.]+$' '' "$target_file")
		set -l output_file "$base_name.mp4"

		ffmpeg -i "$target_file" \
			-f mp4 \
			-c:v libx264 \
			-preset fast \
			-profile:v main \
			-c:a aac \
			-hide_banner \
			"$output_file"

		# Check if ffmpeg succeeded before printing success message
		if test $status -eq 0
			echo (set_color green)"Done"(set_color normal)
			echo (set_color green)"The result stored as "(set_color normal)"$output_file"
		else
			echo (set_color red)"Conversion failed!"(set_color normal)
		end
	end
end
