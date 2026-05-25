# Git Commands Tutorial

This tutorial turns the Git command notes into a practical guide. It covers setup, cloning, staging, commits, remotes, branches, merges, rebases, resets, tags, `.gitignore`, forks, and common maintenance tasks.

## Check Your Git Version

```bash
git --version
```

## Create a New Repository

Initialize Git inside the current directory:

```bash
git init
```

This creates a hidden `.git` directory that stores repository history and metadata.

On Linux or macOS, show hidden files:

```bash
ls -la
```

On Windows PowerShell, show hidden files:

```powershell
Get-ChildItem -Force
```

Create a repository with `main` as the initial branch:

```bash
git init --initial-branch=main
```

Short form:

```bash
git init -b main
```

If a brand-new repository has no commits yet and a tool complains that `HEAD` does not exist, create an initial empty commit:

```bash
git commit --allow-empty -m "Initial commit"
```

## Clone a Repository

Clone a remote repository into the current directory:

```bash
git clone https://github.com/username/repo-name.git .
```

Clone a local repository:

```bash
git clone repo1 repo2
```

After cloning, view the configured remote:

```bash
git remote -v
git remote show origin
```

## Configure Git Identity

Set your Git username and email. These values are used in commits. They are not your Git password.

```bash
git config --global user.name "MY-USERNAME"
git config --global user.email "USER-EMAIL@GMAIL.COM"
```

View global configuration:

```bash
git config --global --list
```

Show all Git config values and where they came from:

```bash
git config --list --show-origin
```

Use `--local` instead of `--global` to configure only the current repository:

```bash
git config --local user.name "MY-USERNAME"
git config --local user.email "USER-EMAIL@GMAIL.COM"
```

## Stage and Check Changes

Stage all changed files:

```bash
git add .
```

Show repository status:

```bash
git status
```

Useful diffs:

| Command | Shows |
| --- | --- |
| `git diff` | Working tree changes that are not staged |
| `git diff --cached` | Staged changes compared with the last commit |
| `git diff HEAD` | All working tree changes compared with the last commit |

Compare one file between two branches:

```bash
git diff branchA..branchB -- myfile.py
```

## Understand `HEAD`

`HEAD` usually points to the commit currently checked out in your local repository.

Most of the time, `HEAD` means "the latest commit on my current branch." It does not mean the latest commit on the remote server.

## Commit Changes

Commit staged changes:

```bash
git commit -m "Initial testfile.txt commit"
```

Stage modified and deleted tracked files, then commit them:

```bash
git commit -am "some comment"
```

Equivalent long form:

```bash
git commit -a -m "some comment"
```

Important: `git commit -am` does not add brand-new untracked files. Use `git add` first for new files.

## Amend the Last Commit

Change the last commit message:

```bash
git commit --amend
```

Change the last commit message directly:

```bash
git commit --amend -m "New commit message"
```

Add staged changes to the previous commit without changing its message:

```bash
git add path/to/file
git commit --amend --no-edit
```

Avoid amending commits that other people may already have pulled unless your team expects rewritten history.

## Add a Remote and Push

Add a remote named `origin`:

```bash
git remote add origin https://github.com/johnthebrit/gitplay1
```

Push the local `main` branch and set upstream tracking:

```bash
git push -u origin main
```

After upstream tracking is set, you can usually run:

```bash
git push
git pull
```

## Pull and Fetch

Pull changes from the current branch's upstream:

```bash
git pull
```

Pull from a specific remote and branch:

```bash
git pull origin main
```

Fetch remote commits without merging them into your current branch:

```bash
git fetch
```

Fetch a specific branch:

```bash
git fetch origin main
```

Fetch from all configured remotes:

```bash
git fetch --all
```

`git pull` is basically:

```bash
git fetch
git merge
```

or, when using rebase:

```bash
git fetch
git rebase
```

## `git fetch` vs `git pull`

| Command | What It Does |
| --- | --- |
| `git fetch` | Downloads remote commits, branches, and tags into your local repository but does not change your working branch |
| `git pull` | Fetches remote changes and then integrates them into your current branch |

Use `fetch` when you want to inspect remote changes before merging or rebasing.

