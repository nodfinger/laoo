# Local assistant development setup

The runtime and models are installed outside the repository in `C:\RYPIT\local-ai`. The configured model is `qwen3:4b-instruct-2507-q4_K_M` (Apache 2.0); basic Thai intent classification has been tested locally. `qwen2.5:3b` is also installed for earlier research, but is subject to a non-commercial research licence and must not be enabled for production business use. Start the local service after reboot using `powershell -ExecutionPolicy Bypass -File tools/start-local-assistant.ps1`. It binds to loopback and sets `OLLAMA_NO_CLOUD=1`; this setting alone is not an operating-system firewall. The helper does not change an already-running process.

The chatbot is under development. Do not enable a repair-creation route or apply the proposed idempotency migration until permission, tenancy, duplicate-request, and attachment requirements have been implemented and tested. The application still uses its ordinary repair workflow.
