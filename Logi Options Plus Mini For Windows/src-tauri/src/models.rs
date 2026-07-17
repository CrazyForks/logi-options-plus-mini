use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum Feature {
    Quiet,
    Analytics,
    Flow,
    Sso,
    Update,
    Dfu,
    Backlight,
    Logivoice,
    Aipromptbuilder,
    DeviceRecommendation,
    Smartactions,
    ActionsRing,
}

impl Feature {
    pub fn all() -> Vec<Feature> {
        vec![
            Feature::Quiet,
            Feature::Analytics,
            Feature::Flow,
            Feature::Sso,
            Feature::Update,
            Feature::Dfu,
            Feature::Backlight,
            Feature::Logivoice,
            Feature::Aipromptbuilder,
            Feature::DeviceRecommendation,
            Feature::Smartactions,
            Feature::ActionsRing,
        ]
    }

    pub fn description(&self) -> &'static str {
        match self {
            Feature::Quiet => "Quiet Install",
            Feature::Analytics => "Analytics",
            Feature::Flow => "Flow",
            Feature::Sso => "SSO",
            Feature::Update => "Update",
            Feature::Dfu => "DFU",
            Feature::Backlight => "Backlight",
            Feature::Logivoice => "LogiVoice",
            Feature::Aipromptbuilder => "AI Prompt Builder",
            Feature::DeviceRecommendation => "Device Recommendation",
            Feature::Smartactions => "Smart Actions",
            Feature::ActionsRing => "Actions Ring",
        }
    }

    pub fn help(&self) -> &'static str {
        match self {
            Feature::Quiet => "Installs the app silently without the UI.",
            Feature::Analytics => "Shows or hides choice for users to opt in to share app usage and diagnostics data. Default value is Yes.",
            Feature::Flow => "Shows or hides the Flow feature. Default value is Yes.",
            Feature::Sso => "Shows or hides ability for users to sign into the app. Default value is Yes.",
            Feature::Update => "Enables or disables app updates. Default value is Yes.",
            Feature::Dfu => "Enables or disables device firmware updates. Default value is Yes.",
            Feature::Backlight => "Enables or disables keyboard backlight on the supported keyboards. Default value is Yes.",
            Feature::Logivoice => "Enables or disables LogiVoice feature. Default value is Yes.",
            Feature::Aipromptbuilder => "Enables or disables AI Prompt Builder feature. Default value is Yes.",
            Feature::DeviceRecommendation => "Enables or disables device recommendation feature. Default value is Yes.",
            Feature::Smartactions => "Enables or disables Smart Actions feature. Default value is Yes.",
            Feature::ActionsRing => "Enables or disables Actions Ring feature. Default value is Yes.",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeatureInfo {
    pub id: String,
    pub name: String,
    pub description: String,
    pub help: String,
    pub default_enabled: bool,
}

impl From<&Feature> for FeatureInfo {
    fn from(feature: &Feature) -> Self {
        let id = match feature {
            Feature::Quiet => "quiet",
            Feature::Analytics => "analytics",
            Feature::Flow => "flow",
            Feature::Sso => "sso",
            Feature::Update => "update",
            Feature::Dfu => "dfu",
            Feature::Backlight => "backlight",
            Feature::Logivoice => "logivoice",
            Feature::Aipromptbuilder => "aipromptbuilder",
            Feature::DeviceRecommendation => "device-recommendation",
            Feature::Smartactions => "smartactions",
            Feature::ActionsRing => "actions-ring",
        };

        let default_enabled = match feature {
            Feature::Quiet => false,
            _ => true,
        };

        FeatureInfo {
            id: id.to_string(),
            name: feature.description().to_string(),
            description: feature.description().to_string(),
            help: feature.help().to_string(),
            default_enabled,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallResult {
    pub success: bool,
    pub message: String,
    pub version: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VersionInfo {
    pub installed_version: String,
    pub latest_version: String,
}
