# Check git version
git --version

#  initialize a folder in git
#  creates the .git folder inside this one
git init

#  inittialize git on windows
# "fatal: ambiguous argument 'HEAD': unknown revision or path not in the working tree"
git commit --allow-empty -n -m "Initial commit"

# show the .git hidden folder
get-childitem -Force

# clone a remote repository in current folder ( . )
git clone https://github.com/username/repo-name.git .

# clone a local repo
git clone repo1 repo2
# looking for remote repo / would show repo1 as the origin as we cloned from it
git remote -v
git remote show origin

# Set initial git configuration, give it username / password
# Can replace --global with --local to set values for a specific repo if required
git config --global --list  
git config --global user.name MY-USERNAME
git config --global user.email USER-EMAIL@GMAIL.COM

git config --list --show-origin

# adds all the changes in code to the git
git add .
# shows what files has been chagned without being commited
git status

# difference between staged and what is commited
git diff --cached 
# difference between current working code and staged
git diff
# difference between working code and last commit
git diff HEAD

# differences between one file in two branches
git diff branchA..branchB -- myfile.py

# HEAD is the last commited change in remote directory

# commit all added changed with a comment
git commit -m "Initial testfile.txt commit"

# mix git add and commit
git commit -am "some comment"
git commit -a -m "some comment"

# change the message of last commit
git commit --amend
# add new files to staging but don't update the message
git commit --amend --no-edit

# add remote repository to local project
git remote add origin https://github.com/johnthebrit/gitplay1
# push to the remote referened as origin
git push -u origin main

# pull down remote changes
git pull
# specify where to pull from and branch
git pull origin main
# pull from all remotes, pulles down the changes and MERGES with a fast-forward
git pull --all

# git pull actually is doing two things
# to just get remote content
git fetch
# can be explicit
git fetch origin main

# how to make change to a repository
git pull
# do the changes in the code
git commit
git push

# difference between "git fetch" and "git pull"
# Git Fetch is the command that tells the local repository that there are changes available in the remote repository without bringing the changes into the local repository

# look at the full commit
git log
# look at the type
git cat-file -t <first 7 of the hash characters shown for the commit>
# look at the content
git cat-file -p <first 7 of the hash characters shown for the commit>

git log --oneline --graph --decorate --all

# get a list of all git commits
# A---B---C---D (master)
#      \
#       \-E---F (HEAD)
git log --reflog

# you create a new repo you can override the default initial branch
git init --initial-branch=main
git init -b main

# view all branches. * is current
git branch --list
# View remotes
git branch -r
# view all (local and remote)
git branch -a

# create a new branch pointing to where we are called branch1
git branch branch1
# go to another branch
git checkout branch1

# better move to new switch that is based around movement to separate commands
# switch only allows a branch to be specified. Checkout allows a commit hash (so could checkout a detached head)
git switch branch1

#To create and checkout in one step:
git checkout -c branch1

# push a branch to a remote.
# -u sets up tracking between local and remote branch. Allows argumentless git pull in future
git push -u <remote repo, e.g. origin> <branch name>

# Check which branch we are on
git branch

# see the changes between two branches
git diff main..branch1

# go back to main branch
git checkout main
git switch main

# when we are in main, we can merge changes from branch1 into merge
git merge --no-ff branch1

# delete a branch locally
git branch -d branch1
# then we can delete the remote branch
git push origin --delete branch1

# how to merge local branchA into master
git checkout master      # go to local master branch
git pull origin master   # update with remote
git merge branchA        # merge local branchA into local master
git push origin master   # push to remote

# git merge two local branchs branchA , branchB
# merge branchB into BranchA
git checkout branchA
git merge branchB

# clone an specific remote branch (not master/main)
git clone -b <branch> <remote_repo>
git clone -b branchA git@github.com:user/myproject.git

# git conflict => when in branch1 we have added two new commits, and in main branch we also have added a separate commit, and now we want to merge branch1 into main
git merge branch1  # this will show the error that we have a conflict between two repos, fix it by editing the file it tells us and conflicts have been marked
git add .
git commit -m "fixed the issue"
git merge branch1  # do it again and now it works

