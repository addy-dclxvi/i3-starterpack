# Example: git_push_file_to_all "path/to/your/file.txt" "Update file.txt for all"
# Note: If you omit the commit message, it will automatically default to "Update <filename> across all branches"
function git_push_file_to_all -d "Copy a file to all local branches, commit, and push"
	set -l target_file $argv[1]
	set -l commit_message $argv[2]

	# 1. Check if the user provided a file
	if test -z "$target_file"
		echo (set_color red)"Error: Please specify a file."(set_color normal)
		echo "Usage: git_push_file_to_all <file_path> [commit_message]"
		return 1
	end

	# 2. Default commit message if none is provided
	if test -z "$commit_message"
		set commit_message "Update $target_file across all branches"
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

		# Grab the target file from the original branch
		git checkout $original_branch -- "$target_file"

		# Stage the file
		git add "$target_file"

		# Check if the file actually changed on this branch
		if not git diff --cached --quiet
			echo (set_color green)"Committing and pushing changes..."(set_color normal)
			git commit -m "$commit_message"
			
			# Push to origin (assumes your remote is named 'origin')
			git push origin $branch
		else
			echo (set_color yellow)"File is already up-to-date on this branch. Skipping."(set_color normal)
		end
	end

	# 7. Return to the starting branch
	echo (set_color blue)"\n--- Returning to original branch: $original_branch ---"(set_color normal)
	git checkout $original_branch
	
	echo (set_color green)"Done!"(set_color normal)
end
