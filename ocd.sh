#!/bin/bash

# Started writing this code in 2018

# OCD (Organized & Categorized Data) is a tool to organize file and directory names to make files more archive-friendly.
# Written by Erim "xpelican" Bilgin :: https://github.com/xpelican :: https://linkedin.com/in/erim-bilgin

### NOTES #############################################################################################################

# Flags: -c to remove colors, -l for logging, -p for PROMPT MODE, -o to specify operations

# "find -name <string>" only finds files with exact string in their name, DOESN'T find files with string SOMEWHERE WITHIN their name. For that, do "find -name "*<string>*" the wildcards take care of the rest.

# UPDATES:
	# Right now, function_choose_operations allows you to define and save profiles, but doesn't allow you to load them. Add a check to flag "-o /user/dir/profilename.profile" or an option to choose from saved profiles in interactive batch mode.
	# Add more accented characters to rename.
	# Add more illegal characters to remove.
		# echo 'this_is`~!@#$%^&*()-+=\/{}?,:;<>_a_test' | sed 's/[^a-zA-Z0-9._]//g'
		# Put all illegal char renames into one function?
	# Add operation to change all non-ASCII names (generalizing the previous two features?)
	# ISO 9660 standard requirement: Do not use path or file names that correspond to operating system specific names, such as: AUX, COM1, CON, LPT1, NUL, PRN
	# Make a function to shorten file names longer than 64 characters.
	# Currently, OCD renames all "unwanted" characters to an underscore "_". I added a function to read a config file under "$launch_dir"/Config/ocd.cfg that reads a variable called "$default_seperator" - the plan is to eventually make it so that changing this character makes OCD switch unwanted characters to this character instead of the default underscore "_" (Make sure to also add checks to that function: allow no more than a single adjacent occurance of the character, don't allow certain characters, add escapes for certain characters, etc.)
	# Find and rename "junk" character bunches in filenames (like image_adk3r9i3faknkaslc392d_32qfdka.jpg or something; not sure how to differentiate this yet - Should be somewhat CPU intensive though.)
	# For image operations, consider implementing open-source Image Content Analysis tools to write a few words on images
	# Currently, any operations chosen by the user get run one after another, writing and overwriting files with each operation. This creates a lot of disk activity, which isn't good for protecting disks from wear. Future plans include changing this core modus operandi of OCD with a RAM-based "database" approach - wherein every file name under the target (assuming target is a directory with lots of files under it) is read and written into a dynamic database that OCD keeps on the RAM, then any changes made by the operations applied to the entries within this database, making the appropriate changes with each operation, then finally changing the filenames to their ultimate new names in a single elegant disk write for each file, instead of several for each chosen function. Currently, I was a bit too comfortable with the ways of mv to apply this. | A different way to implement this could be to create a temporary filesystem on the RAM, copy the entire target directory there, and apply operations on there, then finally replacing the RAM-based tempfs directory with the original target path - however this approach assumes the user has a lot of physical RAM accessible, as otherwise the tempFS would only end up using a lot of swap memory, which defeats the aim of reducing disk activity.

# PROBLEMS:
	# Currently, when Beets cannot find information for a music file, it renames that file to "_". Needless to say, this is quite problematic. One way to go about fixing this would be to make it so that when Beets can't find information for a file, the function leaves that file untouched.

# CHECKS:
	#function_target_fail_check loops into itself on a failstate, check if this produces any problems.

### SOFTWARE ##########################################################################################################

# beets convert exiftool fdupes gprename imagemagick mogrify pip pip3 pyrenamer realpath rename symlinks
# Test_Folder uses an excellent set of example images from https://github.com/ianare/exif-samples

### STYLE #############################################################################################################

# functions are defined as 'function_<function_name> () {}', with 5 spaces between each function.
	# Each function's argument sanitization and clean initialization steps are tabbed once like this.

# Colors:
#
# First, define color variables. You can use ANSI escape codes:
#
#	Black        0;30     Dark Gray     1;30
#	Red          0;31     Light Red     1;31
#	Green        0;32     Light Green   1;32
#	Orange       0;33     Yellow        1;33
#	Blue         0;34     Light Blue    1;34
#	Purple       0;35     Light Purple  1;35
#	Cyan         0;36     Light Cyan    1;36
#	Light Gray   0;37     White         1;37
#
# Be sure to use the -e flag in your echo commands to allow backslash escapes.
bold_white='\e[1;38m'
white='\e[0;38m'
grey='\e[0;37m'
dark_grey='\e[1;30m'
green='\e[0;32m'
yellow='\e[1;33m'
red='\e[0;31m'
blue='\e[0;36m'
dark_yellow='\e[0;33m'

# Prompts:
# WHITE   [!]: echo -e ""$grey"["$bold_white"!"$grey"]::
# GREEN   [+]: echo -e ""$grey"["$green"+"$grey"]::
# YELLOW  [-]: echo -e ""$grey"["$yellow"-"$grey"]::
# RED     [x]: echo -e ""$grey"["$red"x"$grey"]::
# Colored [Y/N]: ""$grey"["$bold_white"Y"$grey"/"$red"N"$grey"]?"

# Print DONE/FAILED message for previous operation:
# if [[ $? -eq 0 ]]; then
# 	echo -e ""$grey"["$green"+"$grey"]::Done.\n"
# else
#	echo -e ""$grey"["$red"x"$grey"]::Failed. Exiting.\n" >&2;
# 	function_exit_1
# fi



function_print_help () {
# Show help:

echo -e "\nUsage: ocd <[-OPTION]> <[OPTION ARGS]> <TARGET PATH>"
echo -e "  or: <command that outputs path(s) | ocd <[-OPTION]> <[OPTION ARGS]> -"
echo -e "Target path can be relative or absolute."

echo -e "\nOPTIONS:"
echo -e "   -c :           Remove color from output (it is colored by default)"
echo -e "   -l :           Enable logging. Logs will be output to <launch directory>/Log/ocd_<process date>.log"
echo -e "   -p :           Enable PROMPT MODE. With this option enabled, OCD will require the user to press [ENTER] between each batch of renaming operations."
echo -e "   -o :           Specify which operations to include in the run non-interactively. Useful for automation purposes."
echo -e "                  [ EXAMPLE: ocd -o 1,2,3,15,18 <TARGET> ]"

echo -e "\nOCD GitHub page: <https://github.com/xpelican/OCD>"
echo -e "Please report any errors you encounter. Thank you."
}



function_print_error () {
	echo -e ""$white"["$red"x"$white"]::"$@"" 1>&2;
}



function_prompt () {
# Running OCD with the -p flag enables PROMPT MODE, where the user has to hit a key for the process to keep moving forward at each step. This is used for testing, where we can pause the process between each step OCD perfroms and inspect how the results are coming along.
# If there is no -p flag, function_prompt becomes a 1 second sleep between operations:
		# (Condition for -p flag is coded below in the getopts section)
	echo -e "\n"$dark_grey"Moving on to next operation.\n"
	sleep 1
}

### /STYLE ############################################################################################################



















### OPTIONS ###########################################################################################################

while getopts ":hclpb:o:" opt; do
	case "$opt" in



		h)
			# Print help:
			function_print_help
			exit 0
			;;




		c)
			# Remove colors:
			white=""
			grey=""
			green=""
			yellow=""
			red=""
			blue=""
			bold_white=""
			dark_grey=""
			dark_yellow=""
			;;



		l)
			# Enable logging function:
			status_logging="true"
			;;



		p)
			# Enable PROMPT MODE:
			function_prompt () {
			echo -e "\n"$white"Press "$green"[ANY KEY] "$white"to continue to next operation, or "$red"[CTRL+C] "$white"to quit."$grey""
			read  -r -p ""
			}
			;;



		b)
			# Enable backups:
			status_backup="true"
			backup_dir="$OPTARG"
			;;



		o)
			# The -o flag specifies which operations to include in the run non-interactively. Useful for automation purposes.
			status_input_operations="true"
			input_operations="$OPTARG"
			;;



		\?)
			echo -e "Invalid option supplied: -"$OPTARG"" >&2
			function_print_help
			function_exit_1
			;;

	esac
done

### /OPTIONS ##########################################################################################################




















### PIPE CHECK ########################################################################################################
# Target pasing goes like: Get "user input" > check for errors > clarify programmatically and make error-proof > make a "target"

# PIPED / BATCH setting:
if [ -t 0 ]; then
    echo -e "Running in INTERACTIVE MODE.\n"
	# If OCD was specifically called and given a target, that means we're running BATCH MODE - we print the logo, use interactivity, do all the bells and whistles because there's no problem with verbose output getting printed on the screen - it's OCD's show.
	mode="batch"
	input="$1"
else
	echo -e "Running in PIPED MODE.\n"
	# If there are no arguments, read $INPUT from STDIN (PIPED MODE):
	# If a target has been passed to OCD from another program, that means OCD is supposed to take output (in the form of file paths, one line at a time)
	mode="piped"
#    while read -r line ; do
#		input="$line"
#    done
fi

### /PIPE CHECK #######################################################################################################

















### OPTIONS SETUP #####################################################################################################

