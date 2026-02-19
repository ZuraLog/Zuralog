# Phase 1.8.3: Tool Selection Logic

**Parent Goal:** Phase 1.8 The AI Brain (Reasoning Engine)
**Checklist:**
- [x] 1.8.1 LLM Client Setup
- [x] 1.8.2 Agent System Prompt
- [x] 1.8.3 Tool Selection Logic
- [ ] 1.8.4 Cross-App Reasoning Engine
- [ ] 1.8.5 Voice Input
- [ ] 1.8.6 User Profile & Preferences
- [ ] 1.8.7 Test Harness: AI Chat
- [ ] 1.8.8 Kimi Integration Document
- [ ] 1.8.9 Rate Limiter Service
- [ ] 1.8.10 Usage Tracker Service
- [ ] 1.8.11 Rate Limiter Middleware

---

## What
Implement the "ReAct" style loop or OpenAI Function Calling loop in the `Orchestrator`. This is the engine that decides *when* to call a tool, executes it, feeds the result back to the LLM, and repeats until the final answer is generated.

## Why
The LLM can only output text. We need code to actually *run* the tools it requests and handle the outputs.

## How
We interact with `MCPClient` (from Phase 1.3) to get the tool definitions, pass them to `LLMClient`, and execute the requested tools via `MCPClient.execute_tool`.

## Features
- **Multi-Turn execution:** Can call Tool A, get result, then decides it needs Tool B, get result, then answer.
- **Error Handling:** If a tool fails, feeds the error back to LLM so it can retry or apologize.

## Files
- Modify: `cloud-brain/app/agent/orchestrator.py`

## Steps

1. **Implement tool execution loop (`cloud-brain/app/agent/orchestrator.py`)**

```python
# Pseudo-implementation of the main loop logic
async def process_message(self, user_id: str, message: str) -> str:
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": message}
    ]
    
    # 1. Get available tools dynamically
    tools = await self.mcp_client.list_tools(user_id)
    
    # 2. Loop for tool execution (Max 5 turns to prevent infinite loops)
    for _ in range(5):
        response = await self.llm_client.chat(messages, tools=tools)
        message_obj = response["choices"][0]["message"]
        
        # Add assistant message to history
        messages.append(message_obj)
        
        # Check for tool calls
        if message_obj.get("tool_calls"):
            tool_calls = message_obj["tool_calls"]
            
            for tool_call in tool_calls:
                function_name = tool_call["function"]["name"]
                arguments = json.loads(tool_call["function"]["arguments"])
                
                # Execute tool
                result = await self.mcp_client.execute_tool(function_name, arguments, user_id)
                
                # Append result to messages
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call["id"],
                    "name": function_name,
                    "content": json.dumps(result)
                })
            # Loop continues to let LLM process the tool result
        else:
            # No more tools, return final text
            return message_obj["content"]
            
    return "I'm having trouble retrieving that information right now."
```

## Exit Criteria
- Orchestrator can detect `tool_calls` in response.
- Can execute tools via `mcp_client`.
- Can submit tool results back to LLM.
