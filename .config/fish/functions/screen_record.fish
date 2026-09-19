function screen_record -d "Record screen and internal audio using ffmpeg"
	# Ensure the Videos directory exists
	mkdir -p ~/Videos

	# Set the timestamp for the filename
	set -l current_time (date +"%y.%m.%d_%H-%M-%S")

	# Automatically detect screen resolution using xdpyinfo or xrandr
	set -l screen_res ""
	if command -sq xdpyinfo
		set screen_res (xdpyinfo | awk '/dimensions/ {print $2}')
	else if command -sq xrandr
		set screen_res (xrandr | awk '/\*/ {print $1}' | head -n 1)
	end

	# Fallback in case both commands fail or are missing
	if test -z "$screen_res"
		set screen_res "1366x768"
	end

	# Detect the audio server to capture internal desktop audio
	set -l audio_args
	
	# PipeWire and PulseAudio share the same pactl interface
	if command -sq pactl
		# Grab the name of the current default output (speakers/headphones)
		set -l default_sink (pactl get-default-sink)
		
		if test -n "$default_sink"
			# Append .monitor to record the output audio instead of the microphone
			set audio_args -f pulse -i "$default_sink.monitor"
		else
			set audio_args -f pulse -i default
		end
	else
		# Fallback to ALSA if PulseAudio/PipeWire tools are missing
		set audio_args -f alsa -i default
	end

	# Start ffmpeg recording
	ffmpeg \
		-f x11grab \
		-video_size $screen_res \
		-i :0.0 \
		$audio_args \
		-c:v libvpx \
		-b:v 5M \
		-crf 10 \
		-quality realtime \
		-c:a aac \
		-b:a 192k \
		-y ~/Videos/Action_$current_time.mkv
end