function_setup_log () {
if [ "$status_logging" = "true" ]; then
	echo -e ""$dark_grey"Logging enabled."
	logfile=""$launch_dir"/Log/ocd_"$process_date".log"

	# Line below timestamps the logfile, and if that write is successful, lets the user know write is good.
	echo -e "\nProcess Date: "$process_date"" > "$logfile"

		if [[ $? -eq 0 ]]; then
			echo -e ""$dark_grey"["$green"+"$dark_grey"]::Write successful. Log file for this session is situated in "$grey""$logfile""$grey".\n"
		else
			echo -e ""$grey"["$red"x"$grey"]::Write to log file failed. Logging will be DISABLED..\n" >&2;
		 	status_logging="false"
		fi
fi
}





function_log () {
# function_log should only be PIPED TO within the script.
if [ "$status_logging" = "true" ]; then
	tee -a "$logfile"
else
	cat /dev/stdin
fi
}





function_choose_operations () {
# If the -o flag was activated with argument "a", it means we apply ALL operations:
if [[ ("$input_operations" = "a") || ("$mode" = "piped" && "$status_input_operations" != "true" && -z "$input_operations") ]]; then
	# Include all functions in operation:
	input_operations="1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20"	
fi



# PIPED: If the -o flag was activated, but no arguments given to it, print an error about it and exit:
if [ "$mode" = "piped" ] && [ "$status_input_operations" = "true" ] && [ -z "$input_operations" ]; then
	function_print_error "No operations specified to the -o flag. If using the -o flag, either specify operations to apply, seperated by COMMA (,) characters, or type a (as in "-o a" to apply all operations."
	function_exit_1
fi



# List possible operations, ask user to input operation numbers, grep the input.
if [ "$mode" = "batch" ] && [ -z "$input_operations" ]; then

	echo -e "\n"$white"["$yellow"!"$white"]"$white"::Which operations would you like OCD to perform for this session?"
	echo -e "  "$dark_grey"[0] :: Print help and exit"

	echo -e "\n "$red"OPERATIONS "$grey""
	echo -e ""$dark_grey"Junk removal operations: "$grey""
	echo -e "  "$yellow"[1]"$grey" :: Delete empty directories"
	echo -e "  "$yellow"[2]"$grey" :: Delete duplicate files"
	echo -e "  "$yellow"[3]"$grey" :: Delete broken symlinks"

	echo -e "\n"$dark_grey"Renaming operations: "$grey""
	echo -e "  "$yellow"[4]"$grey" :: Rename whitespace characters to underscores"
	echo -e "  "$yellow"[5]"$grey" :: Rename illegal characters"
	echo -e "  "$yellow"[6]"$grey" :: Rename files starting with special characters other than \".\""
	echo -e "  "$yellow"[7]"$grey" :: Rename all filenames to lowercase"
	echo -e "  "$yellow"[8]"$grey" :: Rename all accented characters to international characters"
	echo -e "  "$yellow"[9]"$grey" :: Rename directories to start with Capital Letters"
	echo -e " "$yellow"[10]"$grey" :: Add .file extension to files without extensions"
	echo -e " "$yellow"[11]"$grey" :: Rename extensions to lowercase"
	echo -e " "$yellow"[12]"$grey" :: Sqeeze repeating special characters"
	echo -e " "$yellow"[13]"$grey" :: Rename user-specified bad character combinations"
	echo -e " "$yellow"[14]"$grey" :: Remove tilde (~) characters that might result from renaming operations"

	echo -e "\n"$dark_grey"Image renaming / tagging operations: "$grey""
	echo -e " "$yellow"[15]"$grey" :: Prepend images with their resolution"
	echo -e " "$yellow"[16]"$grey" :: Prepend images with their EXIF location data"
	echo -e " "$yellow"[17]"$grey" :: Prepend images with their device name"
	echo -e " "$yellow"[18]"$grey" :: Prepend images with their dates"
	echo -e " "$yellow"[19]"$grey" :: Remove EXIF data from images"

	echo -e "\n"$dark_grey"Music renaming / retagging operations: "$grey""
	echo -e " "$yellow"[20]"$grey" :: Use beets to sort & tag music archive (AUTO)"
#	echo -e " "$yellow"[19]"$grey" :: Use beets to sort & tag music archive (MANUAL)"

#	echo -e "\n"$dark_grey"Placement / Categorization operations: "$grey""
#	echo -e " "$yellow"[20]"$grey" :: Categorize and move files according to their content "$dark_grey"(as specified within config file)"$grey""

	echo -e "\n"$grey"Please enter the numbers for each operation you would like performed with COMMAS (,) between them, and hit "$white"[ENTER]."$white""
	echo -e ""$dark_grey"(EXAMPLE: 1,2,3,16,17)"
	echo -e ""$grey"Leave empty and press "$white"[ENTER]"$grey" to apply all operations"
	read -r -p "" input_operations

	if [ "$input_operations" = '' ]; then
	# If user left the input field empty, it means apply all operations.
		echo -e ""$grey"Applying the default configuration..."
		input_operations="1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20"	
	else
			echo -e ""$dark_grey"["$yellow"?"$dark_grey"]::Would you like to save this configuration for later use? "$grey"["$bold_white"Y"$grey"]?"
				read -r -p "" response
				case "${response}" in
			    [yY][eE][sS]|[yY]) 
					echo -e ""$grey"["$bold_white"!"$grey"]::Please enter a profile name and press [ENTER]"
					read -r -p "" response2
					# Parse response2 to remove all uppercase and special characters, leave only lowercase and numbers:
					ocd_profile_name=$(echo -e "$response2" | tr -dc '[:alnum:]\n\r' | tr '[:upper:]' '[:lower:]')

					# Clear up input operations (also done below in case this step isn't in place) and save:
					chosen_operations=$(echo "$input_operations" | sed 's/[^,0-9]*//g')
					echo "$chosen_operations" > "$launch_dir"/Config/"$ocd_profile_name".profile
					echo -e ""$grey"["$green"+"$grey"]::Profile saved as: "$launch_dir"/Config/"$ocd_profile_name".profile"
					;;
				*)

		        ;;
				esac		
	fi

fi


# Clarify input so only numbers (0-9) and commas (,) remain:
chosen_operations=$(echo "$input_operations" | sed 's/[^,0-9]*//g') # Take the "chosen_operations" string, and remove any character that's not a digit.
}




function_read_config () {
ocd_config_file=""$launch_dir"/Config/ocd.cfg"

default_seperator=$(cat "$ocd_config_file" | grep '^[[:blank:]]*[^[:blank:]#;]' | grep "DEFAULT_SEPERATOR" | cut -d= -f2)
	# If there's no default seperator specified, rather than canceling operation, we default to underscore.
	if [ -z "$default_seperator" ]; then
		default_seperator="_"
	fi
}

### /OPTIONS SETUP ####################################################################################################



















### CORE ##############################################################################################################

process_date=$(date +"%Y%m%d%H%M%S")
username=$(whoami)
launch_dir="/opt/OCD"



