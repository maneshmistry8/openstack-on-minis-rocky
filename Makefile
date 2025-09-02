# ==== Config ====
PYTHON        ?= python3
VENV_DIR      ?= .venv
VENV_BIN      := $(VENV_DIR)/bin
INVENTORY     ?= inventory/multinode.ini
EXTRA         ?=                      # e.g. EXTRA="-l compute1"
ANSIBLE       := $(VENV_BIN)/ansible
ANSIBLE_PLAY  := $(VENV_BIN)/ansible-playbook
PIP           := $(VENV_BIN)/pip
KOLLA         := $(VENV_BIN)/kolla-ansible

# ==== Help ====
.PHONY: help
help:
	@echo ""
	@echo "OpenStack on Minis — Make targets"
	@echo "---------------------------------"
	@echo "make venv         Create venv and install requirements"
	@echo "make shell        Spawn a subshell with venv activated"
	@echo "make ping         Ansible ping all hosts"
	@echo "make genpass      Generate Kolla passwords"
	@echo "make bootstrap    Run playbooks/bootstrap.yml"
	@echo "make deploy       Run playbooks/deploy.yml"
	@echo "make mini-nuke    Destroy OpenStack, KEEP Cinder loopback file"
	@echo "make nuke         Destroy OpenStack and REMOVE Cinder loopback file"
	@echo "make reset        mini-nuke -> bootstrap -> deploy"
	@echo "make cleanvenv    Remove the venv"
	@echo ""
	@echo "Variables: VENV_DIR, INVENTORY, EXTRA"
	@echo 'Examples: make ping EXTRA="-l compute1"'

# ==== Virtualenv ====
.PHONY: venv
venv:
	$(PYTHON) -m venv $(VENV_DIR)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt
	@echo ""
	@echo "✅ venv ready at $(VENV_DIR)"
	@echo "Tip: run 'make shell' or 'source $(VENV_DIR)/bin/activate' to use it."

.PHONY: shell
shell:
	@. $(VENV_BIN)/activate && exec bash -l

# ==== Sanity checks ====
$(ANSIBLE):
	@echo "Virtualenv not found. Run: make venv"
	@false

$(KOLLA):
	@echo "Virtualenv not found. Run: make venv"
	@false

# ==== Ops targets ====
.PHONY: ping
ping: $(ANSIBLE)
	$(ANSIBLE) -i $(INVENTORY) all -m ping $(EXTRA)

.PHONY: genpass
genpass: $(ANSIBLE)
	./scripts/gen-passwords.sh

.PHONY: bootstrap
bootstrap: $(ANSIBLE_PLAY)
	$(ANSIBLE_PLAY) -i $(INVENTORY) playbooks/bootstrap.yml $(EXTRA)

.PHONY: deploy
deploy: $(ANSIBLE_PLAY)
	$(ANSIBLE_PLAY) -i $(INVENTORY) playbooks/deploy.yml $(EXTRA)

# ==== Destructive targets ====
.PHONY: mini-nuke
mini-nuke: $(KOLLA)
	@echo "⚠️  This will DESTROY your OpenStack cluster (containers/config/DB), but keep Cinder volumes."
	@read -p "Type 'MINI' to continue: " confirm && [ "$$confirm" = "MINI" ]
	$(KOLLA) -i $(INVENTORY) destroy --yes-i-really-really-mean-it \
	  -e @kolla/globals.yml -e @kolla/passwords.yml
	@echo "✅ Mini-nuke complete. Volumes preserved."

.PHONY: nuke
nuke: $(KOLLA)
	@echo "⚠️  This will COMPLETELY NUKE OpenStack and REMOVE the Cinder loopback file."
	@read -p "Type 'NUKE' to continue: " confirm && [ "$$confirm" = "NUKE" ]
	$(KOLLA) -i $(INVENTORY) destroy --yes-i-really-really-mean-it \
	  -e @kolla/globals.yml -e @kolla/passwords.yml
	# Remove loopback Cinder VG if present
	@if [ -f /var/lib/cinder-volumes.img ]; then \
	  echo "Removing loopback Cinder volume file..."; \
	  sudo vgremove -ff cinder-volumes || true; \
	  LOOPDEV=$$(losetup -j /var/lib/cinder-volumes.img | cut -d: -f1); \
	  if [ -n "$$LOOPDEV" ]; then sudo losetup -d $$LOOPDEV; fi; \
	  sudo rm -f /var/lib/cinder-volumes.img; \
	fi
	@echo "✅ Full nuke complete."

# ==== One-shot reset ====
.PHONY: reset
reset: mini-nuke bootstrap deploy
	@echo "✅ Reset done: cluster redeployed with volumes preserved."

# ==== Cleanup ====
.PHONY: cleanvenv
cleanvenv:
	@rm -rf $(VENV_DIR)
	@echo "Removed $(VENV_DIR)"

