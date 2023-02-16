help:
	@echo "use: $(MAKE) [clone-upstream]"
	@echo ""
	@echo "  clone-upstream -> clone upstream(Jigsaw-Code/outline-server) into ./workspace/outline-server"
	@echo "  apply-patches -> patch diff files into ./workspace/outline-server"
	@echo "  create-patch -> create patch file from workspace TARGET=target_to_execute_diff"
	@echo "  clean -> clean workspace directory"

clone-upstream:
	mkdir -p ./workspace;
	@if [[ ! -d ./workspace/outline-server ]]; then \
		git clone https://github.com/Jigsaw-Code/outline-server.git ./workspace/outline-server; \
	else \
		cd ./workspace/outline-server; \
		git pull; \
	fi;

apply-patches:
	@cd ./workspace/outline-server; \
	for FILE in ../../patches/*.patch; do \
		[[ -e "$${FILE}" ]] || continue; \
		echo "Applying $${FILE}"; \
		git apply "$${FILE}"; \
	done;

create-patch:
	@cd ./workspace/outline-server; \
	git diff $(TARGET) > ../../patches/_.patch;

clean:
	rm -rf ./workspace/outline-server;