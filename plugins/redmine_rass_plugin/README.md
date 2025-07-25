# Redmine RASS Plugin

## Overview
This plugin enables seamless semantic search in Redmine by integrating with the RASS Engine. It injects a toggle into the search UI, intercepts search requests, and routes them to the RASS Engine when semantic search is enabled. Results are mapped and displayed in the standard Redmine search UI.

## Features
- Semantic/classic search toggle in the search UI
- API call to RASS Engine `/search` endpoint with user context
- Result mapping to Redmine search result objects
- Fallback to classic search if RASS is unavailable or not configured
- No changes to Redmine core/submodule files

## RASS Engine Integration

This plugin now fully integrates with the RASS Engine for semantic search:
- Semantic/classic search toggle in the search UI (cookie-based)
- Search controller patch routes semantic queries to the RASS Engine
- Ruby HTTP client calls `/search/semantic` endpoint with user context, query, and filters
- Results are mapped to Redmine search result objects and displayed in the UI
- Plugin settings allow configuration of RASS endpoint, API key, and default page size
- Robust error handling and fallback to classic search if RASS is unavailable
- Unit and functional tests cover all flows and error cases

### Configuration
- Go to plugin settings and set:
  - RASS Engine Endpoint URL
  - RASS API Key
  - Default Page Size
- Save settings.

### Testing
- Enable the semantic search toggle in the search UI.
- Enter a query and submit.
- If RASS is configured, results are fetched from the RASS Engine; otherwise, classic search is used.
- See test/unit/semantic_issue_search_test.rb and test/functional/search_controller_test.rb for test coverage.

## Development & Maintenance
- **Always consult the canonical integration plan in [docs/rass_integration_plan.md](../docs/rass_integration_plan.md) and the Cursor rule [.cursor/rules/rass-integration-plan.mdc](../.cursor/rules/rass-integration-plan.mdc) before making changes.**
- All plugin logic, API calls, and result mapping must follow the documented architecture and best practices.
- For error handling, fallback, and extensibility, see the integration plan.

## References
- [docs/rass_integration_plan.md](../docs/rass_integration_plan.md)
- [.cursor/rules/rass-integration-plan.mdc](../.cursor/rules/rass-integration-plan.mdc) 