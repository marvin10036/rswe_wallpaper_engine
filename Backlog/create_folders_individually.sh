#!/bin/bash

CURRENT_FILE=$1
# CURRENT_FILE_FILENAME="${CURRENT_FILE##*/}" # Thanks gpt. Removing everything to the left of the last '/'
CURRENT_FILE_FILENAME="$(echo "$CURRENT_FILE" | awk -F/ 'print{$NF}')"
VIDEO_FRAMES_FOLDER="$HOME/Imagens/Wallpapers/Video_Wallpapers/"

# ???? Removes the last 4 characters from the string
New_folder="${VIDEO_FRAMES_FOLDER}${CURRENT_FILE_FILENAME%????}_frames/"

# If the new folder doesn't exist
if [[ ! -d $New_folder ]]; then

	mkdir $New_folder
	# -fps_mode is there because ffmpeg tends to generate extra frames to preserve some
	# frame timing stuff, I'm disabling it.
	ffmpeg -i $CURRENT_FILE -fps_mode passthrough ${New_folder}/frame%08d.png

	File_extension=${CURRENT_FILE_FILENAME: -3}
	if [[ "$File_extension" == "gif" ]] then
		# %T\n returns that frame delay, or the time it stays on screen on 
		# 10 x milliseconds (a hundreth of a second) (Thanks gpt)
		Frame_durations_array=($(identify -format "%T\n" $CURRENT_FILE))

		for Frame_delay in ${Frame_durations_array[@]} ; do
			Frame_duration_seconds=$(python3 -c "print(f'{float($Frame_delay) / 100}')")
			echo $Frame_duration_seconds >> ${New_folder}Metadata
		done

	elif [[ "$File_extension" == "mp4" ]] then
		Video_FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=noprint_wrappers=1:nokey=1 $CURRENT_FILE)
		Frame_duration_seconds=$(python3 -c "print(f'{ 1 / float($Video_FPS)}')")
		echo $Frame_duration_seconds >> ${New_folder}Metadata
	fi
fi