function_exit_0 () {
echo -e "\n"$grey"["$bold_white"!"$grey"]::Cleaning up temporary files..."
rm -r "$launch_dir"/Temp/* 2>/dev/null
if [ "$mode" = "batch" ]; then
	echo -e ""$grey"["$green"+"$grey"]::Done. Goodbye!"
	exit 0
fi
}



function_exit_1 () {
function_print_error "Cleaning up temporary files..."
rm -r "$launch_dir"/Temp/* 2>/dev/null

if [ "$mode" = "batch" ]; then
	echo -e ""$grey"["$green"+"$grey"]::Done. Goodbye!"
	exit 1
fi

if [ "$mode" = "piped" ]; then
	exit 1
fi
}



trap function_exit_0 SIGINT SIGTERM


### /CORE #############################################################################################################



















### DEPENDENCY CHECKS #################################################################################################

function_symlink_check () {
	if ! [ -e /usr/local/bin/ocd ]; then
		sudo ln -s "$launch_dir"/ocd.sh /usr/local/bin/ocd
	fi
}

function_dependency_check_auto () {
# function_dependency_check_auto requires the name of the package as it's specified in the repositories as ARGUMENT 1; queries it with DPKG; and if it's not installed, uses the APT package manager to install the required package.
package_name="$1"

dpkg -s "$program_name" &> /dev/null
	if [ $? -eq 1 ]; then
		sleep 0.2
		echo -e ""$white"["$red"x"$white"]::"$yellow""$package_name""$white" is not installed, but it is required."
		if [ "$mode" = "batch" ]; then
			sleep 0.2
			echo -e ""$grey"Do you want to install it "$grey"["$bold_white"Y"$grey"/"$red"N"$grey"]?"
			read -r -p "" response
				case "${response}" in
				    [yY][eE][sS]|[yY]) 
						sudo apt install -y "$package_name" && echo -e ""$grey"["$green"+"$grey"]::"$package_name" installed"
						;;
					*)
							function_print_error ""$package_name" not installed. "$red"Aborting."; function_exit_1;
			        ;;
				esac
		else
			function_print_error ""$package_name" not installed. "$red"Aborting."; function_exit_1;
		fi
	fi
}



function_dependency_check () {
#Beets' Chromaprint plugin dependencies are detailed here: https://beets.readthedocs.io/en/v1.4.6/plugins/chroma.html

function_dependency_check_auto python
function_dependency_check_auto python3
function_dependency_check_auto python-pip
function_dependency_check_auto python3-pip
function_dependency_check_auto libchromaprint-tools
function_dependency_check_auto gstreamer1.0-x
function_dependency_check_auto gstreamer1.0-plugins-base
function_dependency_check_auto gstreamer1.0-plugins-good
function_dependency_check_auto gstreamer1.0-plugins-bad
function_dependency_check_auto gstreamer1.0-plugins-ugly
function_dependency_check_auto gstreamer1.0-libav
function_dependency_check_auto gstreamer1.0-doc
function_dependency_check_auto gstreamer1.0-tools
function_dependency_check_auto gstreamer1.0-x
function_dependency_check_auto gstreamer1.0-alsa
function_dependency_check_auto gstreamer1.0-gl
function_dependency_check_auto gstreamer1.0-gtk3
function_dependency_check_auto gstreamer1.0-qt5
function_dependency_check_auto gstreamer1.0-pulseaudio
function_dependency_check_auto python-gi
function_dependency_check_auto libimage-exiftool-perl
function_dependency_check_auto fdupes
function_dependency_check_auto imagemagick
function_dependency_check_auto coreutils
function_dependency_check_auto rename
function_dependency_check_auto symlinks

if ! [[ $(pip search pyacoustid | grep -i "INSTALLED") ]]; then
	sleep 0.2
	echo -e ""$white"["$red"x"$white"]::"$yellow"pyacoustid"$white" is not installed, but it is required."
	if [ "$mode" = "batch" ]; then
		sleep 0.2
		echo -e ""$grey"Do you want to install it "$grey"["$bold_white"Y"$grey"/"$red"N"$grey"]?"
		read -r -p "" response
			case "${response}" in
			    [yY][eE][sS]|[yY]) 
					sudo pip install pyacoustid && echo -e ""$grey"["$green"+"$grey"]::pyacoustid installed"
					;;
				*)
						function_print_error "pyacoustid not installed. "$red"Aborting."; function_exit_1;
		        ;;
			esac
	else
		function_print_error "pyacoustid not installed. "$red"Aborting."; function_exit_1;
	fi
fi

if ! [[ $(pip3 search pyacoustid | grep -i "INSTALLED") ]]; then
	sleep 0.2
	echo -e ""$white"["$red"x"$white"]::"$yellow"pyacoustid"$white" is not installed, but it is required."
	if [ "$mode" = "batch" ]; then
		sleep 0.2
		echo -e ""$grey"Do you want to install it "$grey"["$bold_white"Y"$grey"/"$red"N"$grey"]?"
		read -r -p "" response
			case "${response}" in
			    [yY][eE][sS]|[yY]) 
					sudo pip3 install pyacoustid && echo -e ""$grey"["$green"+"$grey"]::pyacoustid installed"
					;;
				*)
						function_print_error "pyacoustid not installed. "$red"Aborting."; function_exit_1;
		        ;;
			esac
	else
		function_print_error "pyacoustid not installed. "$red"Aborting."; function_exit_1;
	fi
fi
}

### /DEPENDENCY CHECKS ################################################################################################


















# INTRO ###############################################################################################################
function_intro () {
if [ "$mode" = "batch" ]; then
	echo -e "$white"'                                              '
	echo -e "$dark_grey"'||||||||||||||||||||||||||||||||||||||||||||||'
	echo -e "$white"'                                              '
	echo -e "$white"'  ,ad8888ba,      ,ad8888ba,   88888888ba,    '
	echo -e "$white"' d8"      "8b    d8"      "8b  88       "8b   '
	echo -e "$white"'d8         "8b  d8             88         8b  '
	echo -e "$white"'88          88  88             88         88  '
	echo -e "$white"'88          88  88             88         88  '
	echo -e "$white"'Y8,        ,8P  Y8,            88         8P  '
	echo -e "$white"' Y8a.    .a8P    Y8a.    .a8P  88      .a8P   '
	echo -e "$white"'   "88888Y"        "Y8888Y"    88888888Y"     '
	echo -e "$white"'                                              '
	echo -e "$dark_grey"'||||||||||||||||||||||||||||||||||||||||||||||'
	echo -e "$white"'  Organized   &   Categorized     Data        '
	echo -e "$dark_grey""|||||||||||||||||||||||||||||||||||||||||$red/$dark_grey|||"
	echo -e "$white"'                                              '
	echo -e ""$grey"\n------------------------------------------------"
	echo -e ""$red"Starting processing files..."
	echo -e ""$dark_grey"Process date: "$process_date""
fi
}
#######################################################################################################################



















### BACKUPS ###########################################################################################################

function_make_backup () {
# Get backups of files before archiving
# If batch mode was launched with the -b flag...
if [ "$mode" = "batch" ] && [ "$status_backup" = "true" ]; then
	# ...then the user is also expected to have specified a backup directory, but we backup to user's home directory if they haven't.
	if [ ! -d "$backup_dir" ]; then
		mkdir /home/"$username"/OCD_"$process_date"_Backup
		cp -r "$target" /home/"$username"/OCD_"$process_date"_Backup && echo -e ""$grey"["$green"+"$grey"]::Backup complete." || echo -e ""$grey"["$red"x"$grey"]::Backup failed."
	else
		cp -r "$target" "$backup_dir" && echo -e ""$grey"["$green"+"$grey"]::Backup complete." || echo -e ""$grey"["$red"x"$grey"]::Backup failed."
	fi
fi



# If batch mode wasn't already launched with -b flag, prompt the user to take backups one last time anyway (this will be removed once I'm more confident in OCD's capabilities.)
if [ "$mode" = "batch" ] && [ "$status_backup" != "true" ]; then
	echo -e "\n"$dark_grey"["$yellow"!"$dark_grey"]"$dark_grey"::OCD is still in development, and its operations are not yet perfect. In order to protect your data from possible corruption, it is strongly recommended that you back up your data before processing."$white""
	echo -e ""$grey"Do you want OCD to make a backup of the target path before archiving "$grey"["$white"Y"$grey"/"$red"N"$grey"]?"$bold_white""
	read -r -p "" response_backup
		case "${response_backup}" in
		    [yY][eE][sS]|[yY]) 
			echo -e ""$grey"OCD will now copy "$target"."
			echo -e "\n"$white"Please enter the absolute path for the directory you want to backup to "$grey"(leaving empty will place the backup in current user's home directory):"
			read backup_dir

				if [ ! -d "$backup_dir" ]; then
					mkdir /home/"$username"/OCD_"$process_date"_Backup
					cp -r "$target" /home/"$username"/OCD_"$process_date"_Backup && echo -e ""$grey"["$green"+"$grey"]::Backup complete." || echo -e ""$grey"["$red"x"$grey"]::Backup failed."
				else
					cp -r "$target" "$backup_dir" && echo -e ""$grey"["$green"+"$grey"]::Backup complete." || echo -e ""$grey"["$red"x"$grey"]::Backup failed."
				fi

		esac
fi


# If running in PIPED MODE, there's no room for interactivity; and plus, OCD might be running a few times in a "while read line" loop. If a -b flag was provided, check it for an argument and if it doesn't, just copy to user's home directory.
if [ "$mode" = "piped" ] && [ "$status_backup" = "true" ]; then

	if [ -d "$backup_dir" ]; then
		mkdir /home/"$username"/OCD_"$process_date"_Backup
		cp -r "$target" /home/"$username"/OCD_"$process_date"_Backup/
	else
		cp -r "$target" "$backup_dir"
	fi

fi
}

### /BACKUPS ##########################################################################################################



















### FILE PROCESSING STARTS HERE ###



















### JUNK REMOVAL & FILE (NOT FILE NAME) OPERATIONS ####################################################################

# Find and delete empty directories as well as directories that contain only empty directories. find can do that itself with -delete and -empty:
function_delete_empty_directories () {
echo -e "\n"$white"["$bold_white"!"$white"]::"$white"Finding and deleting empty directories..."$grey""

# find empty directories in target | Change all newlines with a NULL character | Feed it to rm with the -0 argument:
# find "$target" -type d -empty | tr "\n" "\0" | xargs -0 rm -r

find "$target" -depth -type d -empty -delete
}



# Find duplicate files
### unison instead of fdupes for duplicate file detection and removal?
function_delete_duplicate_files () {
# fdupes syntax: -r: recursive search / -S: Show SIZE of duplicates / -n: "no empty" doesn't include empty files into the process as they all appear the same too.
#echo -e "\n"$white"Finding duplicate files based on hashes..."$grey""
#if [ "$mode" = "piped" ]; then
#fdupes -r -n -S "$target"

echo -e "\n"$white"["$bold_white"!"$white"]::"$white"Deleting duplicate files based on hashes..."$grey""
fdupes -r -n -S -d -N "$target"
sleep 0.5
}



# Delete broken symlinks:
function_delete_broken_symlinks () {
echo -e "\n"$white"["$bold_white"!"$white"]::"$white"Removing all broken symbolic links..."$grey""
symlinks -d -r "$target"
#find -L "$target" -name . -o -type d -prune -o -type l -exec rm {} +
}

### /JUNK REMOVAL & FILE (NOT FILE NAME) OPERATIONS ###################################################################



















### RENAMING ##########################################################################################################

# Rename whitespaces to underscores:
function_rename_whitespace_to_underscore () {
# The regular expression sytax for this change is: rename 's/ /_/g' * -v 	|	# Brackets mean "any one of"
echo -e "\n"$white"["$bold_white"!"$white"]::"$white"Converting all whitespace characters to underscores..."$grey""
find "$target" -depth -a -name "*\ *" -print0 | while IFS= read -r -d '' i; do
	original_name=$(basename "$i")
	dirname=$(readlink -f "$i" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(basename "$i" | sed 's/[\ ]/_/g')

	# And finally rename:
	if [ "$new_name" != "$original_name" ]; then
		mv -v -T --backup=t "$i" "$dirname"/"$new_name"
	fi

done
}







# Rename all FILES to LOWERCASE:
#   IMPORTANT: Make sure this operation only affects the FILE name, and not the parent directories in it's full path.
function_rename_filenames_to_lowercase () {
echo -e "\n"$white"["$bold_white"!"$white"]::"$white"Renaming all filenames to lowercase..."$grey""
find "$target" -depth -type f -exec rename 's:([^/]*$):lc($1):e' {} +
# In the command above, ([^/]*$) matches only the last part of the path that doesn't contain a / inside a pair of parentheses(...) which it makes the matched part as group of matches. hen translate matched part($1 is index of first matched group) to lowercase with lc() function. -exec ... {} + is for commands that can take more than one file at a time (eg cat, stat, ls). The files found by find are chained together like an xargs command. This means less forking out and for small operations, can mean a substantial speedup.
}



# Rename all DIRECTORIES to have Capital_First_Letters:
function_rename_directories_to_capital () {
echo -e "\n"$white"["$bold_white"!"$white"]::"$white"Capitalizing first letter of every word in directories..."$grey""

find "$target" -depth -type d | awk '{print gsub("/","/"), $0}' | sort -rn | cut -d' ' -f2- | while read -r i; do

	original_name=$(basename "$i")	
	dirname=$(echo "$i" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(basename "$i" | tr '[:upper:]' '[:lower:]' | sed -e "s/\b\(.\)/\u\1/g" | sed 's/_./\U&/g')
	
	if [ "$new_name" != "$original_name" ]; then
		mv -T -v --backup=t "$i" "$dirname"/"$new_name"
	fi

done
}





function_rename_illegal_chars () {
# Remove the other illegal characters:

# FILES:
echo -e "\n"$white"["$bold_white"!"$white"]::"$white"Removing special characters:"
sleep 0.2


# Remove - from filenames:
echo -e ""$white"Removing all - characters..."$grey""
#find "$target" -type f -exec rename "s/\$//g" {} +
find "$target" -depth -a -name "*-*" -print0 | while IFS= read -r -d '' i; do

	original_name=$(basename "$i")
	dirname=$(echo "$i" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(sed 's/-//g' <<< "$original_name")

	if [ "$new_name" != "$original_name" ]; then
		mv -v -T --backup=t "$i" "$dirname"/"$new_name"
	fi

done



# Remove ' from filenames:
echo -e ""$white"Removing all ' characters..."$grey""
find "$target" -depth -a -name "*[\']*" -print0 | while IFS= read -r -d '' i; do

	original_name=$(basename "$i")
	dirname=$(echo ""$i"" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(sed "s/'//g" <<< "$original_name")


	if [ "$new_name" != "$original_name" ]; then
		mv -v -T --backup=t "$i" "$dirname"/"$new_name"
	fi

done



# Remove " from filenames:
echo -e ""$white"Removing all \" characters..."$grey""
find "$target" -depth -a -name "*[\"]*" -print0 | while IFS= read -r -d '' i; do

	original_name=$(basename "$i")
	dirname=$(echo ""$i"" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(sed "s/\"//g" <<< "$original_name")


	if [ "$new_name" != "$original_name" ]; then
		mv -v -T --backup=t "$i" "$dirname"/"$new_name"
	fi

done



# Remove ? from filenames:
echo -e ""$white"Removing all ? characters..."$grey""

find "$target" -depth -a -name "*[\?]*" -print0 | while IFS= read -r -d '' i; do

	original_name=$(basename "$i")
	dirname=$(echo "$i" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(sed 's/?//g' <<< "$original_name")


	if [ "$new_name" != "$original_name" ]; then
		mv -v -T --backup=t "$i" "$dirname"/"$new_name"
	fi

done



# Remove ! from filenames:
echo -e ""$white"Removing all ! characters..."$grey""

find "$target" -depth -a -name "*\!*" -print0 | while IFS= read -r -d '' i; do

	original_name=$(basename "$i")
	dirname=$(echo ""$i"" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(sed "s/\!//g" <<< "$original_name")


	if [ "$new_name" != "$original_name" ]; then
		mv -v -T --backup=t "$i" "$dirname"/"$new_name"
	fi

done



# Remove % from filenames:
echo -e ""$white"Removing all % characters..."$grey""
find "$target" -depth -a -name "*[%]*" -print0 | while IFS= read -r -d '' i; do
	
	original_name=$(basename "$i")
	dirname=$(echo ""$i"" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(sed "s/%//g" <<< "$original_name")

	if [ "$new_name" != "$original_name" ]; then
		mv -v -T --backup=t "$i" "$dirname"/"$new_name"
	fi

done



# Remove : from filenames:
echo -e ""$white"Removing all : characters..."$grey""
find "$target" -depth -a -name "*[:]*" -print0 | while IFS= read -r -d '' i; do

	original_name=$(basename "$i")
	dirname=$(echo ""$i"" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(sed "s/://g" <<< "$original_name")

	if [ "$new_name" != "$original_name" ]; then
		mv -v -T --backup=t "$i" "$dirname"/"$new_name"
	fi

done



# Remove ; from filenames:
echo -e ""$white"Removing all ; characters..."$grey""
#find "$target" -type f -exec rename "s/;//g" {} +
find "$target" -depth -a -name "*[\;]*" -print0 | while IFS= read -r -d '' i; do

	original_name=$(basename "$i")
	dirname=$(echo ""$i"" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(sed "s/\;//g" <<< "$original_name")

	if [ "$new_name" != "$original_name" ]; then
		mv -v -T --backup=t "$i" "$dirname"/"$new_name"
	fi

done



# Remove $ from filenames:
echo -e ""$white"Removing all \$ characters..."$grey""
#find "$target" -type f -exec rename "s/\$//g" {} +
find "$target" -depth -a -name "*\$*" -print0 | while IFS= read -r -d '' i; do

	original_name=$(basename "$i")
	dirname=$(echo "$i" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(sed 's/\$//g' <<< "$original_name")

	if [ "$new_name" != "$original_name" ]; then
		mv -v -T --backup=t "$i" "$dirname"/"$new_name"
	fi

done
}








function_rename_accent_to_global () {
# Rename all ACCENTED CHARACTERS into global ones:

# Thanks to Seko for this sed line:
# echo "çğıöşüÇĞİÖŞÜ" | sed 's/ç/c/gI; s/ğ/g/gI; s/ı/i/gI; s/ö/o/gI; s/ş/s/gI; s/ü/u/gI; s/İ/I/gI' 	

echo -e "\n"$white"["$bold_white"!"$white"]::"$white"Renaming accented characters into English characters..."$grey""

find "$target" -depth -print0 | while IFS= read -r -d '' i; do

	original_name=$(basename "$i")
	dirname=$(readlink -f ""$i"" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(echo "$original_name" | sed 's/ç/c/gI; s/ğ/g/gI; s/ı/i/gI; s/İ/I/gI; s/ö/o/gI; s/ş/s/gI; s/ü/u/gI')
	#echo "ĞÜŞÖÇİğüşöçı" |  sed 's/ç/c/gI; s/ğ/g/gI; s/ı/i/gI; s/İ/I/gI; s/ö/o/gI; s/ş/s/gI; s/ü/u/gI'
	#echo "ĞÜŞÖÇİğüşöçı" |  sed 's/ç/c/gI; s/ğ/g/gI; s/İ/I/gI; s/ı/i/gI; s/ö/o/gI; s/ş/s/gI; s/ü/u/gI'

	if [ "$new_name" != "$original_name" ]; then
		mv -v -T --backup=t "$i" "$dirname"/"$new_name" 2>/dev/null
	fi

done
#echo -e "aaa bbb c\naaa_bbb_c\naaa-bbb-c" | sed 's/^\(.\)/\U\1/g' | sed 's/\([ _-].\)/\U\1/g'
}









function_rename_user_bad_combos () {
# First, check if USER_COMBO has been defined in config file, skip entire function if the line doesn't exist.
if [[ $(cat "$ocd_config_file" | grep '^[[:blank:]]*[^[:blank:]#;]' | grep "USER_COMBO") ]]; then

	# Rename based on user config:
	echo -e "\n"$white"["$bold_white"!"$white"]::"$white"Renaming according to user's personal preferences..."$grey""

	cat "$ocd_config_file" | grep '^[[:blank:]]*[^[:blank:]#;]' | grep "USER_COMBO" | tr "\n" "\0" | while IFS= read -r -d '' i; do

	bad_combo=$(echo -e "$i" | cut -d= -f2 | cut -d: -f1)
	good_combo=$(echo -e "$i" | cut -d= -f2 | cut -d: -f2)

	echo -e "\n"$grey"Renaming "$yellow""$bad_combo""$grey" characters into "$yellow""$good_combo""$grey" in filenames..."$grey""

		find "$target" -depth -a -iname "*"$bad_combo"*" -print0 | while IFS= read -r -d '' i; do

			original_name=$(basename "$i")
			dirname=$(echo "$i" | sed 's/\(^.*\)\/.*$/\1/')
			new_name=$(echo "$original_name" | sed "s/\\"$bad_combo"/"$good_combo"/g")

			if [ "$new_name" != "$original_name" ]; then
				mv -v -T --backup=t "$i" "$dirname"/"$new_name"
			fi

		done

	done
fi
}





#function_rename_consequtive_special_chars () {}





function_rename_shorten_long_junk_names () {
echo -e "\n"$white"["$bold_white"!"$white"]::"$white"Shortening junk file names..."$grey""

#find filenames with characters that go on for longer than x characters without a _ or .
# The idea for this function is solid, but somewhat too large for my capabilities: There are a lot of files, usually downloaded off the internet, which have "junk" names like asd32456ij54uXAW201501.jpg (actual filename from my browser cache).
# The idea is to somehow spot these junk filenames, and at least take some measures to make them "prettier".
# We can't go the distance of scanning filenames to find whether they contain actual words, or otherwise intelligable information - so we do something much more primitive and luck-based, but hey, it's something! Here it is:

# 	Junk files will usually be formatted like asdasdasdasdasdasd.txt or asd123asd34sd.txt - basically a chaotic mix of alphanumeric characters.
#	 But these files probably have a higher chance of being a somewhat proper name if they were maybe like asdasd_asd_asdasdasd.txt, since if someone took the effort to split the words apart, there's probably something in there to split apart!
#	 Above tip goes also for WHITESPACE characters and % characters.
}









function_rename_add_extension () {
echo -e "\n"$white"["$bold_white"!"$white"]::"$white"Adding a .file extension to files with no extensions..."$grey""
find "$target" -depth -type f ! -name "*.*" -exec bash -c 'mv "$0" "$0".file' {} \;
}









function_rename_extensions_to_lowercase () {
echo -e "\n"$white"["$bold_white"!"$white"]::"$white"Renaming file extensions to lowercase where possible..."$grey""
find "$target" -depth -type f -name '*.*' -exec bash -c 'base=${0%.*} ext=${0##*.} a=$base.${ext,,}; [ "$a" != "$0" ] && mv -- "$0" "$a"' {} \;
}









function_rename_special_initials () {
# Only run this function if function_rename_illegal_chars was not chosen
if ! [[ $(echo "$chosen_operations" | grep '\b5\b') ]]; then

	# This function finds filenames that for whatever reason start with special characters other than dot "."
	echo -e "\n"$white"["$bold_white"!"$white"]::"$white"Renaming files that start with special characters other than dot (.)..."$grey""
	find "$target" -depth -name "[\'\"\!\%\:\;\$]*" -print0 | while IFS= read -r -d '' i; do

		original_name=$(basename "$i")
		dirname=$(readlink -f "$i" | sed 's/\(^.*\)\/.*$/\1/')
		new_name=$(echo -e "$original_name" | sed's/^.//') # the sed here removes first (^) ONE character (.) and replaces it with NOTHING (//)

		if [ "$new_name" != "$original_name" ]; then
			mv -v -T --backup=t "$i" "$dirname"/"$new_name"
		fi

	done

fi
}









function_rename_squeeze_repeating_special_characters () {
# This function finds all special characters that repeat (such as __ or .. and so on) and squeezes them into a single one:
echo -e "Squeezing repeating special characters..."
find "$target" -depth | while IFS= read -r -d '' i; do

	original_name=$(basename "$i")
	dirname=$(readlink -f "$i" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(echo -e "$original_name" | tr --squeeze-repeats '[:punct:]')

	if [ "$new_name" != "$original_name" ]; then
		mv -v -T --backup=t "$i" "$dirname"/"$new_name"
	fi

done
}









function_rename_mv_tildes () {
# mv --backup=t renames existing files as "<filename>.~1~" the DOT there makes the 1, even after removing the tildes (~), appear like a file EXTENSION to the program. See if there's an easy way to make this happen without the DOT. - Create a function that finds files that have "*.~*~", and removes the part after the last dot, and takes the number and adds it in front of the removed dot (for directories), and in front of the last dot BEFORE the removed dot (for files)   | mv --backup --suffix doesn't work, it only works for SIMPLE method in suffixes.  Add function to find occurences of string "~<number>~" turn them into _<thatsamenumber>
# Thanks to "Byte Commander" for this function's file rename portion: https://unix.stackexchange.com/questions/371375/mv-add-number-to-file-name-if-the-target-exists
echo -e "Renaming all tilde extensions from FILES resulting from mv conflicts..."
find "$target" -depth -type f -a -iname "*.~*~" -print0 | while IFS= read -r -d '' i; do

	original_name=$(basename "$i")
	dirname=$(readlink -f "$i" | sed 's/\(^.*\)\/.*$/\1/')
	
	#cd "$dirname" && rename 's/((?:\..+)?)\.~(\d+)~$/_$2$1/' "$original_name" && cd -
	rename 's/((?:\..+)?)\.~(\d+)~$/_$2$1/' "$dirname"/"$original_name"

done



echo -e "Removing all tilde characters from DIRECTORIES resulting from mv conflicts..."
find "$target" -depth -type d -a -iname "*.~*~" -print0  | while IFS= read -r -d '' i; do

	original_name=$(basename "$i")
	dirname=$(echo "$i" | sed 's/\(^.*\)\/.*$/\1/')
	new_name=$(echo "$original_name" | sed 's/\~//g')

	if [ "$new_name" != "$original_name" ]; then
		mv -v -T --backup=t "$i" "$dirname"/"$new_name"
	fi

done
}









function_split_eight(){ echo "$1" | cut -c "$2"- 2>/dev/null | sed -r 's/(.{8})/\1\n/g' ; }

function_check_for_date () {
	# function_check_for_date takes a file or directory path as ARGUMENT $1
	# This function doesn't rename files, just searches for a valid date within the file name and prints it out if it finds one.

targetfile="$1"

original_path=$(readlink -f "$targetfile")
original_basename=$(basename "$targetfile")

# First of all, check if the first 8 characters of the filename already constitude a date, and if they do, print those and quit the rest of the function:
if  date -d $(echo ""$original_basename"" | head -c 8) &> /dev/null ; then
	file_date=$(echo ""$original_basename"" | head -c 8)
	echo "$file_date"
	return 0
fi

# By extracting only the numbers from the filename, we eliminate any variety in naming such as YYYY-MM-DD or YYYY:MM:DD and so on, we leave only the numbers, so that it becomes YYYYMMDD and judge by that.
only_digits=$(echo "$original_basename" | sed 's/[^0-9]*//g')

# We judge the remaining string of numbers to see whether it has 19XX or 20XX as YYYY, and the rest accordingly:
[[ "$only_digits" =~ (19[0-9][0-9]|20[0-2][0-9])(0[1-9]|1[0-2])(0[1-9]|[1-2][0-9]|3[0-1]) ]]

# If there indeed IS a date SOMEWHERE in the string,
if [[ $? -eq 0 ]]; then

	# If the string is greater than 8 chacaters,
	if [[ $(echo -e "$only_digits" | wc -m) -ge 8 ]]; then
		
		# Split the string into lines of 8 characters, and apply operations to each 8 - we will later break the loop on the first detection of a valid date, as we dont want multiple matches.
		for (( i=0 ; i <= 8 ; i++ )) ; do function_split_eight "$only_digits" "$i" ; done | grep -v "^$" |  grep -x '.\{8\}' | while read line; do
			
			# within the loop, if $line is a valid date,
			if date -d "$line" &> /dev/null; then 
			
			# This part commented out is assuming this function wants to actually rename the target file with a new one; it differentiates between a filename that has nothing left after cutting out the date and one that doesnt. Perhaps move this out to make things more modular?
				# (Remember, $original_path is already determined beforehand, that's why its not here below)

				#original_dirname=$(echo ""$original_path"" | sed 's/\(^.*\)\/.*$/\1/')
				#original_basename_sans_date=${original_basename/"$line"} # the sed here removes first (^) ONE character (.) and replaces it with NOTHING (//)
				
				#if ! [ -z "$original_basename_sans_date" ]; then
				#	new_name=$(echo ""$line"_"$original_basename_sans_date"")
				#else
					#new_name=$(echo ""$line""$original_basename_sans_date"")
				#fi
				
						#if [ "$new_name" != "$original_basename" ]; then
							#mv -v -T --backup=t "$original_path" "$dirname"/"$new_name"
						#fi
				file_date=$(echo "$line")
				echo "$file_date"
				return 0

				# If there are multiple matches to the loop's conditions, say, a file is named testfile_20120312_25, any one of the results could be valid. So, we take the first one that's validated by the "date" program.
				break
			
			fi

		done

	else
		return 1
	fi

else
	return 1
fi
}
### /RENAMING #########################################################################################################



















