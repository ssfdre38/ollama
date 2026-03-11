# Ollama Fork - Issues to Fix

## Repository
- **Upstream**: https://github.com/ollama/ollama
- **Fork**: https://github.com/ssfdre38/ollama
- **Local Clone**: `C:\Users\admin\source\ollama`

## Issues to Fix

### 1. Model Registry Race Conditions
**File**: Likely in `api/` or `server/` directories

**Problem**: 
- `/api/tags` endpoint returns stale model list
- Race condition when models are pulled/deleted while API is querying
- Cache invalidation lag between filesystem and API response

**Fix Approach**:
- Add proper mutex/locking around model registry operations
- Force cache refresh after model mutations (pull/tag/delete)
- Add registry version/timestamp to detect staleness
- Implement retry logic for stale reads

### 2. Tool Calling Format Validation
**File**: Likely in `api/types.go` or similar

**Problem**:
- Go struct `ToolFunctionParameters` expects `type` field to be string
- Error: "cannot unmarshal object into Go struct field ToolFunctionParameters.tools.function.parameters.type of type string"
- Format is technically correct but validation is too strict

**Fix Approach**:
- Review JSON unmarshaling in tool parameter parsing
- Add better error messages that explain what's wrong
- Consider more flexible schema validation

### 3. Model Keep-Alive Issues
**Problem**:
- Models unload between requests causing timing issues
- No persistent "keep model loaded" option that survives service restarts

**Fix Approach**:
- Add persistent keep-alive configuration per model
- Allow setting default keep-alive in config file
- Improve model loading/unloading synchronization

### 4. API Timeout During Tool Calls
**Problem**:
- llama3.3:70b hangs/times out when tools are included
- No proper timeout error, just silent failure

**Fix Approach**:
- Add explicit timeout handling for tool calls
- Return proper error instead of hanging
- Investigate model-specific tool calling compatibility

## Next Steps
1. Read codebase to understand registry implementation
2. Find where `/api/tags` is implemented
3. Locate tool calling unmarshaling code
4. Create branch for fixes
5. Write tests reproducing the race condition
6. Implement fixes with proper locking/synchronization

## Testing Plan
- Unit tests for registry cache consistency
- Integration tests for concurrent model operations
- Tool calling format validation tests
- Timing/race condition stress tests