## Basic Change Workflow

A common workflow:

```bash
git pull
# edit files
git add .
git commit -m "Describe the change"
git push
```

## Inspect History and Git Objects

Show full commit history:

```bash
git log
```

Show compact history with branch and tag decorations:

```bash
git log --oneline --graph --decorate --all
```

Show history including entries from the reflog:

```bash
git log --reflog
```

Inspect the type of a Git object:

```bash
git cat-file -t <commit-hash-prefix>
```

Inspect the content of a Git object:

```bash
git cat-file -p <commit-hash-prefix>
```

Show changes introduced by commits:

```bash
git log -p
```

Compare two commits:

```bash
git diff <commit1>..<commit2>
```

## Branches

List local branches:

```bash
git branch --list
```

List remote branches:

```bash
git branch -r
```

List local and remote branches:

```bash
git branch -a
```

Check which branch you are on:

```bash
git branch
```

The current branch is marked with `*`.

## Create and Switch Branches

Create a branch:

```bash
git branch branch1
```

Switch to that branch:

```bash
git switch branch1
```

Older equivalent:

```bash
git checkout branch1
```

Create and switch in one command:

```bash
git switch -c branch1
```

Older equivalent:

```bash
git checkout -b branch1
```

Note: `git checkout -c branch1` is not the normal command for creating a branch. Use `git checkout -b branch1` or `git switch -c branch1`.

## Push a Branch

Push a local branch to a remote and set upstream tracking:

```bash
git push -u origin branch1
```

After this, future `git pull` and `git push` calls can usually be run without extra arguments from that branch.

## Compare and Merge Branches

Compare two branches:

```bash
git diff main..branch1
```

Switch back to `main`:

```bash
git switch main
```

Older equivalent:

```bash
git checkout main
```

Merge `branch1` into the current branch:

```bash
git merge --no-ff branch1
```

If you are on `main`, this merges `branch1` into `main`.

## Delete Branches

Delete a local branch:

```bash
git branch -d branch1
```

Force-delete a local branch that has not been merged:

```bash
git branch -D branch1
```

Delete a remote branch:

```bash
git push origin --delete branch1
```

## Merge One Local Branch Into Another

Merge `branchA` into `master`:

```bash
git checkout master
git pull origin master
git merge branchA
git push origin master
```

Merge `branchB` into `branchA`:

```bash
git checkout branchA
git merge branchB
```

## Clone a Specific Branch

Clone a specific remote branch:

```bash
git clone -b <branch> <remote_repo>
```

Example:

```bash
git clone -b branchA git@github.com:user/myproject.git
```

## Merge Conflicts

A merge conflict happens when Git cannot automatically combine changes.

Start a merge:

```bash
git merge branch1
```

If Git reports a conflict:

1. Open the conflicted files.
2. Edit the conflict markers.
3. Stage the resolved files.
4. Complete the merge commit.

Commands:

```bash
git status
git add .
git commit -m "Resolve merge conflict"
```

Do not run the same `git merge branch1` again after committing the conflict resolution. The merge has already been completed by the merge commit.

Abort an in-progress merge:

```bash
git merge --abort
```

If a remote branch changed and your local branch also changed, first fetch or pull the remote changes:

```bash
git fetch
git merge origin/master
```

or:

```bash
git pull origin master
```

## Work with Remote Branches

See local and remote branches:

```bash
git branch -v -a
```

Create a local branch that tracks a remote branch:

```bash
git switch -c test --track origin/test
```

Shorter form when Git can infer the remote:

```bash
git switch test
```

Avoid this if you want to keep working normally:

```bash
git checkout remotes/origin/branchA
```

That checks out the remote-tracking branch directly and usually leaves you in detached `HEAD` state. Prefer creating a local tracking branch.

## Rebase Basics

Rebasing moves or replays commits onto a new base commit. It can make history look as if your branch was created from a newer point.

Learn more:

```text
https://www.atlassian.com/git/tutorials/rewriting-history/git-rebase
```

Rebase `branch1` onto `main`:

```bash
git switch branch1
git rebase main
```

If conflicts happen:

```bash
# fix files in your editor
git add .
git rebase --continue
```