# Error => git merge is not possible because you have unmerged files
# remote branch was edited via browser, local branch was edited locally
git merge --abort
# to fix this
# we can pull the remote changes first, then merge
git fetch
git merge origin/master
# or
git pull origin master

# switch to different remote branch
git checkout remotes/origin/branchA

# delete a remote branch

# a: delete the local branch
git branch -d branchB
# b: push it to remote
git push origin --delete branchB

# git rebase
# Rebasing is the process of moving or combining a sequence of commits to a new base commit.
# From a content perspective, rebasing is changing the base of your branch from one commit to another making it appear as if you'd created your branch from a different commit
https://www.atlassian.com/git/tutorials/rewriting-history/git-rebase

# Rebase, for rebase we need to be on branch1 not main (unlike merge)
git switch branch1
# the rebase will be pushed to the end of the main branch, so it will look like we created branch1 from the latest commit in main
git rebase main
# fix the issues in the code and add them (if there are any)
git add .
git rebase --continue

# when remote branch has new changes you don't have, but you also have local changes remote doesnt have, use pull rebase
git pull --rebase
# rebase to 3 changes in the past
git rebase -i HEAD~3

# rebase with conflict
git checkout branchA
git rebase master  # CONFLICT (content): Merge conflict in ...,Failed to merge in the changes.
# fix the conflict in code editor
git add .
git status
# DO NOT commit in here!!
git rebase --continue
# in case of more errors
git rebase --skip

# combine multiple local commits before pushing to remote repo
git rebase -i HEAD~7  # squashing

# we have master and branches b1,b2. we change something in master branch, how to add them to the two branches?

# we have to be inside the branch that wants to be updated (rebased)
git checkout b1  
git fetch
git rebase origin/master
# option 2:
git checkout b1
git merge origin/master
git push origin b1

# change this:
# (commit 1) - master
#                 \-- (commit 2) - (commit 3) - demo
#                                                 \-- (commit 4) - (commit 5) - PRO

# to this:
# (commit 1) - master
#                 |-- (commit 2) - (commit 3) - demo
#                 \-- (commit 4) - (commit 5) - PRO

git checkout PRO
git rebase --onto master demo PRO  # we want to rebase: change base of PRO branch from demo to master
# this style
git rebase --onto newBase oldBase feature/branch

# shows changes between commits
git log -p

# difference between two commits
git diff <commit>..<commit>

# stage the removal (which will also delete from working directory)
git rm <file>
# to ONLY stage the remove (but not delete from working directory)
git rm --cached <file>
# could also just delete from working directory then "add" all changes
git add .
git commit -m "Removed file x"

# edit the file
vi testfile4.txt
# add and commit the change
git add testfile4.txt
git commit -m "adding testfile4.txt"
# see the change status
git status
# remove the file from staging and working directory
git rm testfile4.txt
git status # note the delete is staged
ls # its gone from stage AND my working
git commit -m "removed testfile4.txt"


# can reset individual files:
vi testfile.txt
# stage the change
git add testfile.txt
git status
# restore version in staged (to the last commit HEAD) but NOT working directory (local file)
git restore --staged testfile.txt
# restore working from stage
git restore testfile.txt
# restore to stage and working from last commit
git restore --staged --worktree testfile.txt
# full version but not required is to say from where by this is default anyway but could specify different
git restore --source=HEAD --staged --worktree testfile.txt

# remove all staged content. This is actually using --mixed which is default
git reset
# sets the staged to match the last commit, but doesn't change your working directory
git reset --hard

# go back to previous commit, move back 1 but do not change staging or working. could go back 2, 3 etc ~2, ~3
git reset HEAD~1 --soft
# reset by a specific commit ID
git reset <first x characters of commit> --soft
#  resets both commit and staging areas
git reset --mixed
# resets commit, staging and working directory, since there is no value, it just changes both staging and working directory to latest commit
git reset --hard
# set everything back one commit
git reset HEAD~1 --hard

