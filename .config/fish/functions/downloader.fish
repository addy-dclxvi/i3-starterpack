function downloader -d "Download video or audio from YouTube using yt-dlp"
	set -l url $argv[1]

	# Check if a URL was provided
	if test -z "$url"
		echo (set_color red)"Error: Please provide a YouTube URL."(set_color normal)
		echo "Usage: downloader <video_url>"
		return 1
	end

	# Ensure yt-dlp is installed
	if not command -sq yt-dlp
		echo (set_color red)"Error: yt-dlp is not installed."(set_color normal)
		echo "Please install it (e.g., sudo apt install yt-dlp, brew install yt-dlp, or pip install yt-dlp)."
		return 1
	end

	# Display available formats
	echo (set_color blue)"Fetching available formats..."(set_color normal)
	yt-dlp -F "$url"

	if test $status -ne 0
		echo (set_color red)"Failed to fetch formats. Please check the URL."(set_color normal)
		return 1
	end

	echo ""
	echo (set_color yellow)"Enter the format code number(s) you want to download (e.g., 22, 137+140, or 'best')."(set_color normal)
	echo (set_color yellow)"Type 'mp3' to automatically extract the best audio to MP3."(set_color normal)
	
	# Prompt the user for input
	read -l -P "Format code: " format_code

	if test -z "$format_code"
		echo (set_color red)"No format entered. Aborting."(set_color normal)
		return 1
	end

	echo (set_color green)"Starting download..."(set_color normal)

	if test "$format_code" = "mp3"
		# MP3 audio extraction command (modernized for yt-dlp)
		yt-dlp "$url" \
			--embed-metadata \
			--extract-audio --audio-format mp3 --audio-quality 0 \
			--ignore-errors --restrict-filenames \
			-o "%(title)s.%(ext)s"
	else
		# Standard video/audio download based on the user's chosen code
		yt-dlp "$url" \
			-f "$format_code" \
			--embed-metadata \
			--ignore-errors --restrict-filenames \
			-o "%(title)s.%(ext)s"
	end

	if test $status -eq 0
		echo (set_color green)"Done! Download stored in the current directory."(set_color normal)
	else
		echo (set_color red)"Download completed with some errors, or failed."(set_color normal)
	end
end