If you need to stop the rebase:

```bash
git rebase --abort
```

Skip the current conflicting commit during a rebase:

```bash
git rebase --skip
```

Do not run `git commit` manually while resolving a rebase conflict. Use `git rebase --continue`.

## Pull with Rebase

When the remote branch has new commits and you also have local commits, you can pull with rebase:

```bash
git pull --rebase
```

This fetches remote changes, then replays your local commits on top.

## Interactive Rebase and Squashing

Interactively edit the last 3 commits:

```bash
git rebase -i HEAD~3
```

Squash the last 7 commits before pushing:

```bash
git rebase -i HEAD~7
```

Interactive rebase is best used before commits are pushed to a shared branch.

## Update a Feature Branch from `master`

Option 1: rebase the feature branch on top of the latest `master`:

```bash
git checkout b1
git fetch origin
git rebase origin/master
```

Option 2: merge latest `master` into the feature branch:

```bash
git checkout b1
git fetch origin
git merge origin/master
git push origin b1
```

Use rebase for a cleaner linear history. Use merge when you want to preserve the exact branch history or avoid rewriting commits.

## Rebase with `--onto`

Suppose history looks like this:

```text
(commit 1) - master
                \-- (commit 2) - (commit 3) - demo
                                                \-- (commit 4) - (commit 5) - PRO
```

You want `PRO` to branch from `master` instead of `demo`:

```text
(commit 1) - master
                |-- (commit 2) - (commit 3) - demo
                \-- (commit 4) - (commit 5) - PRO
```

Run:

```bash
git checkout PRO
git rebase --onto master demo PRO
```

General form:

```bash
git rebase --onto <new-base> <old-base> <branch>
```

## Remove Files from Git

Remove a file from Git and from the working directory:

```bash
git rm <file>
git commit -m "Remove file"
```

Stop tracking a file but keep it in your working directory:

```bash
git rm --cached <file>
git commit -m "Stop tracking file"
```

You can also delete a file manually, then stage the deletion:

```bash
rm <file>
git add .
git commit -m "Remove file"
```

Example:

```bash
vi testfile4.txt
git add testfile4.txt
git commit -m "Add testfile4.txt"
git rm testfile4.txt
git commit -m "Remove testfile4.txt"
```

## Restore Files and Unstage Changes

Edit and stage a file:

```bash
vi testfile.txt
git add testfile.txt
git status
```

Unstage a file without changing the working directory:

```bash
git restore --staged testfile.txt
```

Discard working directory changes for a file:

```bash
git restore testfile.txt
```

Restore both staging area and working tree from `HEAD`:

```bash
git restore --source=HEAD --staged --worktree testfile.txt
```

Shorter form:

```bash
git restore --staged --worktree testfile.txt
```

## Reset

Unstage all staged changes but keep working directory changes:

```bash
git reset
```

This is equivalent to a mixed reset to `HEAD`.

Soft reset back one commit. The commit is removed from history, but its changes remain staged:

```bash
git reset --soft HEAD~1
```

Soft reset to a specific commit:

```bash
git reset --soft <commit-hash>
```

Mixed reset. This moves `HEAD` and resets the staging area, but keeps working directory changes:

```bash
git reset --mixed <commit-hash>
```

Hard reset. This moves `HEAD`, resets the staging area, and discards working directory changes:

```bash
git reset --hard <commit-hash>
```

Hard reset back one commit:

```bash
git reset --hard HEAD~1
```

Warning: `git reset --hard` deletes uncommitted local changes. Use it only when you are sure you do not need those changes.

## Abort a Bad Merge

If you are in the middle of a conflicted merge:

```bash
git merge --abort
```

If the merge cannot be aborted and you want to return to the last valid commit:

```bash
git reset --hard HEAD
```

Use `git reset --hard HEAD` carefully because it discards uncommitted changes.

## Squash with Reset

Squash the last 2 commits into one new commit:

```bash
git reset --soft HEAD~2
git commit -m "Squashed commit"
```

## Reset a Remote Branch to a Previous Commit

First reset locally:

```bash
git reset --hard <commit-hash>
```

Then force-push:

```bash
git push --force-with-lease origin master
```

