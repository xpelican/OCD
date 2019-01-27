# **OCD**
Organized & Categorized Data

--------------------------------------------------------------------------------------------

## AUTHOR
Erim _"xpelican"_ Bilgin | https://linkedin.com/in/erim-bilgin

--------------------------------------------------------------------------------------------

![alt text](https://i.ibb.co/dfMGmfd/ocd-logo.png)

--------------------------------------------------------------------------------------------

## DEFINITION & PURPOSE
Many people enjoy sorting and storing all of their files in a more or less standardized format that makes it easy for them to sift through all of it to find what they need. Especially when browsing in a terminal where stepping into a new directory doesn't automatically show you the files within it, it's helpful if you have a standardized way of naming files that helps you more or less guess what a file's going to be named.

Across the many file systems and archiving structures out there, I was usually annoyed at how file names and structures would often be in incompatible formats (ie Files without extensions not working on Windows, files with convoluted, junk names, images with nondescriptive names that make them hard to distinguish their content on a terminal, and so on).

 When a user imports their say, camera images from their Android phone, downloaded web images from their iPad and artwork images from their laptop and wants to archive all of those images on their main archiving storage, each group of files would have different naming and strutcutre based on how their device names these images. OCD takes all the files, gives them a more unified format for naming and categorization, and makes them easier to integrate into any main backup systems you may have for further, proper archiving.

 Before starting out with this project, I've checked to see if there were any universally accepted standards for file naming that I could use as a guide to structure OCD around, and the closest I've found were the ISO 8601 for dates, and some rules for the ISO 9660 filesystem compatability issues, but nothing ultimately fit the bill, so I had to use common sense when making some decisions.

### **LIST OF CURRENTLY SUPPORTED OPERATIONS:**
##### JUNK REMOVAL:
###### - Recursively delete empty directories
###### - Delete duplicate files
###### - Delete broken symlinks

##### RENAMING:
###### - Rename whitespace characters to underscores
###### - Rename illegal and special characters
###### - Rename files starting with special characters other than dot (.)
###### - Rename all file names to lowercase
###### - Rename all directories to Title Case
###### - Rename all accented characters to similar English counterparts (Ç,Ö,Ş,Ü > C,O,S,U...)
###### - Add a .file extension to files without extensions
###### - Rename all uppercase extensions to lowercase
###### - Squeeze repeating special characters (!!! > !)
###### - Rename user-specified unwanted character combinations
###### - Remove tilde characters that may result from renaming operations (~1~ > 1)

##### IMAGE RENAMING:
###### - Prepend images with their resolution information
###### - Prepend images with the city name from their EXIF location data
###### - Prepend images with their EXIF device information
###### - Prepend images with their dates
###### - Remove EXIF data from images

##### MUSIC RENAMING:
###### - Use Beets to sort & tag music archive (Auto)

**IMAGES:**
On many devices, a user may not be able to view thumbnails or other visual means to find a specific image file they're looking for. Perhaps they can only see filenames and they want to have a rough estimate of the picture they want just from the filename. OCD structures images by reading EXIF data for dates, loations, device information, and resolutions, then renames image files in <YYYYMMDD><horizontal resolution>x<vertical resolution><image name>.<extension> format. (ex: 20180310_800x600_myphoto.jpg)

**MUSIC:**
Calling itself a "media library management system for obsessive-compulsive music geeks", [Beets](https://github.com/beetbox/beets) is a very useful tool for music archive organizing. OCD uses Beets with pre-defined configs that are set in accordance with OCD's accepted understanding of universal file storage rules. So for instance, OCD sets Beets to rename music files with all-lowercase filenames, rather than the default behavior where Title Case would be used where needed and so on. Due to the heavily changed configuration of Beets, this part of OCD is by far the least developed so far, so make sure you take some backups before and use this function with caution.

--------------------------------------------------------------------------------------------

## INSTALLATION & USE
OCD v1.0 has been tested on Ubuntu 18.04.

Assuming you're using an OS with the APT package manager, there's actually no need to install OCD. Just download the files, put the OCD folder under /opt/ (or, wherever you device to place it, change the path definition for the variable "launch_dir" to that path in line 440).

The accepted syntax is:
**ocd /path/to/directory/** *OR* **<command that outputs filenames> | ocd**

The target path specified can be relative or absolute.

You may need to install some dependencies that OCD needs to run - these are quite common programs for the most part. You can find all the dependencies listed in the first few commented lines of ocd.sh.

--------------------------------------------------------------------------------------------

## TESTING & DEVELOPMENT
You will notice three files in the OCD git that have to do with testing. These are:
	- reset_test_folders.sh
	- Test_Folder
	- Test_Folder.BKP

The way these work is simple. Test_Folder contains a set of files and directories with various types of names and content. You test OCD's performance by running it with the Test_Folder as the argument:

	ocd Test_Folder

And you can see how your current code handles the various file types you have within Test_Folder.

reset_test_folders.sh is a little script that you can run after each OCD test. The script replaces all the content of Test_Folder with that of the original structure, found in Test_Folder.BKP

Anytime we add a new function to OCD, we can create the kinds of sample files that emulate the kinds of files we have just set OCD to deal with. So for instance, when we start adding an ability to properly handle music files for archiving, we go to the Test_Folder.BKP directory, and create/copy a bunch of music files with example names and minimal content, so we can test the new ability on them. The trick is to make each file broken in at least one way that we're planning to fix, but not so broken that when something goes wrong, we're not sure what.

Once we're sure the Test_Folder.BKP directory is the way we want to run with our tests, we run the ./reset_test_folders.sh script again so all the changes we just made in Test_Folder.BKP get copied over to Test_Folder, and so we can do little tweaks in the code each time, and reset the Test_Folder directory to its originally intended format before we test again. Test_Folder.BKP is never touched by OCD, only Test_Folder is acted on, with the currently accepted state of .BKP staying useful as a backup point to revert to after each test.

In terms of actually adding code to OCD, I've tried to keep the code well-commented as much as possible to help out other people who were kind enough to consider contributing. Most of the functions are explained with a comment line the first time they appear in the code; so if a line seems complex and doesn't have a comment explaining what it does, try to find an earlier occurance of it within the program - chances are that one isn't the first time it's used in the code and the first occurance should hopefully include a comment to explain the reasoning behind it. When you do add to the code, please take care to add your own comments.

--------------------------------------------------------------------------------------------

## UPDATES
As mentioned in the opening paragraph, OCD is by no means complete or optimized - Not nearly! Therefore I more than welcome any more capable developers to come in and help improve it.

- Add more checks for user input at any point where it's asked.
- Right now, function_choose_operations allows you to define and save profiles, but doesn't allow you to load them. Add a check to flag "-o /user/dir/profilename.profile" or an option to choose from saved profiles in interactive mode.
- Add more accented characters to rename.
- Add more special characters to remove / Put all the removal of special characters operations into one operation.
- Add operation to change all non-ASCII names
- ISO 9660 standard requirement: Do not use path or file names that correspond to operating system specific names, such as: AUX, COM1, CON, LPT1, NUL, PRN
- Make a function to shorten file names longer than 64 characters.
- Currently, OCD renames all "unwanted" characters to an underscore. I added a function to read a config file under "$launch_dir"/Config/ocd.cfg that reads a variable called "$default_seperator" - the plan is to eventually make it so that changing this character makes OCD switch unwanted characters to this character instead of the default underscore. (Make sure to also add checks to that function: allow no more than a single adjacent occurance of the character, don't allow certain characters, add escapes for certain characters, etc.)
- Find and rename "junk" character bunches in filenames (like image_adk3r9i3faknkaslc392d_32qfdka.jpg or something; not sure how to differentiate this yet - Should be somewhat CPU intensive though.)
- For image operations, consider implementing open-source Image Content Analysis tools to write a few words on images
- Currently, any operations chosen by the user get run one after another, writing and overwriting files with each operation. This creates a lot of disk activity, which isn't good for protecting disks from wear. Future plans include changing this core modus operandi of OCD with a RAM-based "database" approach - wherein every file name under the target (assuming target is a directory with lots of files under it) is read and written into a dynamic database that OCD keeps on the RAM, then any changes made by the operations applied to the entries within this database, making the appropriate changes with each operation, then finally changing the filenames to their ultimate new names in a single elegant disk write for each file, instead of several for each chosen function. Currently, I was a bit too comfortable with the ways of mv to apply this. | A different way to implement this could be to create a temporary filesystem on the RAM, copy the entire target directory there, and apply operations on there, then finally replacing the RAM-based tempfs directory with the original target path - however this approach assumes the user has a lot of physical RAM accessible, as otherwise the tempFS would only end up using a lot of swap memory, which defeats the aim of reducing disk activity.
- Port the code over to a more portable and efficient language.

--------------------------------------------------------------------------------------------

## DISCLAIMER
This is my first project of this kind. It's easy for me to remain extremely humble about it - since I'm very inexperienced when it comes to writing this sort of code, many of the techinques and structures I used coding OCD were learned from various places on the internet and advice from friends. So please feel free to criticize, change, or improve OCD in any way you deem fit in your forks. Thank you, and remember; there's nothing inherently bad about having a little OCD! :)

--------------------------------------------------------------------------------------------
