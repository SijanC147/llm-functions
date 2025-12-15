# Task Completion Checklist

## After Making Changes

### For Tool Changes
1. [ ] Run `argc build@tool` to rebuild declarations
2. [ ] Run `argc check@tool <tool>` to verify deps and envs
3. [ ] Test with `argc run@tool <tool> '<json>'`

### For Agent Changes
1. [ ] Run `argc build@agent` to rebuild declarations
2. [ ] Run `argc check@agent <agent>` to verify
3. [ ] Test with `argc run@agent <agent> <action> '<json>'`

### For Any Changes
1. [ ] Run `argc check` to verify environment
2. [ ] Run `argc test` to run full test suite
3. [ ] Verify `functions.json` was regenerated correctly

## Before Committing
1. [ ] Ensure `argc build` completes without errors
2. [ ] Ensure `argc check` passes all checks
3. [ ] Update `tools.txt` or `agents.txt` if adding new items
4. [ ] No debug/temporary code left behind

## Environment Variables
Check required env vars are set for tools using `# @env VAR!` annotations.
Common vars: `OPENAI_API_KEY`, `TAVILY_API_KEY`, `WEATHER_API_KEY`, etc.