`--force-with-lease` is safer than `--force` because it refuses to overwrite remote work you have not fetched.

## Tags

Create a lightweight tag at the current commit:

```bash
git tag v1.0.0
```

Create a lightweight tag at a previous commit:

```bash
git tag v0.9.1 <previous-commit-hash>
```

List tags:

```bash
git tag --list
```

Show a tagged commit:

```bash
git show v1.0.0
```

Create an annotated tag:

```bash
git tag -a v0.0.1 <commit-hash> -m "First version"
```

Show the annotated tag:

```bash
git show v0.0.1
```

Inspect tag object types:

```bash
git cat-file -t v0.0.1
git cat-file -t v1.0.0
```

Push all tags:

```bash
git push --tags
```

Push one tag:

```bash
git push origin v1.0.0
```

## `.gitignore`

Create or edit `.gitignore`:

```bash
vi .gitignore
```

Example patterns:

```gitignore
*.log
debug/
```

Commit the ignore file:

```bash
git add .gitignore
git commit -m "Add gitignore file"
git push
```

If a file is already tracked, adding it to `.gitignore` will not stop Git from tracking it. Use:

```bash
git rm --cached <file>
```

## Revert Pushed Commits

Use `git revert` to undo committed changes without rewriting shared history.

Revert one commit:

```bash
git revert <commit-hash>
```

Revert a range of commits. This excludes the oldest commit and includes the latest:

```bash
git revert <oldest-commit-hash>..<latest-commit-hash>
```

To include the oldest commit too, use:

```bash
git revert <oldest-commit-hash>^..<latest-commit-hash>
```

## Revert a Merge Commit

A merge commit has more than one parent, so Git needs to know which parent is the mainline.

View history:

```bash
git log
```

Revert a merge commit using parent 1 as the mainline:

```bash
git revert -m 1 <merge-commit-hash>
```

Example:

```bash
git revert -m 1 8f937c6
git push origin master
```

`-m 1` usually means "keep the first parent branch and undo the merged-in branch."

## Track Executable Permission

Add executable permission in Git:

```bash
git update-index --chmod=+x path/to/file
```

Remove executable permission in Git:

```bash
git update-index --chmod=-x path/to/file
```

Commit the permission change:

```bash
git commit -m "Update executable permission"
```

## Add a Remote with a Custom SSH Port

If SSH uses a non-default port:

```bash
git remote add origin ssh://user@host:1234/srv/git/example
```

In this example, SSH connects on port `1234`.

## Forks, Upstream, and Pull Requests

When working from a fork:

| Remote | Meaning |
| --- | --- |
| `origin` | Your fork |
| `upstream` | The original repository you forked from |

Add the original repository as `upstream`:

```bash
git remote add upstream https://github.com/username/repo-name.git
```

Fetch upstream changes:

```bash
git fetch upstream
```

Merge upstream `main` into your current branch:

```bash
git merge upstream/main
```

Or rebase on upstream `main`:

```bash
git rebase upstream/main
```

Definitions:

| Term | Meaning |
| --- | --- |
| Downstream | A repository or branch that receives changes from another source |
| Upstream | The source repository or branch that changes flow from |

## Update a Feature Branch While Developing

To update a feature branch with latest `master` or `main`, switch to the feature branch first.

Merge approach:

```bash
git switch feature-branch
git fetch origin
git merge origin/main
```

Rebase approach:

```bash
git switch feature-branch
git fetch origin
git rebase origin/main
```

Merging adds a merge commit when needed. Rebasing replays your feature commits on top of the latest base branch.

## Git Proxy Configuration

Set HTTP and HTTPS proxy values:

```bash
git config --global http.proxy http://proxy.mycorps.net:10443
git config --global https.proxy http://proxy.mycorps.net:10443
```

Set a general proxy environment variable:

```bash
export ALL_PROXY=http://proxy.mycorps.net:10443
```

Unset proxy values:

```bash
git config --global --unset http.proxy
git config --global --unset https.proxy
unset ALL_PROXY
```

## Change Commit Messages

Change the most recent unpushed commit:

```bash
git commit --amend -m "New commit message"
```

