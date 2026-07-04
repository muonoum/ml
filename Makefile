.PHONY: commit push

all:

commit: commit_message ?= $(git_diff)
commit:
	test -n "$(commit_message)"
	git commit -m "$(commit_message)"

push: commit
	git push
