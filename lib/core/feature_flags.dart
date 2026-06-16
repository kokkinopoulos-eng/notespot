const bool kCloudAiEnabled =
    bool.fromEnvironment('ENABLE_CLOUD_AI', defaultValue: false);

/// Human-readable edition name, derived from the build flavor.
const String kEditionName = kCloudAiEnabled ? 'Pro' : 'Free';
