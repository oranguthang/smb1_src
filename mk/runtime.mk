# Debug symbols, runtime capture, and format round trips.
symbols: build
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.debug_symbols \
		--debug "$(NATIVE_DEBUG)" \
		--map "$(NATIVE_MAP)" \
		--labels "$(NATIVE_LABELS)" \
		--rom "$(NATIVE_ROM)" \
		--fceux-output-dir "$(FCEUX_SYMBOL_DIR)" \
		--breakpoints "$(DEBUG_BREAKPOINTS)" \
		--watches "$(DEBUG_WATCHES)" \
		--summary "$(DEBUG_SUMMARY)"

validate-symbols: symbols
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_debug_runtime \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(NATIVE_ROM)" \
		--summary "$(DEBUG_SUMMARY)" \
		--lua "$(DEBUG_RUNTIME_LUA)" \
		--result "$(DEBUG_RUNTIME_RESULT)"

trace-runtime: symbols
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.run_runtime_scenarios \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(NATIVE_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(RUNTIME_TRACE_LUA)" \
		--scenarios "$(RUNTIME_SCENARIOS)" \
		--output-dir "$(RUNTIME_TRACE_DIR)"
	$(MAKE) validate-runtime

validate-runtime:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_runtime_scenarios \
		--scenarios "$(RUNTIME_SCENARIOS)" \
		--trace-dir "$(RUNTIME_TRACE_DIR)"

trace: validate-symbols trace-runtime

roundtrip-formats: build-prg
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.data_formats \
		--manifest "$(DATA_FORMAT_MANIFEST)" \
		--labels "$(NATIVE_LABELS)" \
		--prg "$(NATIVE_PRG)" \
		--project-root "$(PROJECT_DIR)" \
		--summary "$(DATA_FORMAT_SUMMARY)"