If the commit has already been pushed, changing it requires a force push:

```bash
git push --force-with-lease origin <branch>
```

Avoid force-pushing shared branches unless your team agrees.

## Compare Files in VS Code

To compare two files in VS Code:

1. Right-click the first file and choose `Select for Compare`.
2. Right-click the second file and choose `Compare with Selected`.
3. Review the diff panel.

## Open VS Code from the Mac Terminal

In VS Code:

1. Open the command palette with `Command + Shift + P`.
2. Search for `Shell`.
3. Select `Shell Command: Install 'code' command in PATH`.

Then open VS Code from the terminal:

```bash
code .
```

## GitLab Project Members

Common GitLab member-management notes:

- Project members can be added from the project member settings.
- If a project belongs to a group, group members can be granted access through the group.
- Give users an appropriate role higher than `Guest` when they need to contribute.
- Add people to the correct group, such as a database engineering group, when group-level access is preferred.



## Quick Reference

| Task | Command |
| --- | --- |
| Check version | `git --version` |
| Initialize repo | `git init` |
| Initialize with `main` | `git init -b main` |
| Clone repo | `git clone URL` |
| Show remotes | `git remote -v` |
| Set username | `git config --global user.name "Name"` |
| Set email | `git config --global user.email "email@example.com"` |
| Stage all changes | `git add .` |
| Show status | `git status` |
| Show unstaged diff | `git diff` |
| Show staged diff | `git diff --cached` |
| Commit | `git commit -m "Message"` |
| Amend last commit | `git commit --amend` |
| Push and set upstream | `git push -u origin branch` |
| Pull | `git pull` |
| Fetch | `git fetch` |
| Show history graph | `git log --oneline --graph --decorate --all` |
| Create branch | `git switch -c branch` |
| Switch branch | `git switch branch` |
| Merge branch | `git merge branch` |
| Delete local branch | `git branch -d branch` |
| Delete remote branch | `git push origin --delete branch` |
| Rebase on main | `git rebase main` |
| Continue rebase | `git rebase --continue` |
| Abort rebase | `git rebase --abort` |
| Unstage file | `git restore --staged file` |
| Discard file changes | `git restore file` |
| Undo last commit, keep staged | `git reset --soft HEAD~1` |
| Hard reset | `git reset --hard commit` |
| Revert commit | `git revert commit` |
| Create tag | `git tag v1.0.0` |
| Push tags | `git push --tags` |
| Stop tracking file | `git rm --cached file` |


## Additional Git Concepts

## Merge vs Rebase

Both `git merge` and `git rebase` are used to bring changes from one branch into another, but they do it in different ways.

### Core Difference

| Command | What It Does |
| --- | --- |
| `git merge` | Combines two branches, usually by creating a merge commit with two parents |
| `git rebase` | Replays your branch commits onto a new base, creating new commit SHAs |

## How `git merge` Works

Suppose the history looks like this:

```text
main:    A---B---C
feature:     \---D---E
```

If you merge `feature` into `main`, Git performs a three-way merge between:

| Item | Meaning |
| --- | --- |
| Merge base | The common ancestor, `B` |
| Tip of `main` | The latest commit on `main`, `C` |
| Tip of `feature` | The latest commit on `feature`, `E` |

Result:

```text
A---B---C-------M
     \         /
      D---E---
```

`M` is a merge commit. It points to both `C` and `E`.

Merge properties:

- Preserves the exact branch topology.
- Does not rewrite existing commits.
- Good for shared or public branches.
- Good when auditability matters.
- Can create noisy history if there are many merge commits.

Example:

```bash
git checkout main
git merge branch_a_1
```

## How `git rebase` Works

Using the same starting point:

```text
main:    A---B---C
feature:     \---D---E
```

If you rebase `feature` onto `main`, Git:

1. Finds commits unique to `feature`, such as `D` and `E`.
2. Reapplies those commits on top of `C`.
3. Creates new commits with new SHAs, such as `D'` and `E'`.

Result:

```text
A---B---C---D'---E'
```

The old `D` and `E` commits are replaced by new commit objects.

Rebase properties:

