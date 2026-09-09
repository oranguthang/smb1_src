# Static, semantic-runtime, and scoring evidence.
ENEMY_STREAM_EVIDENCE_MANIFEST ?= $(PROJECT_DIR)config/semantic_evidence/enemy_streams.json
ENEMY_STREAM_EVIDENCE_REPORT ?= $(PROJECT_DIR)build/evidence/enemy_streams.json
UNREACHABLE_CODE_EVIDENCE_MANIFEST ?= $(PROJECT_DIR)config/semantic_evidence/unreachable_code.json
UNREACHABLE_CODE_EVIDENCE_REPORT ?= $(PROJECT_DIR)build/evidence/unreachable_code.json
semantic-evidence: audit-enemy-streams audit-unreachable-code trace-semantic-runtime trace-scoring-runtime

trace-semantic-runtime: symbols
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.run_runtime_scenarios \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(NATIVE_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(RUNTIME_TRACE_LUA)" \
		--scenarios "$(SEMANTIC_RUNTIME_SCENARIOS)" \
		--output-dir "$(SEMANTIC_RUNTIME_TRACE_DIR)"
	$(MAKE) validate-semantic-runtime

validate-semantic-runtime:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_runtime_scenarios \
		--scenarios "$(SEMANTIC_RUNTIME_SCENARIOS)" \
		--trace-dir "$(SEMANTIC_RUNTIME_TRACE_DIR)"

trace-scoring-runtime: symbols
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.run_runtime_scenarios \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(NATIVE_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(SCORING_RUNTIME_TRACE_LUA)" \
		--scenarios "$(SCORING_RUNTIME_SCENARIOS)" \
		--output-dir "$(SCORING_RUNTIME_TRACE_DIR)"
	$(MAKE) validate-scoring-runtime

validate-scoring-runtime:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_scoring_contract \
		--manifest "$(SCORING_RUNTIME_SCENARIOS)"
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_runtime_scenarios \
		--scenarios "$(SCORING_RUNTIME_SCENARIOS)" \
		--trace-dir "$(SCORING_RUNTIME_TRACE_DIR)"

audit-unreachable-code: verify
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.audit_unreachable_code \
		--manifest "$(UNREACHABLE_CODE_EVIDENCE_MANIFEST)" \
		--debug "$(NATIVE_DEBUG)" \
		--prg "$(NATIVE_PRG)" \
		--output "$(UNREACHABLE_CODE_EVIDENCE_REPORT)"

audit-enemy-streams:
	$(MAKE) verify-revision PROFILE=ju
	$(MAKE) verify-revision PROFILE=pc10
	$(MAKE) verify-revision PROFILE=pal
	$(MAKE) verify-platform PLATFORM=vs_smb
	$(MAKE) verify-platform PLATFORM=fds_smb
	$(MAKE) verify-platform PLATFORM=ann_fds
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.audit_enemy_streams \
		--project-root "$(PROJECT_DIR)" \
		--manifest "$(ENEMY_STREAM_EVIDENCE_MANIFEST)" \
		--output "$(ENEMY_STREAM_EVIDENCE_REPORT)"