# fix a merge conflict, "You are in the middle of a conflicted merge."
# Since your pull was unsuccessful then HEAD (not HEAD^) is the last "valid" commit on your branch
git reset --hard HEAD
# or
git merge --abort


# squash last n commits together
git reset --soft HEAD~2 &&
git commit -m "squashed commit"

# resetting remote branch back to a certain commit
git reset --hard <commit-hash> # first revert on local
git push -f origin master # then push it to remote


# create a tag at the current location
git tag v1.0.0
git tag v0.9.1 <previous commit>
git tag --list

# look at a commit that is tagged. Show gives information about an object:
git show v1.0.0
# there is also an annotated type which is a full object with its own message
git tag -a v0.0.1 <commit hash> -m "First version"
git show v0.0.1

# we see the TAG information AND then the commit it references
git cat-file -t v0.0.1
git cat-file -t v1.0.0

# tags have to be pushed to a remote origin for them to be visible there
git push --tag


# .gitignore, you can mention inside it what files NOT to include when commiting or pushing
vi .gitignore 

        # add *.log /debug/*

git add .
git commit -m "added ignore file"
git push


# undo pushed commits in git
git revert <commit_hash>  # this will only revert changes from this specific commit
git revert <oldest_commit_hash>..<latest_commit_hash> # revert all the changes between these two commits including the latest

# revert a merge commit that has already been pushed to remote
# In git revert -m, the -m option specifies the parent number. This is needed because a merge commit has more than one parent, and Git does not know 
# automatically which parent was the mainline, and which parent was the branch you want to un-merge
git log
# -m 1 indicates that you'd like to revert to the tree of the first parent prior to the merg
# <commit-hash> is the commit hash of the merge that you would like to revert
git revert <commit-hash> -m 1

git revert 8f937c6 -m 1
git push -u origin master

# How to add chmod permissions to file in Git
git update-index --chmod=+x path/to/file # add
git update-index --chmod=-x path/to/file # remove

# add remote origin with different ssh port (not the default 22)
git remote add origin ssh://user@host:1234/srv/git/example   # here on port 1234


# Pull Request
# when you are on a forked repo and want to have ability to pull/push 
git remote add upstream https://github.com/username/repo-name.git .
git fetch upstream
git merge upstream/main

# DownStream => you're downstream when you copy (clone, checkout, etc) from a repository. Information flowed "downstream" to you
# UpStream => you are pushing to upstream ("otherRepo" is still "upstream", where the information now goes back to)

# *** How to update feature-branch with master branch when still developing it? ***
# here we can also use merge or rebase, but instead of merging feature to master, we can merge master To feature branch and add it's changes to our branch. rebase will do same thing but will add all the different commits 
# of the master to our commits.

# Switch to remote branch on local machine
git branch -v -a
git switch -c test origin/test


# set git proxy
git config --global http.proxy http://proxy.mycorps.net:10443
git config --global https.proxy http://proxy.mycorps.net:10443
export ALL_PROXY=proxy.mycorps.net:10443

# How to modify existing, unpushed commit messages
# Amending the most recent commit message
git commit --amend
git commit --amend -m "New commit message"

# Changing the message of a commit that you've already pushed to your remote branch
git push <remote> <branch> --force
# or
git push <remote> <branch> -f


# ***** How to do a Diff in VS Code (Compare Files) *****
# 1. Right click the first file and "Select for Compare"
# 2. Right click on the second file and "Compare with Selected"
# 3. You should see the diff panel appear once you've completed these steps

# **** Run / Open VSCode from Mac Terminal *****
# Open Visual Studio Code
# Open the command pallette with 'Command + Shift + P'
# Type 'Shell' in command palette
# Select Shell Command: 'Install code in PATH'
# Now open your terminal type: $ code 

# **** Add Members to Project in GitLab *****
# Project -> add member
# Add project to the group, then all group members get added to the project
# Add new users to db engineering group, use the role besides "guest" to add user.
# Add people to this group: "Gitlab Database group"