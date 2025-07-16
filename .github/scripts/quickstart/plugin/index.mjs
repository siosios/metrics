export default async function(
  { login, q, imports, data, computed, rest, graphql, queries, account },
  { enabled = false, extras = false } = {}
) {
  try {
    const pluginName = "<%= name %>";
    const isQueryAvailable = !!q[pluginName];
    const isPluginEnabled = !!imports.metadata.plugins[pluginName].enabled(enabled, { extras });

    // Check if plugin is enabled and requirements are met
    if (!isQueryAvailable || !isPluginEnabled) {
      // Optionally: Log or throw a more descriptive error
      // throw new Error(`Plugin "${pluginName}" is not enabled or query is unavailable.`);
      return { status: "skipped", reason: "Plugin not enabled or requirements unmet." };
    }

    // Results
    return {};
  } catch (error) {
    throw imports.format.error(error);
  }
}