- Produces linear history.
- Can make `git log` easier to read.
- Can make `git bisect` easier in many teams.
- Rewrites commit history.
- Requires a force push if the rebased branch was already pushed.

Example:

```bash
git checkout branch_a_1
git rebase main
```

## Merge and Rebase Conflict Behavior

Both merge and rebase can produce conflicts.

| Operation | Conflict Timing |
| --- | --- |
| Merge | Conflicts are usually resolved once, at merge time |
| Rebase | Conflicts may appear commit by commit as Git replays each commit |

During a rebase conflict:

```bash
# fix the conflicted files
git add .
git rebase --continue
```

Abort a rebase if needed:

```bash
git rebase --abort
```

## When to Use Merge or Rebase

Use merge when:

- The branch is shared or public.
- You want to preserve the true branch history.
- You want the safest non-rewriting integration method.

Use rebase when:

- You are cleaning up local feature history before a pull request.
- Your team prefers linear history.
- You control the branch and other people are not depending on its commits.

Important rule:

```text
Do not rebase commits that other people may already depend on unless the team explicitly agrees.
```

Rebasing local/private branches is usually safe.

## `git fetch` vs `git pull`

`git fetch` downloads the latest changes from the remote repository but does not merge them into your current branch.

It updates remote-tracking branches such as:

```text
origin/main
origin/dev
```

Example:

```bash
git fetch origin
```

Use `git fetch` when you want to see what changed before updating your branch.

`git pull` downloads the latest changes from the remote repository and then updates your current branch.

It is basically:

```text
git fetch + git merge
```

Or, if configured to rebase:

```text
git fetch + git rebase
```

Example:

```bash
git pull origin main
```

Use `git pull` when you want to immediately bring remote changes into your local branch.

| Command | Downloads Changes | Updates Current Branch | Safer for Review |
| --- | --- | --- | --- |
| `git fetch` | Yes | No | Yes |
| `git pull` | Yes | Yes | Less safe |

Example review workflow:

```bash
git fetch origin
git log HEAD..origin/main --oneline
```

If the changes look good:

```bash
git merge origin/main
```

Or pull directly:

```bash
git pull origin main
```

## What `git log HEAD..origin/main --oneline` Does

This command shows commits that exist on `origin/main` but are not yet in your current local branch.

```bash
git log HEAD..origin/main --oneline
```

Meaning:

| Part | Meaning |
| --- | --- |
| `HEAD` | Your current local commit |
| `origin/main` | Your local remote-tracking branch for remote `main` |
| `HEAD..origin/main` | Commits that are ahead on the remote-tracking branch |
| `--oneline` | Show each commit in compact one-line format |

## How to Handle Merge Conflicts

A merge conflict happens when Git cannot automatically combine changes from two sources.

Common situations:

- You changed a line locally and the remote branch changed the same line.
- Your branch changed a file and `main` changed the same file differently.
- Two branches made incompatible edits to the same area.

## 1. Pull or Merge Changes

Example:

```bash
git pull origin main
```

If conflicts exist, Git stops and shows the conflicted files.

Check status:

```bash
git status
```

## 2. Open Conflicted Files

Conflict markers look like this:

```text
<<<<<<< HEAD
your local changes
=======
incoming changes
>>>>>>> origin/main
```

Meaning:

| Marker | Meaning |
| --- | --- |
| `HEAD` | Your current local version |
| Lower section | Incoming version from the branch being merged or pulled |

## 3. Resolve the Conflict

Edit the file and remove the conflict markers.

Final file should contain only the correct resolved content:

```text
final resolved content
```

In VS Code, useful conflict buttons include:

- Accept Current Change
- Accept Incoming Change
- Accept Both Changes
- Compare Changes

## 4. Mark the Conflict as Resolved

After editing:

```bash
git add <file>
```

Example:

```bash
git add src/app.js
```

## 5. Finish the Operation

If it was a merge:

```bash
git commit
```

If it was a rebase:

```bash
git rebase --continue
```

For `git pull`, Git may create a merge commit after conflicts are resolved, depending on your pull strategy.

## 6. Abort if Needed

Cancel a merge:

```bash
git merge --abort
```

Cancel a rebase:

```bash
git rebase --abort
```

Common conflict workflow:

```bash
git fetch origin
git merge origin/main
git status
# resolve files in VS Code
git add .
git commit
```

## Staged vs Unstaged Changes

Git has three main areas:

```text
Working directory -> Staging area -> Commit
```

## Unstaged Changes

Unstaged changes are edits you made in files but have not added to Git's staging area.

Check them with:

```bash
git status
```

Example status:

```text
modified: app.js
```

Stage the file:

```bash
git add app.js
```

## Staged Changes

Staged changes have been added to the staging area and are ready to be included in the next commit.

```bash
git add app.js
git status
```

Commit staged changes:

```bash
git commit -m "Update app logic"
```

Summary:

| State | Meaning |
| --- | --- |
| Unstaged | Changed but not ready for commit |
| Staged | Marked to be included in the next commit |
| Commit | Saved snapshot in Git history |

## Full Code Lifecycle Through GitHub

This is a typical team workflow from local development to GitHub pull request and deployment.

## 1. Create or Clone a Repository

Create a repository on GitHub, then clone it locally:

```bash
git clone https://github.com/user/repo.git
cd repo
```

## 2. Create a New Branch

In team projects, avoid working directly on `main`.

```bash
git checkout -b feature/login-page
```

Equivalent newer command:

```bash
git switch -c feature/login-page
```

## 3. Make Code Changes

Edit files in VS Code or another editor.

Check changed files:

```bash
git status
```

## 4. Stage Changes

Add all changed files:

```bash
git add .
```

Or add a specific file:

```bash
git add src/app.js
```

## 5. Commit Changes

Save changes locally with a message:

```bash
git commit -m "Add login page"
```

## 6. Push Branch to GitHub

Upload your branch:

```bash
git push origin feature/login-page
```

If this is the first push for the branch, setting upstream is useful:

```bash
git push -u origin feature/login-page
```

## 7. Create a Pull Request

On GitHub:

1. Open the repository.
2. Click `Compare & pull request`.
3. Select the base branch, usually `main`.
4. Add a title and description.
5. Create the pull request.

## 8. Code Review

Team members review the PR. They may:

- Approve changes.
- Request changes.
- Add comments.
- Suggest improvements.

If changes are requested, update code locally:

```bash
git add .
git commit -m "Address review comments"
git push
```

The pull request updates automatically.

## 9. Run Checks or CI Pipeline

GitHub Actions or another CI tool may run:

- Unit tests
- Build checks
- Linting
- Security scans
- Deployment validation

Example successful checks:

- Tests passed.
- Build passed.
- Lint passed.

## 10. Merge the Pull Request

After approval and passing checks, merge into `main`.

Common merge options:

| Option | Meaning |
| --- | --- |
| Merge commit | Keeps full branch history |
| Squash merge | Combines branch commits into one commit |
| Rebase merge | Replays commits on `main` |

## 11. Pull Latest `main` Locally

After the PR is merged:

```bash
git checkout main
git pull origin main
```

Or:

```bash
git switch main
git pull origin main
```

## 12. Delete the Feature Branch

Delete the local branch:

```bash
git branch -d feature/login-page
```

Delete the remote branch:

```bash
git push origin --delete feature/login-page
```

## 13. Release or Deploy

After code reaches `main`, deployment may happen through:

- GitHub Actions
- Jenkins
- Azure DevOps
- AWS CodePipeline
- Manual deployment

Typical flow:

```text
Code -> PR -> Review -> Merge -> Build -> Test -> Deploy
```

Lifecycle summary:

```text
Clone repo
-> Create branch
-> Make changes
-> Stage changes
-> Commit
-> Push
-> Open Pull Request
-> Code review
-> Add more commits if review changes are requested
-> CI checks
-> Merge
-> Deploy
-> Pull latest main
```
---

You have divergent branches and need to specify how to reconcile them. You can do so by running one of the following commands sometime before your next pull:

git config pull.rebase false  # merge
git config pull.rebase true   # rebase
git config pull.ff only       # fast-forward only

You can replace "git config" with "git config --global" to set a default, preference for all repositories. You can also pass --rebase, --no-rebase, or --ff-only on the command line to override the configured default per invocation.
