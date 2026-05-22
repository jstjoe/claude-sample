# claude + github sample

A small guide to getting Claude and GitHub playing nice.

## Local shell

The quickest way to get set up in the cloud, is to start in a local shell.

1. On your local machine, pull a project you want to work on.
2. Open a shell in that project directory.
3. Ensure you have the `gh` CLI installed. Claude will use this to set things up on GitHub.
4. Ensure you're logged in to the `gh` CLI: `gh auth login`
   1. Run `gh auth login`
   2. Choose GitHub.com
   3. Choose SSH
   4. Copy the code
   5. Go to the URL
   6. Paste the code
   7. Authenticate & follow redirects
5. Ensure you have the `claude` CLI installed.
6. Ensure you're logged in to Claude: `claude /login`
7. Run the installer slash command: `/install-github-app` from claude's TUI, or `claude /install-github-app` from the shell.
   1. Note: If prompted, you may need to give the `gh` CLI more permissions to manage workflows. Follow the steps again to do this.
   2. Choose "subscription" when prompted, this will use your existing usage allowance.
   3. Approve the Claude app's access to GitHub. You can choose the whole org, or select repos.
   4. After authenticating, go back to your terminal. Hit enter to let Claude know it's done.
   5. Claude will prompt you to choose which GitHub Actions to install. I suggest both to start - we'll modify and improve them later. Hit enter.
   6. Claude will push the Actions configuration files to a branch, and redirect you to GitHub to create the PR.
   7. Create the PR, approve and merge when ready.
   8. Done.
8. *Bonus round!* You've configured the GitHub integration between Claude and your repo. While you're here, if you're in an existing project without a CLAUDE.md, run `/init` in the `claude` TUI. This will trigger Claude to run a standard process to generate a structured CLAUDE.md reference file. This works _much_ better than simply asking Claude to make one. Try it out, you can always throw the file away if you want.

## Claude for Mac App

### Configure GitHub Connector

1. Open Claude.app on your Mac
2. Open 'Code'
3. Click 'Customize' > 'Connectors'
4. Enable and log in to the GitHub integration.
5. Quit the app for good measure. Open Claude.app again.

### Code in a Cloud Environment

1. Open 'Code' in the Claude app
2. Above the prompt input you should see 'Local' or 'Default'. Click that button, and select 'Default' if you see that option
   1. If you do not see `Default`, look for `+ Add cloud environment`. Click that and create one with the default configuration.
   2. Warning: If you do NOT see anything referring to a cloud environment in this menu, something is not working and we may need to debug the setup or restart the app. The point of this is to get 'Cloud' options for Claude to run in. Do not skip this! It's worth it!
3. With a Cloud environment selected, you should now be able to choose from available GitHub repositories. 
   1. Pick one. Note that you can also pick more than one... but let's start simple.
   2. Pick the branch you want to start from. Note that Claude's default behavior is to create a new branch FROM the selected branch. Usually, the default branch is the right place to start.
4. Prompt Claude to make a small change to see how this new cloud-enabled workflow works e.g. "add a note to the README.md about enabling Claude for GitHub"
5. It will take a few seconds before you see Claude start responding. What's happening?
   1. Anthropic is spinning up a cloud VM, cloning the selected repo(s), creating a new local (to the VM) branch for changes, setting up the environment variables specified in the cloud config, running the startup script, and initiating the `claude` CLI with your prompt and some additional context about the environment it's working in.
   2. Claude executes inside this sandboxed VM in the cloud. Once the session has started, you can shut down your laptop. Claude will keep working.
   3. Depending on your settings, when it has some work done Claude will push changes to its branch. If you enabled PR creation, Claude will create a PR and the link will appear in the UI.
   4. If auto-fix is enabled, Claude (still in the VM) will subscribe to webhooks from the PR. It will get notified of CI results, comments on the PR, code reviews, etc. Even long running CI jobs should work fine - the claude VM will wake up when it gets a webhook from GitHub. This works great in tandem with the GitHub Actions for code review: your developer agent opens a PR, the reviewer agent reviews and leaves comments, your developer agent gets notified and can push fixes to address review comments and even respond with comments... this is a deep well :)
6. That's the start! Now you can run many different Claudes in parallel, in the cloud, on their own branch. You can also set up "Routines" to run on a schedule whether your computer is open or not. And you can access and manage these claude sessions from anywhere, including your phone. Now, you're an agent orchestrator.