### Media Files



















### IMAGES ############################################################################################################

# Find anything that's an image:
# echo -e "\n"$white"Looking for image files... "$yellow"[ BMP | GIF | JPG | PNG | RAW | TIFF ] "$grey"" 

# During these operations, we need to make sure we don't process files that already fit our desires for each operation. For instance, it makes to sense to rename a file to start with it's size values if it already has them.
# For this, we can modify find commands to NOT include certain criteria in its results. / You can use the negate (!) feature of find to not match files with specific names:
#	 find "$target" -type f ! -name '*numberxnumber' ! -name 'resolution*'
# The ! can be problematic in shell scripting sometimes, so the -not parameter is a very useful synonym to it:
# 	find "$target" -type f ! -name '*numberxnumber' -not -name 'resolution*'

# Also, the find commands -o flag stands for "or", while the -a flag stands for "and". Combined with escaped parantheses, using these is a good way to structure a find command with multiple criteria.

function_images_prepend_resolution () {
# Prepend image file names with their <WIDTH>x<HEIGHT>:
echo -e "\n"$white"Prepend image file names with their <WIDTH>x<HEIGHT>..."$grey""

find "$target" -depth -type f \( -iname \*.bmp -o -iname \*.gif -o -iname \*.jpg -o -iname \*.png -o -iname \*.raw -o -iname \*.tiff \) -a -not -iname '*[0-9][0-9]x[0-9][0-9]*' -print0 | while IFS= read -r -d '' i; do
#find "$target" -type f -print0 -iname \*.bmp -o -iname \*.gif -o -iname \*.jpg -o -iname \*.png -o -iname \*.raw -o -iname \*.tiff -exec exiftool "$i" | grep "Image Width" | awk -F':' '{ print $2 }' | sed 's/ //g'	

	dirname=$(readlink -f "$i" | sed 's/\(^.*\)\/.*$/\1/')
	original_name=$(basename "$i")
	image_width=$(exiftool "$i" | grep "Image Width" | head -n 1 | awk -F':' '{ print $2 }' | sed 's/ //g')
	image_height=$(exiftool "$i" | grep "Image Height" | head -n 1 | awk -F':' '{ print $2 }' | sed 's/ //g')

# Now, if any one of those size elements is NOT Non-Existent (if either one has a defined value), then we go ahead and rename them:
if [ ! -z "$image_height" ] && [ ! -z "$image_width" ]; then
	mv -v -T --backup=t "$i" ""$dirname"/"$image_width"x"$image_height"_"$original_name""
fi

done
}





