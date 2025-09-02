# ==== config ====
PYTHON        ?= python3
VENV_DIR      ?= .venv
VENV_BIN      := $(VENV_DIR)/bin
INVENTORY     ?= inventory/multinode.ini
EXTRA         ?=                      # extra args e.g. EXTRA="-l compute1"
ANSIBLE       := $(VENV_BIN)/ansible
ANSIBLE_PLAY  := $(VENV_BIN)/ansible-playbook
PIP           := $(VENV_BIN)/pip
KOLLA         := $(VENV_BIN)/kolla-ansible

# ==== help ====
.PHONY: help
help:
	@echo ""
	@echo "OpenStack on Minis — Make targets"
	@echo "---------------------------------"
	@echo "make venv         Create venv and install requirements"
	@echo "make shell        Spawn a subshell with venv activated"
	@echo "make ping         Ansible ping all hosts"
	@echo "make bootstrap    Run playbooks/bootstrap.yml"
	@echo "make deploy       Run playbooks/deploy.yml"
	@echo "make genpass      Generate Kolla passwords"
	@echo "make nuke         Destroy ALL OpenStack services (irreversible!)"
	@echo "make cleanvenv    Remove the venv"
	@echo ""
	@echo "Variables you can override: VENV_DIR, INVENTORY, EXTRA"
	@echo 'Example: make ping EXTRA="-l compute1"'

# ==== virtualenv ====
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

# ==== sanity checks ====
$(ANSIBLE):
	@echo "Virtualenv not found. Run: make venv"
	@false

# ==== Ops targets ====
.PHONY: ping
ping: $(ANSIBLE)
	$(ANSIBLE) -i $(INVENTORY) all -m ping $(EXTRA)

.PHONY: bootstrap
bootstrap: $(ANSIBLE_PLAY)
	$(ANSIBLE_PLAY) -i $(INVENTORY) playbooks/bootstrap.yml $(EXTRA)

.PHONY: deploy
deploy: $(ANSIBLE_PLAY)
	$(ANSIBLE_PLAY) -i $(INVENTORY) playbooks/deploy.yml $(EXTRA)

.PHONY: genpass
genpass: $(ANSIBLE)
	./scripts/gen-passwords.sh

.PHONY: nuke
nuke: $(KOLLA)
	@echo "⚠️  WARNING: This will DESTROY your OpenStack cluster and wipe all data!"
	@read -p "Type 'YES' to continue: " confirm && [ "$$confirm" = "YES" ]
	$(KOLLA) -i $(INVENTORY) destroy --yes-i-really-really-mean-it \
	  -e @kolla/globals.yml -e @kolla/passwords.yml

# ==== Cleanup ====
.PHONY: cleanvenv
cleanvenv:
	@rm -rf $(VENV_DIR)
	@echo "Removed $(VENV_DIR)"

