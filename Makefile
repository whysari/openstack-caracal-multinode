.PHONY: validate smoke evidence teardown

validate:
	./scripts/validate.sh

smoke:
	./scripts/20-smoke-test.sh

evidence:
	./scripts/30-collect-evidence.sh

teardown:
	./scripts/99-teardown.sh --yes