function_images_prepend_date () {
# Prepend image file names with their creation dates:
echo -e "\n"$white"Prepending image file names with their creation dates..."$grey""

# Check out how, in the next line with the find command, we specify the files that do not include any dates:
# We do this with the '*[1|2][9|0][0-9][0-9][0-9][0-9][0-9][0-9]*' syntax. The first two [#|#] parts specify a string of numbers that first starts with either 1 or 2, as all dates relevant to digital archiving are going to be either from the 1st or 2nd millenium, and following that up with 9 or 0 for the second digit, as we're unlikely to run into many files from the 1800's in a digital archive.
find "$target" -depth -type f \( -iname \*.bmp -o -iname \*.gif -o -iname \*.jpg -o -iname \*.png -o -iname \*.raw -o -iname \*.tiff \) -a -not -name '*[1|2][9|0][0-9][0-9][0-9][0-9][0-9][0-9]*' -print0 | while IFS= read -r -d '' i; do


# Process the file's path:
dirname=$(readlink -f "$i" | sed 's/\(^.*\)\/.*$/\1/')
original_name=$(basename "$i")


# For each file that doesn't start with 19XX or 20XX, check if it has a date within it:
file_date=$(function_check_for_date "$i")


 if [[ ! -z "$file_date" ]]; then

 	# If it did have a date within, we got the date from the function so we rename accordingly:
 	mv -v -T --backup=t "$i" ""$dirname"/"$file_date"_"$original_name""

 else
	
	# If we didn't get the date from the function, we try to pull it from the metadata:
	
	# Filter out the colon (:) characters and determine year/month/date:
	image_date_year=$(exiftool "$i" | grep -i "Create Date" | head -n 1 | awk -F':' '{ print $2 }' | sed 's~[^[:alnum:]/]\+~~g')
	image_date_month=$(exiftool "$i" | grep -i "Create Date" | head -n 1 | awk -F':' '{ print $3 }' | sed 's~[^[:alnum:]/]\+~~g')
	image_date_day=$(exiftool "$i" | grep -i "Create Date" | head -n 1 | awk -F':' '{ print $4 }' | awk -F' ' '{ print $1 }' | sed 's~[^[:alnum:]/]\+~~g')

		#if [ "$image_date_year" = '' ] || [ "$image_date_month" = '' ] || [ "$image_date_day" = '' ]; then
		#	image_date_year=$(exiftool "$i" | grep -i "File Modification Date/Time" | head -n 1 | awk -F':' '{ print $2 }' | sed 's~[^[:alnum:]/]\+~~g')
		#	image_date_year=$(exiftool "$i" | grep -i "File Modification Date/Time" | head -n 1 | awk -F':' '{ print $3 }' | sed 's~[^[:alnum:]/]\+~~g')
		#	image_date_year=$(exiftool "$i" | grep -i "File Modification Date/Time" | head -n 1 | awk -F':' '{ print $4 }' | cut -d'' -f1 | sed 's~[^[:alnum:]/]\+~~g')
		#fi

	# If any one of those date elements is NOT Non-Existent (if either one has a defined value), then we go ahead and rename them:
	if [ ! -z "$image_date_year" ] || [ ! -z "$image_date_month" ] || [ ! -z "$image_date_day" ]; then
		mv -v -T --backup=t "$i" ""$dirname"/"$image_date_year""$image_date_month""$image_date_day"_"$original_name""
	fi

fi

done
# OR
#exiftool -r -d %Y%m%d_%H%M%S -ext "-testname<CreateDate" "$target"
#exiftool -r -d %Y%m%d_%H%M%S -ext "-testname<CreateDate" -overwrite_original "$target"
}






