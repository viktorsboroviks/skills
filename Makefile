MAKE_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: install-copy install-symlink remove

install-copy:
	cp -r $(MAKE_DIR)/skills/iterate $(HOME)/.claude/skills/

install-symlink:
	ln -s $(MAKE_DIR)/skills/iterate $(HOME)/.claude/skills/

remove:
	rm -rf $(HOME)/.claude/skills/iterate
