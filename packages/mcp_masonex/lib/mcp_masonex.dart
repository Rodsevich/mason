/// `mcp_masonex` exposes the masonex CLI through an MCP server so AI agents
/// can interact with bricks (list, search, scaffold, generate, publish, …)
/// using a structured tool surface instead of free-form shell calls.
library mcp_masonex;

export 'src/runner/masonex_runner.dart';
export 'src/server.dart';