function_check_nominatim () {
# Ping nominatim.openstreemap.org to see if the site is available for GPS data conversion
echo -e "\n"$grey"Checking to see if "$yellow"nominatim.openstreemap.org "$grey"is up..."
sleep 0.5

if ping -c 1 nominatim.openstreemap.org &> /dev/null ; then
	# echo -e ""$grey"nominatim.openstreemap.org is "$green"UP!"$grey""
	status_nominatim="up"
	return 0
else
	echo -e ""$grey"nominatim.openstreemap.org is "$red"DOWN!"$grey""
	status_nominatim="down"
	return 1	
fi

}



function_images_prepend_location () {

# Quit the whole function if nominatim is down.
function_check_nominatim
if [ "$status_nominatim" = "down" ] ; then
	return 1
fi

echo -e "\n"$white"Prepeding images with their EXIF location names..."$grey""

find "$target" -depth -type f -iname \*.bmp -o -iname \*.gif -o -iname \*.jpg -o -iname \*.png -o -iname \*.raw -o -iname \*.tiff -print0 | while IFS= read -r -d '' i; do
	
	# Check if the GPS data we're seeking exists for each image within our scope:
	image_location_coordinates=$(exiftool "$i" | grep -i "GPS Position")

		if [ ! -z "$image_location_coordinates" ]; then
			#if the image's GPS coordinates DON'T NOT exist, then go ahead:
			# Process the file's path:
			dirname=$(readlink -f "$i" | sed 's/\(^.*\)\/.*$/\1/')
			original_name=$(basename "$i")

			# Get image's latitude/longtitude:
			image_location_latitude=$(exiftool -c "%.6f" "$i" | grep -i "GPS Latitude  " | awk -F ': ' '{ print $2 }' | awk -F ' ' ' { print $1 }')
			image_location_longitude=$(exiftool -c "%.6f" "$i" | grep -i "GPS Longitude  " | awk -F ': ' '{ print $2 }' | awk -F ' ' ' { print $1 }')

			# Convert latitude and longtitude to corresponding address:
				# Site to convert len/lat to address:
				# https://nominatim.openstreetmap.org/reverse.php?format=html&lat="$image_location_latitude"&lon="$image_location_longitude"
				# XML, HTML, or CSV?
			image_location_url="https://nominatim.openstreetmap.org/reverse.php?format=html&lat="$image_location_latitude"&lon="$image_location_longitude""
			image_location_cityname=$(curl -s "$image_location_url" | grep -i "data-position" | awk -F '"name">' '{ print $2 }' | awk -F ',' '{ print $1 }' | sed 's/ç/c/gI; s/ğ/g/gI; s/ı/i/gI; s/İ/I/gI; s/ö/o/gI; s/ş/s/gI; s/ü/u/gI; s/\ /_/g')
			#image_location_cityname=$(curl -s "$image_location_url" | grep -i "\"town\":" | awk -F ':' '{ print $2 }' | ascii2uni -a U)

			# Rename:
			if [ ! -z "$image_location_cityname" ]; then
				mv -v -T --backup=t "$i" ""$dirname"/"$image_location_cityname"_"$original_name""
			fi
		fi

done
}



function_images_prepend_device () {
echo -e "\n"$white"Prepending images with device name data..."$grey""
sleep 1

find "$target" -depth -type f -iname \*.bmp -o -iname \*.gif -o -iname \*.jpg -o -iname \*.png -o -iname \*.raw -o -iname \*.tiff -print0 | while IFS= read -r -d '' i; do
	
	# Check if device data is available:
	image_device_name=$(exiftool "$i" | grep -i "Camera Model Name" | cut -d: -f 2 |  sed ':a;N;$!ba;s/\n/_/g' | sed 's~[^[:alnum:]/]\+~~g' | tr [:upper:] [:lower:])

	if [ ! -z "$image_device_name" ]; then
		# Process the file's path:
		dirname=$(readlink -f "$i" | sed 's/\(^.*\)\/.*$/\1/')
		original_name=$(basename "$i")
	
		mv -v -T --backup=t "$i" ""$dirname"/"$image_device_name"_"$original_name""
	fi

done
}



