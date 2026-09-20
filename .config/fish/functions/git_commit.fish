# Usage: git_commit "Commit messages"
function git_commit --description 'Check unpulled changes, stage, commit, and push with fallback message'
	# 1. Fetch the latest updates from the remote repository safely
	git fetch --quiet 2>/dev/null
	
	# 2. Check if the local branch is behind its remote tracking branch
	set -l LOCAL (git rev-parse @ 2>/dev/null)
	set -l REMOTE (git rev-parse @{u} 2>/dev/null)
	set -l HAS_UPSTREAM $status

	if test $HAS_UPSTREAM -eq 0; and test "$LOCAL" != "$REMOTE"
		set -l BASE (git merge-base @ @{u})
		if test "$LOCAL" = "$BASE"
			echo "Aborting: There are unpulled changes on the remote repository."
			echo "Please run 'git pull' before committing."
			return 1
		end
	end

	# 3. Stage changes
	git add .
	if test $status -ne 0
		echo "Error: 'git add' failed."
		return 1
	end

	# 4. Check if there are actually staged changes to commit
	if not git diff --cached --quiet
		# 5. Handle commit message fallback
		set -l MSG "$argv"
		if test -z "$MSG"
			set MSG "Some updates"
		end

		# 6. Commit changes
		git commit -m "$MSG"
		if test $status -ne 0
			echo "Error: 'git commit' failed."
			return 1
		end
	else
		echo (set_color yellow)"No new changes to commit (they may already be committed). Proceeding to push..."(set_color normal)
	end

	# 7. Get current branch name
	set -l CURRENT_BRANCH (git branch --show-current)

	# 8. Interactive confirmation prompt
	read -l -P "Do you want to push to origin/$CURRENT_BRANCH? [y/N]: " CONFIRM
	switch $CONFIRM
		case Y y yes YES
			# 9. Push to remote with upstream fallback
			if test $HAS_UPSTREAM -ne 0
				echo "No upstream branch found. Creating remote branch and tracking..."
				git push --set-upstream origin "$CURRENT_BRANCH"
			else
				echo "Pushing to origin $CURRENT_BRANCH..."
				git push origin "$CURRENT_BRANCH"
			end
		case '*'
			echo "Push canceled. Your changes remain committed locally."
			return 0
	end
end
