.PHONY: loop-discover loop-plan loop-execute loop-test loop-finalize loop-all

loop-discover:
	./scripts/pipeline/discover.sh

loop-plan:
	./scripts/pipeline/plan.sh

loop-execute:
	./scripts/pipeline/execute.sh

loop-test:
	./scripts/pipeline/test.sh

loop-finalize:
	./scripts/pipeline/finalize.sh

loop-all: loop-discover loop-plan loop-execute
	-./scripts/pipeline/test.sh
	./scripts/pipeline/finalize.sh