function_images_remove_exif () {
# Finally, remove all the EXIF data from the images for anonymity in your archive.
# Do not put any other characters outside of the variables within the function, so even if image_width isn't written in EXIF, it just becomes "", and doesn't affect the file's name.

echo -e "\n"$white"Stripping EXIF data from images..."$grey""
find "$target" -depth -type f -iname \*.bmp -o -iname \*.gif -o -iname \*.jpg -o -iname \*.png -o -iname \*.raw -o -iname \*.tiff -print0 | while IFS= read -r -d '' i; do

	dirname=$(readlink -f "$i" | sed 's/\(^.*\)\/.*$/\1/')
	original_name=$(basename "$i")

	mogrify -strip "$dirname"/"$original_name"

done

# ADD TO UPPER LINE for error logging: || echo "There's been problems deleting EXIF data from images." | tee -a "$logfile" # OR you can also use error output redirection with &>2 or something.
echo -e "\n"$grey"["$green"+"$grey"]::EXIF data stripped from all images in "$target"."
}

### /IMAGES ###########################################################################################################



















### MUSIC #############################################################################################################

# How this functions:
# Use function_find_music to dind all music files under target path
# Calculate total file size, make sure tempfs is large enough,
# Use OCD's static beets config file,
# Create a new library for current operation,
# Use beet with configuration to copy all files specified with the find loop into Temp directory with their new names, ready for their final form!
# Anything not handled by the autotagget will be logged.
	# Later parse the log file to learn which files were skipped, and:
		# Try the FromFilename plugin to guess tags from the filenames
		# Try the AcoustID plugin to use acousting fingerprinting to find information for arbitrary audio,
		# Apply some of OCD's functions to this files to do the least, like the renaming scheme specified in OCD's beets config.






# Find all MUSIC:
function_find_music () {
# function_find_music takes FILE NUMBER as $ARGUMENT1 - You can use this to create multiple lists with the specifying number you enter.
file_number="$1"
echo -e ""$white"Looking for music files... "$dark_grey"[ AAC | ALAC | AIFF | FLAC | M4A | MP3 | OGG | WMA | WAV ]"$grey"" 
find "$target" -depth -type f -iname \*.aac -o -iname \*.alac -o -iname \*.aiff -o -iname \*.flac -o -iname \*.m4a -o -iname \*.mp3 -o -iname \*.ogg -o -iname \*.wma -o -iname \*.wav > "$launch_dir"/Temp/file_list_music"$file_number".tmp
}





### BEETS ###
# Calling itself a "media library management system for obsessive-compulsive music geeks", beets is a very useful tool for music archive organizing.
# OCD uses beets with pre-defined configs that are set in accordance with OCD's accepted understanding of universal file storage rules. So for instance, OCD sets Beets to rename music files with all-lowercase filenames, rather than the default behavior where capital characters would be used where needed and so on.

function_beets () {
# beet [global args] COMMAND [command-specific args] DIRECTORY (or file)

#https://beets.readthedocs.io/en/v1.4.7/
#https://beets.readthedocs.io/en/latest/reference/config.html
#https://beets.readthedocs.io/en/v1.4.7/reference/pathformat.html
#https://beets.readthedocs.io/en/v1.4.7/reference/cli.html#move
#https://beets.readthedocs.io/en/v1.4.7/guides/tagger.html
#https://beets.readthedocs.io/en/v1.3.17/plugins/badfiles.html

# PLUGINS used:
	# Below each plugin for beet you can find a brief explanation of what the plugin does, taken from beets' online documentation at https://beets.readthedocs.io/en/v1.3.17/plugins/index.html

	# Fromfilename plugin:
	# The fromfilename plugin helps to tag albums that are missing tags altogether but where the filenames contain useful information like the artist and title. When you attempt to import a track that’s missing a title, this plugin will look at the track’s filename and guess its track number, title, and artist. These will be used to search in MusicBrainz and match track ordering.
	# Scrub plugin:
	# The scrub plugin lets you remove extraneous metadata from files’ tags. If you’d prefer never to see crufty tags that come from other tools, the plugin can automatically remove all non-beets-tracked tags whenever a file’s metadata is written to disk by removing the tag entirely before writing new data. The plugin also provides a command that lets you manually remove files’ tags.
	# Chroma plugin:
	# Uses the Chromaprint open-source fingerprinting technology to fingerprint unkonwn files by their audio, but it's disabled by default. That's because it's sort of tricky to install. See the :doc:`/plugins/chroma` page for a guide to getting it set up. This plugin uses an open-source fingerprinting technology called Chromaprint and its associated Web service, called Acoustid.



# CONFIG STAGE:
	# The paths: section of the config file lets you specify the directory and file naming scheme for your music library.
		# %asciify (asciify_paths option in the config file - same as wrapping the whole line in config in %asciify{} )
		# %lower{text}: Convert text to lowercase.
		# %title{text}: Convert text to Title Case.

		# Beets has a few “global” flags that affect all commands. These must appear between the executable name (beet) and the command—for example, beet -v import ....
		# -l LIBPATH: specify the library database file to use.
		# -c FILE: read a specified YAML configuration file. This configuration works as an overlay: rather than replacing your normal configuration options entirely, the two are merged. Any individual options set in this config file will override the corresponding settings in your base configuration.
		# -d DIRECTORY: specify the library root directory.

	# Define beets configuration file for OCD's current operation:
	beets_config_file="$launch_dir"/Config/ocd_beets_config.yaml
	beets_log_file=""$launch_dir"/Log/"$process_date"_ocd_beets.log"
	beets_library_file=""$launch_dir"/Temp/"$process_date"_ocd_beets_library.db"

	# Define the key-value pair to enter the "library:" line in beets' config file:
	#beet_library_line="library: "$launch_dir"/Temp/library.db"

	# Insert the library line into the config's first line, where the line resides:
	#sed -i "1s/.*/$beets_library_line/" "$beet_config_file"


function_find_music 1


# Calculate the size of all music files and create a Tempfs with an accomodating size:
#tempfs_size=$(du -c "$music_files_list" | tail -1 | cut -f 1)
#tempfs_dir="/dev/shm/Music" #change this to a dynamically created directory within /Temp later on.

# Line to create tempfs:
#<Line>



# IMPORT STAGE:
# Read from the list of music files, replacing NEWLINES with NULL characters, apply loop:
cat "$launch_dir"/Temp/file_list_music1.tmp | tr "\n" "\0" | while IFS= read -r -d '' i; do
	# -a, (--autotag)         infer tags for imported files (default)
	# -i (--incremental) If you want to import only the new stuff from a directory, use the -i option to run an incremental import. With this flag, beets will keep track of every directory it ever imports and avoid importing them again. This is useful if you have an “incoming” directory that you periodically add things to. To get this to work correctly, you’ll need to use an incremental import every time you run an import on the directory in question—including the first time, when no subdirectories will be skipped. So consider enabling the incremental configuration option.
	# -s (--singleton) The importer typically works in a whole-album-at-a-time mode. If you instead want to import individual, non-album tracks, use the singleton mode by supplying the -s option.

	# Import the music in target path using the custom config file, import the files into the library (without copy or move enabled, as specified in the config file), do it quietly, log:
	beet --config="$beets_config_file" --library="$beets_library_file" --directory="$(readlink -f "$i" | sed 's/\(^.*\)\/.*$/\1/')" import --quiet --log="$beets_log_file" "$i"
		#beet --config="$beets_config_file" --library="$beets_library_file" --directory="$tempfs_dir" import --quiet --log="$beets_logfile" "$target"
done


# DAMAGE CONTROL from reading logs:
	if [ $(cat "$beets_log_file" | grep -i "error") ]; then
		function_print_error "There have been some errors with beets. You can check the logfile at: "$beets_log_file"."
		#echo -e ""$grey"["$grey"!"$grey"]::Applying some basic operations to files that weren't imported."

		#Change of plans. Leaving this function as it is for now, but when Beets is run with the MOVE option enabled (as it is currently, then all files that are acted on are MOVED to the target directory - so if you want to act on the ones that were skipped by beets, all you need to do is to run a search on the original directory a second time.)
		#function_find_music 2

		# Apply a loop to whatever's left:
		#cat "$launch_dir"/Temp/file_list_music2.tmp | tr "\n" "\0" | while IFS= read -r -d '' i; do
			#mv 

	fi


	rm "$beets_library_file"

}

### /MUSIC ############################################################################################################



















### EXECUTING FUNCTIONS ###############################################################################################

# Pre-operation checks:
function_dependency_check


# Intro:
function_intro

sleep 0.5

function_setup_log



### TARGET PARSING (PART 2) ###########################################################################################

