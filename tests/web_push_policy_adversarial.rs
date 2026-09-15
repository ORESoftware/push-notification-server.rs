use p256::SecretKey;
use p256::pkcs8::{EncodePrivateKey, LineEnding};
use push_notification_server::{WebPushConfig, WebPushConfigError, WebPushHostPolicy};
use rand_core::OsRng;

fn valid_private_key_pem() -> String {
    SecretKey::random(&mut OsRng)
        .to_pkcs8_pem(LineEnding::LF)
        .expect("encode test VAPID key")
        .to_string()
}

#[test]
fn allowlist_normalizes_case_whitespace_and_leading_dot() {
    let policy = WebPushHostPolicy::allowlist(["  .Push.Example.COM  "]).expect("allowlist");
    assert_eq!(
        policy.allowed_hosts().expect("hosts"),
        &["push.example.com".to_owned()]
    );
}

#[test]
fn allowlist_deduplicates_after_normalization() {
    let policy = WebPushHostPolicy::allowlist([
        "push.example.com",
        ".PUSH.EXAMPLE.COM",
        " push.example.com ",
    ])
    .expect("allowlist");
    assert_eq!(policy.allowed_hosts().expect("hosts").len(), 1);
}

#[test]
fn allowlist_rejects_empty_input() {
    assert!(matches!(
        WebPushHostPolicy::allowlist(Vec::<String>::new()),
        Err(WebPushConfigError::InvalidAllowedHost)
    ));
}

#[test]
fn allowlist_rejects_single_label_localhost() {
    assert!(matches!(
        WebPushHostPolicy::allowlist(["localhost"]),
        Err(WebPushConfigError::InvalidAllowedHost)
    ));
}

#[test]
fn allowlist_rejects_whitespace_inside_host() {
    assert!(matches!(
        WebPushHostPolicy::allowlist(["push .example.com"]),
        Err(WebPushConfigError::InvalidAllowedHost)
    ));
}

#[test]
fn allowlist_rejects_url_syntax_instead_of_host_suffix() {
    assert!(matches!(
        WebPushHostPolicy::allowlist(["https://push.example.com"]),
        Err(WebPushConfigError::InvalidAllowedHost)
    ));
}

#[test]
fn allowlist_rejects_host_that_starts_with_hyphen() {
    assert!(matches!(
        WebPushHostPolicy::allowlist(["-push.example.com"]),
        Err(WebPushConfigError::InvalidAllowedHost)
    ));
}

#[test]
fn allowlist_rejects_host_that_ends_with_hyphen() {
    assert!(matches!(
        WebPushHostPolicy::allowlist(["push.example.com-"]),
        Err(WebPushConfigError::InvalidAllowedHost)
    ));
}

#[test]
fn allowlist_rejects_overlong_dns_name() {
    let host = format!("{}.example.com", "a".repeat(244));
    assert!(host.len() > 253);
    assert!(matches!(
        WebPushHostPolicy::allowlist([host]),
        Err(WebPushConfigError::InvalidAllowedHost)
    ));
}

#[test]
fn strict_default_is_an_explicit_allowlist() {
    let policy = WebPushHostPolicy::strict_default();
    let hosts = policy.allowed_hosts().expect("strict allowlist");
    assert!(hosts.contains(&"fcm.googleapis.com".to_owned()));
    assert!(hosts.contains(&"push.services.mozilla.com".to_owned()));
    assert!(hosts.contains(&"notify.windows.com".to_owned()));
    assert!(hosts.contains(&"push.apple.com".to_owned()));
}

#[test]
fn any_public_has_no_static_allowlist() {
    assert!(WebPushHostPolicy::any_public().allowed_hosts().is_none());
}

#[test]
fn config_rejects_empty_private_key_before_runtime_use() {
    assert!(matches!(
        WebPushConfig::new(
            "   ",
            "mailto:push@example.invalid",
            WebPushHostPolicy::strict_default()
        ),
        Err(WebPushConfigError::MissingField("vapid_private_key_pem"))
    ));
}

#[test]
fn config_rejects_insecure_http_subject() {
    assert!(matches!(
        WebPushConfig::new(
            valid_private_key_pem(),
            "http://example.invalid/contact",
            WebPushHostPolicy::strict_default()
        ),
        Err(WebPushConfigError::InvalidSubject)
    ));
}

#[test]
fn config_accepts_mailto_and_https_subjects_with_valid_key() {
    for subject in [
        "mailto:push@example.invalid",
        "https://example.invalid/contact",
    ] {
        WebPushConfig::new(
            valid_private_key_pem(),
            subject,
            WebPushHostPolicy::strict_default(),
        )
        .expect("valid VAPID subject");
    }
}

#[test]
fn config_enforces_the_28_day_ttl_ceiling() {
    let max = 28 * 24 * 60 * 60;
    WebPushConfig::new(
        valid_private_key_pem(),
        "mailto:push@example.invalid",
        WebPushHostPolicy::strict_default(),
    )
    .expect("base config")
    .with_default_ttl(max)
    .expect("maximum TTL is admitted");

    let error = WebPushConfig::new(
        valid_private_key_pem(),
        "mailto:push@example.invalid",
        WebPushHostPolicy::strict_default(),
    )
    .expect("base config")
    .with_default_ttl(max + 1);
    assert!(matches!(error, Err(WebPushConfigError::InvalidTtl)));
}
