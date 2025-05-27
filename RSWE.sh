#!/bin/bash

WALLPAPER_FOLDER="$HOME/Imagens/Wallpapers"
VIDEO_FRAMES_FOLDER="$HOME/Imagens/Wallpapers/Video_Wallpapers"
MONITOR_WORKSPACE_PATH="/backdrop/screen0/monitorDP-1/workspace0/last-image"
TIME=10

# Child Process PID (the run_GIF_wallpaper and the run_mp4_wallpaper functions will be
# child processes when called)
CHILD_PID=""

kill_child_process () {
	Child_PID=$1
	kill -9 $Child_PID
	# Waiting for it to be killed before exiting
	wait $Child_PID 2>/dev/null
}

# Called if the main process is killed (by the user) before it can kill its child
exit_gracefully () {
	# If the CHILD_PID is not empty. Aka this script has created a child
	if [[ ! -z $CHILD_PID ]] then
		kill_child_process $CHILD_PID
	fi
	exit 0
}
# For this function to listen to these signals
trap 'exit_gracefully' SIGKILL SIGTERM SIGINT

generate_GIF_frames () {
	Current_filename=$1
	GIF_Frames_folder=$2
	Full_file_path="${WALLPAPER_FOLDER}/${Current_filename}"

	# Breaking the GIF into frames
	# -fps_mode is there because ffmpeg tends to generate extra frames to preserve some
	# frame timing stuff, I'm disabling it.
	ffmpeg -i $Full_file_path -fps_mode passthrough ${GIF_Frames_folder}/frame%08d.png

	# %T\n returns that frame delay, or the time it stays on screen on 
	# 10 x milliseconds (a hundreth of a second) (Thanks gpt)
	Frame_durations_array=($(identify -format "%T\n" $Full_file_path))

	for Frame_delay in ${Frame_durations_array[@]} ; do
		# Converting to seconds
		Frame_duration_seconds=$(python3 -c "print(f'{float($Frame_delay) / 100}')")
		# Appending this frame's delay to the Metadata file
		echo $Frame_duration_seconds >> ${GIF_Frames_folder}/Metadata
	done

	exit 0
}

run_GIF_wallpaper () {
	Current_filename=$1
	# ???? removes the last 4 characters from the stirng
	GIF_Frames_folder="${VIDEO_FRAMES_FOLDER}/${Current_filename%????}_frames"

	# If there is a frames folder for this GIF
	if [[ -d $GIF_Frames_folder ]]; then
		# Grab the array of frames's time on screen
		GIF_sleep_delay=($(cat ${GIF_Frames_folder}/Metadata))
		while true; do
			GIF_sleep_delay_iter=0
			# Iterate over each frame
			for Frame in $(ls $GIF_Frames_folder | grep .png); do
				# Display frame image
				xfconf-query -c xfce4-desktop -p $MONITOR_WORKSPACE_PATH -s "${GIF_Frames_folder}/$Frame"

				# Waiting for this frame's time on screen
				sleep ${GIF_sleep_delay[$GIF_sleep_delay_iter]}
				# Go to the next frame's time on screen
				((GIF_sleep_delay_iter++))
				# Note to self, there is always a delay when leaving this loop
			done
		done
	else
		# Attempts at making a frame folder for this GIF
		if mkdir $GIF_Frames_folder; then
			# This process will exit after finishing, so no need to keep its PID or anything
			generate_GIF_frames $Current_filename $GIF_Frames_folder &
		else
			echo "VIDEO_FRAMES_FOLDER not found"
		fi
	fi
}

generate_mp4_frames () {
	Current_filename=$1
	Mp4_Frames_folder=$2
	Full_file_path="${WALLPAPER_FOLDER}/${Current_filename}"

	# Breaking video into frames
	ffmpeg -i $Full_file_path -fps_mode passthrough ${Mp4_Frames_folder}/frame%08d.png

	# Grabbing Mp4's framerate
	Video_FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=noprint_wrappers=1:nokey=1 $Full_file_path)
	# Getting a single frame duration on seconds
	Frame_duration_seconds=$(python3 -c "print(f'{ 1 / float($Video_FPS)}')")
	# Putting it on the Metadata file
	echo $Frame_duration_seconds >> ${Mp4_Frames_folder}/Metadata

	exit 0
}

run_mp4_wallpaper () {
	Current_filename=$1
	# ???? removes the last 4 characters from the stirng
	Mp4_Frames_folder="${VIDEO_FRAMES_FOLDER}/${Current_filename%????}_frames"

	# If there is a frames folder for this mp4
	if [[ -d $Mp4_Frames_folder ]]; then
		Video_sleep_delay=$(cat ${Mp4_Frames_folder}/Metadata)

		# Gonna wait untill this process is killed by its parent, aka when $TIME is up
		while true; do
			# Iterate over each frame
			for Frame in $(ls $Mp4_Frames_folder | grep .png); do
				# Display frame image
				xfconf-query -c xfce4-desktop -p $MONITOR_WORKSPACE_PATH -s "${Mp4_Frames_folder}/$Frame"
				# Waiting for this frame's time on screen (constant for Mp4)
				sleep $Video_sleep_delay
			done
		done
	else
		# Attempts at making a frame folder for this MP4
		if mkdir $Mp4_Frames_folder; then
			# This process will exit after finishing, so no need to keep its PID or anything
			generate_mp4_frames $Current_filename $Mp4_Frames_folder &
		else
			echo "VIDEO_FRAMES_FOLDER not found"
		fi
	fi
}

run_static_image_wallpaper () {
	Current_filepath=$1
	# Display image
	xfconf-query -c xfce4-desktop -p $MONITOR_WORKSPACE_PATH -s $Current_filepath
}

# MAIN

while true; do
	# Getting a random wallpaper from the Wallpaper folder
	Random_wallpaper_path=$(find "$WALLPAPER_FOLDER" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.mp4" \) | shuf -n 1)
	# Getting only the filename of the wallpaper, and not its full path
	Filename=$(echo "$Random_wallpaper_path" | awk -F/ '{print $NF}') # Thanks gpt
	File_extension=${Filename: -3}

	echo $Random_wallpaper_path

	# If it's a GIF wallpaper
	if [[ "$File_extension" == "gif" ]]; then
		run_GIF_wallpaper $Filename &

		# Save the child process PID
		CHILD_PID=$! # Thanks gpt

		# It's bloat, but I need it to listen for SIGNALS in between
		for i in $(seq 1 $TIME); do
			sleep 1
		done
		# Killing child process
		kill_child_process $CHILD_PID

	# If it's a mp4 wallpaper
	elif [[ "$File_extension" == "mp4" ]]; then
		run_mp4_wallpaper $Filename &

		# Save the child process PID
		CHILD_PID=$!

		for i in $(seq 1 $TIME); do
			sleep 1
		done
		# Killing child process
		kill_child_process $CHILD_PID

	# If it's a static image file wallpaper
	else
		run_static_image_wallpaper $Random_wallpaper_path
		sleep $TIME
	fi
done