if [ "$mode" = "batch" ]; then


	# Check if target has been input:
	if [ "$input" = "" ]; then
		echo "You must supply OCD with a file or directory path."
		function_print_error "The correct syntax is: "$red"ocd /home/user/mydirectory/ "$grey"or "$red"<List of files> | ocd"$dark_yellow" [EXAMPLE: find /home/foo/Desktop/ -type f -name testfile* | ocd ]"$grey""
		function_exit_1
	else
		target=$(readlink -f "$input") 
	fi




	function_target_fail_check () {
	# Check that argument 1 (the target path) is indeed a directory or file, and not a symlink or anything like that.
	if [ ! -d "$target" ] && [ ! -f "$target" ]; then

		if [ "$mode" = "batch" ]; then
			function_print_error ""$yellow""$target" "$white"is not a file or a directory. OCD will now attempt to auto-determine your target path."
			sleep 1
			target="$(dirname "$target")/"$target""
			echo -e "\nCurrent target path set as: "$target"."
			
			echo -e "Do you want to change it "$grey"["$bold_white"Y"$grey"/"$red"N"$grey"]?"
			read -r -p "" response
				case "${response}" in
				    [yY][eE][sS]|[yY]) 
					echo -e "Please enter the absolute target path and press [ENTER]:"
					read target
					function_target_fail_check
				esac
					function_print_error "Quitting."
					function_exit_1
		else
			function_print_error ""$yellow""$target" "$white"is not a file or a directory. Quitting." ; function_exit_1
		fi
	fi
	}
	function_target_fail_check



	# Permissions: Check if OCD is permitted to access the file(s) / directories specified:
	if [[ ! $(namei -l "$target" | tail -n 1 | grep -i "$username") ]] && [ "$username" != "root" ]; then
		function_print_error "OCD doesn't have permissions to access the target specified."
		echo -e ""$grey"["$white"!"$grey"]::Please check permissions or run ocd as "$red"root "$dark_grey"(dangerous)"$grey""
		function_exit_1
	fi



# EXECUTION:

	# Optional settings:
	function_make_backup
	function_choose_operations

	if [[ $(echo "$chosen_operations" | grep '\b0\b' 2>/dev/null) ]]; then
	function_print_help
	function_exit_0
	exit 0
	fi

	sleep 0.5

	# Junk removal:

	if [[ $(echo "$chosen_operations" | grep '\b1\b' 2>/dev/null) ]]; then
	function_delete_empty_directories | function_log
	function_prompt
	fi



	if [[ $(echo "$chosen_operations" | grep '\b2\b' 2>/dev/null) ]]; then
	function_delete_duplicate_files | function_log
	function_prompt
	fi



	if [[ $(echo "$chosen_operations" | grep '\b3\b') ]]; then
	function_delete_broken_symlinks | function_log
	function_prompt
	fi





	# Renaming:

	if [[ $(echo "$chosen_operations" | grep '\b4\b') ]]; then
	function_rename_whitespace_to_underscore | function_log
	function_prompt
	fi



	if [[ $(echo "$chosen_operations" | grep '\b5\b') ]]; then
	function_rename_illegal_chars | function_log
	function_prompt
	fi


########
	if [[ $(echo "$chosen_operations" | grep '\b6\b') ]]; then
	function_rename_special_initials | function_log
	fi



	if [[ $(echo "$chosen_operations" | grep '\b7\b') ]]; then
	function_rename_filenames_to_lowercase | function_log
	function_prompt
	fi

		

	if [[ $(echo "$chosen_operations" | grep '\b8\b') ]]; then
	function_rename_accent_to_global | function_log
	function_prompt
	fi

		

	if [[ $(echo "$chosen_operations" | grep '\b9\b') ]]; then
	function_rename_directories_to_capital | function_log
	function_prompt
	fi

		

	if [[ $(echo "$chosen_operations" | grep '\b10\b') ]]; then
	function_rename_add_extension | function_log
	function_prompt
	fi

		

	if [[ $(echo "$chosen_operations" | grep '\b11\b') ]]; then
	function_rename_extensions_to_lowercase | function_log
	function_prompt
	fi

		

	if [[ $(echo "$chosen_operations" | grep '\b12\b') ]]; then
	function_rename_squeeze_repeating_special_characters | function_log
	function_prompt
	fi



	if [[ $(echo "$chosen_operations" | grep '\b13\b') ]]; then
	function_rename_user_bad_combos | function_log
	function_prompt
	fi


	# (Number 14 is at the bottom)




	# Images:

	if [[ $(echo "$chosen_operations" | grep '\b15\b') ]]; then
	function_images_prepend_resolution | function_log
	function_prompt
	fi

		

	if [[ $(echo "$chosen_operations" | grep '\b16\b') ]]; then
	function_images_prepend_location | function_log
	function_prompt
	fi

		

	if [[ $(echo "$chosen_operations" | grep '\b17\b') ]]; then
	function_images_prepend_device | function_log
	function_prompt
	fi

		

	if [[ $(echo "$chosen_operations" | grep '\b18\b') ]]; then
	function_images_prepend_date | function_log
	function_prompt
	fi

		

	if [[ $(echo "$chosen_operations" | grep '\b19\b') ]]; then
	function_images_remove_exif | function_log
	function_prompt
	fi



	# Music:

	if [[ $(echo "$chosen_operations" | grep '\b20\b') ]]; then
	function_beets | function_log
	fi





	# Finalizing:

	if [[ $(echo "$chosen_operations" | grep '\b14\b') ]]; then
	function_rename_mv_tildes | function_log
	fi


	# Exit:
	echo -e "\n"$grey"["$green"+"$grey"]::Done!"
	echo -e ""$green"Thank you for using OCD. Exiting."$white""
	function_exit_0


fi






if [ "$mode" = "piped" ]; then

    while read -r line ; do
		input="$line"



		# Check if target has been input:
		if [ "$input" = "" ]; then
			echo -e "You must supply OCD with a file or directory path."
			continue
		else
			target=$(readlink -f "$input") 
		fi



		# Check that argument 1 (the target path) is indeed a directory or file, and not a symlink or anything like that.
		if [ ! -d "$target" ] && [ ! -f "$target" ]; then
			continue
		fi



		# Permissions: Check if OCD is permitted to access the file(s) / directories specified:
		if [[ ! $(namei -l "$target" | tail -n 1 | grep -i "$username") ]] && [ "$username" != "root" ]; then
			 echo -e "OCD doesn't have permissions to access the target specified."
			continue
		fi



# EXECUTION:


		# Optional settings:
		function_make_backup
		function_choose_operations

		sleep 0.5

		# Junk removal:

		if [[ $(echo "$chosen_operations" | grep '\b1\b' 2>/dev/null) ]]; then
		function_delete_empty_directories | function_log
		function_prompt
		fi



		if [[ $(echo "$chosen_operations" | grep '\b2\b' 2>/dev/null) ]]; then
		function_delete_duplicate_files | function_log
		function_prompt
		fi



		if [[ $(echo "$chosen_operations" | grep '\b3\b') ]]; then
		function_delete_broken_symlinks | function_log
		function_prompt
		fi




		# Renaming:

		if [[ $(echo "$chosen_operations" | grep '\b4\b') ]]; then
		function_rename_whitespace_to_underscore | function_log
		function_prompt
		fi



		if [[ $(echo "$chosen_operations" | grep '\b5\b') ]]; then
		function_rename_illegal_chars | function_log
		function_prompt
		fi



		if [[ $(echo "$chosen_operations" | grep '\b6\b') ]]; then
		function_rename_special_initials | function_log
		fi



		if [[ $(echo "$chosen_operations" | grep '\b7\b') ]]; then
		function_rename_filenames_to_lowercase | function_log
		function_prompt
		fi

			

		if [[ $(echo "$chosen_operations" | grep '\b8\b') ]]; then
		function_rename_accent_to_global | function_log
		function_prompt
		fi

			

		if [[ $(echo "$chosen_operations" | grep '\b9\b') ]]; then
		function_rename_directories_to_capital | function_log
		function_prompt
		fi

			

		if [[ $(echo "$chosen_operations" | grep '\b10\b') ]]; then
		function_rename_add_extension | function_log
		function_prompt
		fi

			

		if [[ $(echo "$chosen_operations" | grep '\b11\b') ]]; then
		function_rename_extensions_to_lowercase | function_log
		function_prompt
		fi



		if [[ $(echo "$chosen_operations" | grep '\b12\b') ]]; then
		function_rename_squeeze_repeating_special_characters | function_log
		function_prompt
		fi

			

		if [[ $(echo "$chosen_operations" | grep '\b13\b') ]]; then
		function_rename_user_bad_combos | function_log
		function_prompt
		fi


		# (Number 14 is at the bottom)



		# Images:

		if [[ $(echo "$chosen_operations" | grep '\b15\b') ]]; then
		function_images_prepend_resolution | function_log
		function_prompt
		fi

			

		if [[ $(echo "$chosen_operations" | grep '\b16\b') ]]; then
		function_images_prepend_location | function_log
		function_prompt
		fi

			

		if [[ $(echo "$chosen_operations" | grep '\b17\b') ]]; then
		function_images_prepend_device | function_log
		function_prompt
		fi

			

		if [[ $(echo "$chosen_operations" | grep '\b18\b') ]]; then
		function_images_prepend_date | function_log
		function_prompt
		fi

			

		if [[ $(echo "$chosen_operations" | grep '\b19\b') ]]; then
		function_images_remove_exif | function_log
		function_prompt
		fi



		# Music:

		if [[ $(echo "$chosen_operations" | grep '\b20\b') ]]; then
		function_beets | function_log
		fi





		# Finalizing:

		if [[ $(echo "$chosen_operations" | grep '\b14\b') ]]; then
		function_rename_mv_tildes | function_log
		fi


		# Exit:
		echo -e "\n"$grey"["$green"+"$grey"]::Done!"
		continue

    done
	function_exit_0
fi
