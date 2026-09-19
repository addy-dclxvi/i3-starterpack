# Example: git_push_folder_to_all "src/components" "Update to all"
function git_push_folder_to_all -d "Copy a folder to all local branches, commit, and push"
	set -l target_folder $argv[1]
	set -l commit_message $argv[2]

	# 1. Check if the user provided a folder
	if test -z "$target_folder"
		echo (set_color red)"Error: Please specify a folder path."(set_color normal)
		echo "Usage: git_push_folder_to_all <folder_path> [commit_message]"
		return 1
	end

	# 2. Default commit message if none is provided
	if test -z "$commit_message"
		set commit_message "Update directory '$target_folder' across all branches"
	end

	# 3. Ensure the repository is clean so we don't accidentally mix other changes
	if not git diff-index --quiet HEAD --
		echo (set_color red)"Error: Your working directory is not clean."(set_color normal)
		echo "Please commit or stash your current changes before running this script."
		return 1
	end

	# 4. Save the name of the current branch so we can return to it later
	set -l original_branch (git branch --show-current)
	if test -z "$original_branch"
		echo (set_color red)"Error: You do not seem to be on any branch."(set_color normal)
		return 1
	end

	# 5. Get a list of all local branches
	set -l branches (git for-each-ref --format='%(refname:short)' refs/heads/)

	# 6. Loop through each branch
	for branch in $branches
		echo (set_color blue)"\n--- Switching to branch: $branch ---"(set_color normal)
		git checkout $branch

		# Grab the target folder from the original branch
		# This brings over all tracked files within the folder
		git checkout $original_branch -- "$target_folder"

		# Stage the entire folder
		git add "$target_folder"

		# Check if anything in the folder actually changed on this branch
		if not git diff --cached --quiet
			echo (set_color green)"Committing and pushing changes..."(set_color normal)
			git commit -m "$commit_message"
			
			# Push to origin (assumes your remote is named 'origin')
			git push origin $branch
		else
			echo (set_color yellow)"Folder is already up-to-date on this branch. Skipping."(set_color normal)
		end
	end

	# 7. Return to the starting branch
	echo (set_color blue)"\n--- Returning to original branch: $original_branch ---"(set_color normal)
	git checkout $original_branch
	
	echo (set_color green)"Done!"(set_color normal)
end
