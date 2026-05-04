import 'package:mcp_dart/mcp_dart.dart';
import 'package:mcp_masonex/src/runner/masonex_runner.dart';
import 'package:mcp_masonex/src/tools/ai.dart' as ai_tools;
import 'package:mcp_masonex/src/tools/auth.dart' as auth_tools;
import 'package:mcp_masonex/src/tools/bricks.dart' as brick_tools;
import 'package:mcp_masonex/src/tools/build.dart' as build_tools;
import 'package:mcp_masonex/src/tools/bundle.dart' as bundle_tools;
import 'package:mcp_masonex/src/tools/make.dart' as make_tools;
import 'package:mcp_masonex/src/tools/meta.dart' as meta_tools;

/// Hard-coded version surfaced via MCP `Implementation`. Bumped manually
/// when this package is published.
const String mcpMasonexVersion = '0.1.0';

/// Builds the [McpServer] with every masonex tool registered.
///
/// Pass a [MasonexRunner] to override the underlying CLI binary or
/// working directory (useful in tests and for users that have masonex
/// installed under a non-default path).
McpServer buildServer({MasonexRunner? runner}) {
  final r = runner ?? MasonexRunner();
  final server = McpServer(
    const Implementation(name: 'mcp_masonex', version: mcpMasonexVersion),
    options: const McpServerOptions(
      capabilities: ServerCapabilities(
        tools: ServerCapabilitiesTools(),
      ),
    ),
  );

  meta_tools.register(server, r);
  brick_tools.register(server, r);
  make_tools.register(server, r);
  bundle_tools.register(server, r);
  build_tools.register(server, r);
  ai_tools.register(server, r);
  auth_tools.register(server, r);

  return server;
}
